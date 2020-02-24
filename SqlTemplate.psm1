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
    Hashtable containing value bindings to pass on to Invoke-EpsTemplate.
    The 'Server' binding is important - it is the type of server to compile the query for. The server binding allows
    the use of platform-agnostic cmdlets like New-Concat, New-StringAgg, and New-ToDate in your EPS template files.
.Parameter CTE
    Set this switch to output in the CTE format {NAME} AS ({BODY}).
.Parameter Inline
    Set this switch to output in the inline format ({BODY}) {NAME}.
.Parameter Prefix
    Set to script the query as a CREATE OR ALTER VIEW statement with the given fully qualified prefix.
    The prefix is prepended as is, and must include a trailing period if there is one.
.Parameter Diff
    Modifies the behavior of Prefix flag to create a query that checks for differences against an existing view rather
    than update the view.
#>
function Use-SQL {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true, Position=0)]
        [string] $Path,
        [Parameter(ValueFromPipeline=$true)]
        [Hashtable] $Binding = @{},
        [switch] $CTE,
        [switch] $Inline,
        [string] $Prefix,
        [switch] $Diff
    )
    # Apply the EPS template
    if ($Path -match '.*\.eps1\.sql\s*$') {
        $Body = $Binding | Invoke-EpsTemplate -Path $Path
    } else {
        $Body = Get-Content -Raw -Path $Path
    }
    
    # Prepend the git log message if defining a view or stored procedure and inside a valid git repository
    if ($Prefix -or $Body -match 'CREATE\s+(OR\s+ALTER\s+|)(PROCEDURE|VIEW)') {
        try {
            git rev-parse 2>&1 | Out-Null
            $Origin = git config --get remote.origin.url
            $Body = "/* File History ($(if ($Origin) { "origin $Origin" } else { "no origin" })):`r`n "+`
                "$((git log --graph --pretty=oneline --abbrev-commit -- $Path) -join "`r`n ")`r`n */`r`n`r`n$Body"
        } catch {}
    }
    
    if ($CTE -or $Inline -or $Prefix) {
        # Indent everything two spaces
        $Body = $Body -replace '^','  ' -replace "`n","`n  " -replace '  $'
        # Get the filebasename with lead non-alpha characters stripped
        $BaseName = [regex]::match($Path, '[^\\.]+(?=[^\\]*$)').Groups[0].Value -replace '^[\W\d_]*'
        if ($CTE) {
            # Output CTE to be used in a WITH statement
            "$BaseName AS (`r`n$Body)"
        } elseif ($Inline) {
            # Output inline expression to be used with a FROM statement
            "(`r`n$Body) $BaseName"
        } elseif ($Prefix) {
            # Create a CREATE OR ALTER VIEW statement with the appropriate dialect
            switch -regex ($Binding.Server) {
                'SS\d+' { # Microsoft SQL Server
                    $Database, $Rest = $Prefix -split '\.',2
                    if ($Diff) {
                        "USE $Database`nGO`n$Body`nEXCEPT SELECT * FROM $Rest$BaseName"
                    } else {
                        "USE $Database`nGO`nCREATE OR ALTER VIEW $Rest$BaseName AS`n$Body"
                    }
                }
                'ORA.*' { # Oracle PL/SQL
                    if ($Diff) {
                        "$Body`nMINUS SELECT * FROM $Prefix$BaseName"
                    } else {
                        "CREATE OR ALTER VIEW $Prefix$BaseName AS`n$Body"
                    }
                }
                default {
                    Write-Error "Unsupported server type: $Binding.Server."
                }
            }
        }
    } else {
        $Body
    }
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
            if ($Filter) { $AdditionalFilter = "`n        AND $Filter" }
@"
STUFF((
      SELECT
        N'$Separator' + $Expression
      FROM $Table t2
      WHERE $Table.$Field=t2.$Field$AdditionalFilter
      ORDER BY $Order
      FOR XML PATH (N'')
    ), 1, $($Separator.Length), N'') 
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
#>
function New-Substring {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true, Position=0)]
        [string] $Server
    )
    switch -regex ($Server) {
        'ORA.*' { 'SUBSTR' }
        default { 'SUBSTRING' }
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
