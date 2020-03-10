<#
.Synopsis
    Processes a SQL EPS ([Embedded PowerShell](http://straightdave.github.io/eps/)) template.
.Description
    Can process a SQL query with EPS templating, change it to run on a particular server, and package it up as a CTE,
    inline query, or a CREATE OR ALTER VIEW AS statement.
.Parameter Path
    The path to the .eps1.sql file to convert (does not modify the file, just goes to stdout).
    NOTE The file is only processed with EPS templating if the path ends in .eps1.sql!
.Parameter Binding
    Hashtable containing value bindings to pass on to Invoke-EpsTemplate. There are some reserved bindings:
     - Server: The type of server to compile the query for. The server binding allows the use of platform-agnostic
           cmdlets like New-Concat, New-StringAgg, New-ToDate, and more in your EPS template files.
     - Prefix: Materialization prefix of tables that the user has rights to create. Passing this parameter is meant to
           change the behavior of template files from queries to DROP TABLE;CREATE TABLE materialization procedures.
           The prefix is prepended as-is, and must include a trailing period if there is one.
           Note that materialization relies on sane indentation - on SQL Server, the line with the FROM with the fewest
           whitespace characters in front of it is the one we'll place the INTO line above of.
           NOTE: Ignored if Inline switch is set. TempPrefix is used instead if CTE switch is set.
     - TempPrefix: Materialization prefix for temporary tables. Set to $($Prefix)TEMP_ if not provided. Used instead
           of $Prefix when -CTE switch is set.
.Parameter ProcPrefix
    Modifies the behavior of the Prefix binding to create a stored procedure with the given prefix.
    Git version history is prepended if this variable is provided.
.Parameter CTE
    Set this switch to output in the CTE format {NAME} AS ({BODY}). If materializing, setting this switch ensures that
    TempPrefix is used instead of Prefix. This switch also turns off Git version history.
.Parameter Inline
    Set this switch to output in the inline format ({BODY}) {NAME}.
.Parameter View
    Modifies the behavior of the Prefix binding to create a view rather than materialize the query in a table.
    Setting this switch also prepends Git version history.
.Parameter Diff
    Modifies the behavior of the Prefix binding to create a query that checks for differences against an existing
    table/view rather than update it.
#>
function Use-SQL {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true, Position=0)]
        [string] $Path,
        [Parameter(ValueFromPipeline=$true)]
        [Hashtable] $Binding = @{},
        [string] $ProcPrefix,
        [switch] $CTE,
        [switch] $Inline,
        [switch] $View,
        [switch] $Diff
    )
    # Get the filebasename with lead non-alpha characters stripped
    $BaseName = [regex]::match($Path, '[^\\.]+(?=[^\\]*$)').Groups[0].Value -replace '^[\W\d_]*'
    
    # Define the time variables declaraion block
    $TimeDeclare = "DECLARE @t1 DATETIME;`r`nDECLARE @t2 DATETIME;"
    
    # Get the raw body
    $Body = Get-Content -Raw -Path $Path

    # Include TempPrefix if needed
    if ($Binding.Prefix -and -not $Binding.TempPrefix) { $Binding += @{TempPrefix = $Binding.Prefix + 'TEMP_'} }
    # Swap TempPrefix for Prefix if -CTE is set
    if ($Binding.Prefix -and $CTE) { $Binding.Prefix = $Binding.TempPrefix }
    
    # If database provided in SQL Server prefix, extract it
    $UseDatabase = ''
    if ($Binding.Server -match 'SS\d+') {
        $Database = ($Binding.Prefix  | Select-String -Pattern '.*(?=\.[^\.]*\.[^\.]*$)').Matches.Value
        if ($Database) {
            $UseDatabase = "USE $Database`r`nGO`r`n"
            $PrefixWithoutDatabase = ($Binding.Prefix | Select-String -Pattern '([^\.]+\.)?[^\.]*$').Matches.Value
            if ($ProcPrefix) {
                # Remove database component from the prefix if we're creating a stored procedure.
                $Binding.Prefix = $PrefixWithoutDatabase
            }
        } else {
            $PrefixWithoutDatabase = $Binding.Prefix
        }
    }
    
    # Process materialization before applying the EPS template
    $Materialize = $Binding.Prefix -and (-not $View) -and (-not $Diff) -and (-not $Inline)
    if ($Materialize) {
        # Pre-process based on server type
        switch -regex ($Binding.Server) {
            'SS\d+' { # Microsoft SQL Server
                # Find the index of the first FROM that's least indented and not already following an INTO.
                $MainFromIndex = (($Body | Select-String -Pattern '(?<=[\n])[^\S\r\n]*FROM' `
                    -AllMatches)[0].matches | Sort-Object -Property Length,Index)[0].Index
                # Insert an INTO right above that FROM
                $Body = $Body.Insert($MainFromIndex, "INTO $($Binding.Prefix)$BaseName`r`n")
            }
            'ORA.*' { # Oracle PL/SQL
                $Body = "DROP TABLE IF EXISTS $($Binding.Prefix)$BaseName;`r`n" +
                    "CREATE TABLE $($Binding.Prefix)$BaseName AS`r`n$Body"
            }
            default {
                Write-Error "Unsupported server type: $Binding.Server."
            }
        }
    }
    
    # Apply the EPS template to the body
    if ($Path -match '.*\.eps1\.sql\s*$') {
        $BindingCopy = $Binding.Clone()
        if (-not $Materialize) {
            $BindingCopy.Remove('Prefix')
            $BindingCopy.Remove('TempPrefix')
        }
        $BindingCopy.Remove('Path')
        $Body = ($BindingCopy + @{Path=$Path}) | Invoke-EpsTemplate -Template $Body
    }
    
    if ($Materialize) {
        # Insert pre-creation drop block and timing initializer
        $PreCreationIndex = (($Body | Select-String -Pattern '(?<=GO\s*\r?\n)|^' `
            -AllMatches)[0].matches | Sort-Object -Descending -Property Index)[0].Index
        $Body = $Body.Insert($PreCreationIndex, $UseDatabase +
            "IF OBJECT_ID('$PrefixWithoutDatabase$BaseName', 'U') IS NOT NULL " +
            "DROP TABLE $PrefixWithoutDatabase$BaseName;`r`n" +
            "IF OBJECT_ID('$PrefixWithoutDatabase$BaseName', 'V') IS NOT NULL " +
            "DROP VIEW $PrefixWithoutDatabase$BaseName;`r`n`r`n" +
            "$TimeDeclare`r`nSET @t1 = GETDATE();`r`n`r`n")
        # Append timing block and GO
        $Body += "`r`nSET @t2 = GETDATE();`r`nSELECT FORMAT(DATEDIFF(millisecond,@t1,@t2)/1000.0, '.##') + " +
        "' s to create $($Binding.Prefix)$BaseName' AS msg`r`nGO`r`n"
    }
    if ($ProcPrefix -or ($CTE -and -not $Materialize) -or ($Inline -and -not $Materialize) -or $View -or $Diff) {
        # Indent everything two spaces
        $Body = $Body -replace '^','  ' -replace "`n","`n  " -replace '  $'
    
        # Define git version history variable
        $GitHistory = if ($ProcPrefix -or $View) {
            try {
                # This will throw an error if we're not in a valid Git repository
                git rev-parse 2>&1 | Out-Null
                # Determine the remote origin if it exists
                $Origin = git config --get remote.origin.url
                # Get the git log in a nice concise format
                $GitLog = git log --graph --date=short --pretty='format:%ad %an%d %h: %s' -- $Path
                # Replace useless refs in the first line
                $GitLog = $GitLog -replace '(?<=\(.*)HEAD -> \w+, |, origin/\w+(?=.*\))'
                # Warn the user if the file has uncommitted changes
                if (git diff --name-only -- $Path) {
                    Write-Warning "$Path has uncommitted changes"
                    $GitLog = @("* $(Get-Date -Format 'yyyy-MM-dd') $(git config user.name) UNCOMMITTED CHANGES") + $GitLog
                }
                "  /* File History ($(if ($Origin) { "origin $Origin" } else { "no origin" })):`r`n   "+`
                    "$($GitLog -join "`r`n   ")`r`n   */`r`n`r`n"
            } catch { '' }
        } else { '' }
        
        if ($Inline) {
            # Output inline expression to be used with a FROM statement
            $Body = "(`r`n$Body) $BaseName"
        } elseif ($Binding.Prefix) {
            switch -regex ($Binding.Server) {
                'SS\d+' { # Microsoft SQL Server
                    if ($Diff) {
                        $Body = "$UseDatabase$Body`r`nEXCEPT SELECT * FROM $($Binding.Prefix)$BaseName"
                    } elseif ($View) {
                        $Body = "$($UseDatabase)CREATE OR ALTER VIEW $PrefixWithoutDatabase$BaseName AS`r`n$GitHistory$Body"
                    } elseif ($ProcPrefix) {
                        # Remove all lines that begin with GO, DECLARE, or USE, as well as a preceding blank line if any
                        $Body = $Body -replace '(\r\n|^)[^\S\r\n]*(GO|DECLARE|USE)[^\r\n]*'
                        # Create stored procedure with given prefix
                        $Body = "$($UseDatabase)CREATE OR ALTER PROCEDURE $ProcPrefix$BaseName AS`r`n" +
                            "BEGIN`r`n$GitHistory  $($TimeDeclare -replace "`n","`n  ")`r`n$Body`r`nEND`r`nGO"
                    } else {
                        $Body = "$UseDatabase$Body"
                    }
                }
                'ORA.*' { # Oracle PL/SQL
                    if ($Diff) {
                        $Body = "$Body`r`nMINUS SELECT * FROM $($Binding.Prefix)$BaseName"
                    } elseif ($View) {
                        $Body = "CREATE OR ALTER VIEW $($Binding.Prefix)$BaseName AS`r`n$Body"
                    }
                }
                default {
                    Write-Error "Unsupported server type: $Binding.Server."
                }
            }
        } elseif ($CTE) {
            # Output CTE to be used in a WITH statement
            $Body = "$BaseName AS (`r`n$Body)"
        }
    }
    "$Body"
}

<#
.Synopsis
    Converts strings to dates.
.Parameter Server
    The server to convert the strings in.
.Parameter String
    The date expression to convert.
.Parameter Format
    The Oracle-style format mask to use for the conversion.
#>
function ConvertTo-Date {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true, Position=0)]
        [string] $Server,
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [string[]] $String,
        [Parameter(Mandatory=$true, Position=1)]
        [string] $Format
    )
    switch -regex ($Server) {
        'ORA.*' { "TO_DATE($String, '$Format')" }
        'SS\d\d.*' {
            # Determine the T-SQL datetime style code
            $SqlStyleCode = switch ($Format) {
                'MM/DD/YYYY' { 101 }
                default { Write-Error "Can't find matching T-SQL style code for datetime format '$Format'" }
            }
            "CONVERT(DATETIME, $String, $SqlStyleCode)"
        }
        default { Write-Error "Server $Server not yet supported for string to datetime conversion." }
    }
}

<#
.Synopsis
    Converts strings to integers.
.Parameter Server
    The server to convert the strings in.
.Parameter String
    The string to convert.
#>
function ConvertTo-Int {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true, Position=0)]
        [string] $Server,
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [string[]] $String
    )
    switch -regex ($Server) {
        'SS\d\d.*' { "CAST($String AS int)" }
        'ORA.*' { "TO_NUMBER($String)" }
        default { Write-Error "Server $Server not yet supported for string to int conversion." }
    }
}

<#
.Synopsis
    Converts dates to yyyymmdd integers.
.Parameter Server
    The server to convert the dates in.
.Parameter Date
    The date expression to convert.
#>
function ConvertTo-IntYYYYMMDD {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true, Position=0)]
        [string] $Server,
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [string[]] $Date
    )
    switch -regex ($Server) {
        'SS\d\d.*' { "CONVERT(char(8), $Date, 112)" | ConvertTo-Int -Server $Server }
        'ORA.*' { "TO_CHAR($Date, 'YYYYMMDD')" | ConvertTo-Int -Server $Server }
        default { Write-Error "Server $Server not yet supported for date to yyyymmdd int conversion." }
    }
}

<#
.Synopsis
    Computes the difference between two dates in days.
.Parameter Server
    The server to concatenate the strings in.
.Parameter StartDate
    The date to subtract from EndDate.
.Parameter EndDate
    The date to subtract StartDate from.
#>
function New-DateDiff {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true, Position=0)]
        [ValidateScript({$_ -match "ORA.*" -or $_ -match "SS\d+"})]
        [string] $Server,
        [Parameter(Mandatory=$true)]
        [string] $StartDate,
        [Parameter(Mandatory=$true)]
        [string] $EndDate
    )
    switch -regex ($Server) {
        'SS\d+' { "DATEDIFF(day, $StartDate, $EndDate)" }
        'ORA.*' { "$EndDate - $StartDate" }
        default { Write-Error "Server $Server not yet supported for string concatenation" }
    }
}

<#
.Synopsis
    Concatenates a list in a platform-appropriate manner.
.Parameter Server
    The server to concatenate the strings in.
.Parameter InputString
    The strings to concatenate.
#>
function New-Concat {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true, Position=0)]
        [ValidateScript({$_ -match "ORA.*" -or $_ -match "SS\d+"})]
        [string] $Server,
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [string] $InputString
    )
    begin {
        $ConcatOperator = switch -regex ($Server) {
            'SS\d+' { ' + ' }
            'ORA.*' { ' || ' }
            default { Write-Error "Server $Server not yet supported for string concatenation" }
        }
        $OutString = ''
    }
    process {
        $OutString += $InputString + $ConcatOperator
    }
    end {
        $OutString.Substring(0, $OutString.Length - $ConcatOperator.Length)
    }
}

<#
.Synopsis
    Gets the length of an expression (LENGTH in Oracle, LEN in SQL Server)
.Parameter Server
    The server to get the length in.
.Parameter Expression
    The expression to find the length of.
#>
function New-Length {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true, Position=0)]
        [ValidateScript({$_ -match "ORA.*" -or $_ -match "SS\d+"})]
        [string] $Server,
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [string] $Expression
    )
    switch -regex ($Server) {
        'SS\d+' { "LEN($Expression)" }
        'ORA.*' { "LENGTH($Expression)" }
        default { Write-Error "Server $Server not yet supported for length" }
    }
}

<#
.Synopsis
    Quotes the given identifier with quoting characters appropriate for the given server.
.Parameter Server
    The server to quote the identifier for.
.Parameter Name
    The identifier name to quote.
#>
function New-QuotedId {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true, Position=0)]
        [ValidateScript({$_ -match "ORA.*" -or $_ -match "SS\d+"})]
        [string] $Server,
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [string] $Name
    )
    $QuoteChars = switch -regex ($Server) {
        'SS\d+' { '[',']' }
        'ORA.*' { '"', '"' }
        default { Write-Error "Server $Server not yet supported for identifier quoting" }
    }
    $QuoteChars[0] + $Name + $QuoteChars[1]
}

<#
.Synopsis
    Sanitizes provided input string, making sure the output is free of nonprinting characters.
.Parameter Server
    The server to sanitize the string for.
.Parameter String
    The string to sanitize.
#>
function New-Sanitize {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true, Position=0)]
        [ValidateScript({$_ -match "ORA.*" -or $_ -match "SS\d+"})]
        [string] $Server,
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [string] $String
    )
    switch -regex ($Server) {
        'SS\d+' {
            # This function does additional processing in addition to sanitizing, but it gets the job done.
            "STRING_ESCAPE($String, 'json')"
        }
        'ORA.*' {
            # This is the desired effect - just removing special characters
            "REGEXP_REPLACE($String, '[[:cntrl:]]')"
        }
        default { Write-Error "Server $Server not yet supported for string sanitization" }
    }
}

<#
.Synopsis
    Generates a string aggregation statement for grouped queries.
.Parameter Server
    The server to generate the aggregation statement for.
.Parameter Expression
    The SQL expression to aggregate.
.Parameter GroupField
    The fully qualified field to group by. The part after the last period is assumed to be the field name. The part
    before the last period is assumed to be the fully qualified table name. Only mandatory for SQL Server '13.
.Parameter Filter
    WHERE filter to apply to the table before aggregating.
.Parameter Separator
    The separator to use when aggregating.
.Parameter Order
    Order of aggregation.
#>
function New-StringAgg {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true, Position=0)]
        [string] $Server,
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [string] $Expression,
        [string] $GroupField = '',
        [string] $Filter = '',
        [string] $Separator = '',
        [string] $Order = '1'
    )
    switch -regex ($Server) {
        'SS13' {
            if ($GroupField) {
                $Table = ($GroupField | Select-String -Pattern '.*(?=\.[^\.]*)').Matches[0].Value
                $Field = ($GroupField | Select-String -Pattern '[^\.]*$').Matches[0].Value
            } else {
                Write-Error 'GroupField param mandatory for SQL Server 13'
            }
            if ($Filter) { $AdditionalFilter = "`r`n        AND $Filter" }
@"
STUFF((
      SELECT
        N'$Separator' + $Expression
      FROM $Table t2
      WHERE $Table.$Field=t2.$Field$AdditionalFilter
      ORDER BY $Order
      FOR XML PATH (N''), ROOT('root'), type
      ).value('/root[1]','VARCHAR(MAX)')
    , 1, $($Separator.Length), N'') 
"@
        }
        'ORA.*' {
            "LISTAGG($Expression, '$Separator') WITHIN GROUP (ORDER BY $Order)"
        }
        default {
            Write-Error "Server $Server not yet supported for list aggregation"
        }
    }
}

<#
.Synopsis
    Outputs substring function - SUBSTR for Oracle, SUBSTRING for everything else.
.Parameter Server
    The server to output substring function for.
.Parameter String
    The string to get substring from.
.Parameter Position
    The starting position of the substring.
.Parameter Length
    The length of the substring.
#>
function New-Substring {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true, Position=0)]
        [string] $Server,
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [string] $String,
        [string] $Position = '1',
        [Parameter(Mandatory=$true)]
        [string] $Length
    )
    switch -regex ($Server) {
        'ORA.*' { "SUBSTR($String, $Position, $Length)" }
        default { "SUBSTRING($String, $Position, $Length)" }
    }
}

<#
.Synopsis
    Outputs substring index function - INSTR for Oracle, CHARINDEX for SQL Server.
.Parameter Server
    The server to output the substring index function for.
.Parameter String
    The string to find the substring in.
.Parameter Substring
    The substring to search for in the string.
#>
function New-SubstringIndex {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true, Position=0)]
        [string] $Server,
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [string] $String,
        [Parameter(Mandatory=$true)]
        [string] $Substring
    )
    switch -regex ($Server) {
        'ORA.*' { "INSTR($String, $Substring)" }
        'SS\d+' { "CHARINDEX($Substring, $String)" }
        default { Write-Error "Server $Server not yet supported for substring location." }
    }
}

<#
.Synopsis
    Gets the current system date (no time component).
.Parameter Server
    The server to get the system date for.
#>
function New-SysDate {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true, Position=0)]
        [ValidateScript({$_ -match "ORA.*" -or $_ -match "SS\d+"})]
        [string] $Server
    )
    switch -regex ($Server) {
        'SS\d+' { 'CAST(SYSDATETIME() AS date)' }
        'ORA.*' { 'SYSDATE' }
        default { Write-Error "Server $Server not yet supported for SYSTIME retrieval" }
    }
}
