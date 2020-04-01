<#
.Synopsis
    Processes a SQL EPS ([Embedded PowerShell](http://straightdave.github.io/eps/)) template.
.Description
    Can process a SQL query with EPS templating, change it to run on a particular server, and package it up as a CTE,
    inline query, or a CREATE OR ALTER VIEW AS statement.
.Parameter Binding
    Hashtable containing value bindings to pass on to Invoke-EpsTemplate. There are some reserved bindings:
     - Server: The type of server to compile the query for. The server binding allows the use of platform-agnostic
           cmdlets like New-Concat, New-StringAgg, New-ToDate, and more in your EPS template files.
     - Body: The body of the nested template for wrapper templates.
     - ChildPath: The path to the child template file for wrapper templates.
     - Prefix: List of 1 or 2 prefixes for database objects:
           - The first prefix in the list is assumed to be the working schema with a trailing period if there is one.
           - The second prefix in the list, if any, will be prepended to stored procedures and views after the first.
           SQL Server notes:
            - It is assumed that the prefix does NOT contain the database name, and that the script will be executed
              within the intended database. This is necessary for running the SQL in automated tools.
     - TempPrefix: Materialization prefix for temporary tables. Set to $($Prefix[0])TEMP_ if not provided.
.Parameter Path
    The path to the .eps1.sql template file to apply (does not modify the file, just goes to stdout).
    NOTE The file is only processed with EPS templating if the path ends in .eps1.sql!
.Parameter Template
    The string template to apply.
.Parameter Wrapper
    Array of names of standard wrapper templates (in the Wrappers directory of the SqlTemplate module) to apply, in
    order from innermost to outermost.
#>
function Use-Sql {
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline=$true)]
        [Hashtable] $Binding = @{},
        [Parameter(ParameterSetName='File template')]
        [string] $Path,
        [Parameter(ParameterSetName='Standard template')]
        [string] $Template,
        [string[]] $Wrapper
    )
    
    # Convert the prefix to array to handle optional additional prefixes for views and stored procedures
    $Binding.Prefix = [string[]] $Binding.Prefix
    
    if ($Template) {
        # Save the template in a temporary .eps1.sql file and set the path to that file
        [string] $TempPath = New-TemporaryFile
        $Path = $TempPath + '.eps1.sql'
        $Template | Set-Content -Path $Path
    }
    
    if ($Template) {
        # Invoke the template
        $Body = $Binding.Clone() | Invoke-EpsTemplate -Template $Template
    } elseif ($Path -match '.*\.eps1\.sql\s*$') {
        # Invoke the template only if the extension is .eps1.sql
        $Body = $Binding.Clone() | Invoke-EpsTemplate -Path $Path
    } else {
        # Return the raw file contents if no name and the file extension is not .eps1.sql
        $Body = Get-Content -Raw -Path $Path
    }
    
    # Apply the wrappers in order from innermost to outermost
    if ($Wrapper) {
        $BindingCopy = $Binding.Clone()
        $BindingCopy.Remove('Body')
        $BindingCopy.Remove('ChildPath')
        $BindingCopy.Add('ChildPath', $Path)
        foreach ($WrapperName in $Wrapper) {
            $Body = ($BindingCopy + @{Body=$Body}) |
                Invoke-EpsTemplate -Path "$((Get-Module -Name SqlTemplate).ModuleBase)\Wrappers\$WrapperName.eps1.sql"
        }
    }
    
    $Body
}

<#
.Synopsis
    Get the SQL object name corresponding to a file with a given filepath.
.Parameter Path
    The path of the file to get the basename of. If the path is not provided, a random string is returned.
#>
function Get-SqlBasename {
    [CmdletBinding()]
    param (
        [Parameter(Position=0, ValueFromPipeline=$true)]
        [string] $Path
    )
    if ($Path) {
        # Get the basename of the file including secondary extensions
        $Basename = (Get-Item -Path $Path).BaseName
        # Strip the secondary extensions
        ($Basename -split '\.')[0]
    } else {
        # Return a random collection of alpha characters
        -join ((65..90) + (97..122) | Get-Random -Count 16 | % {[char]$_})
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
    FROM expression for selecting a single line. Blank in SQL Server, "FROM dual" in Oracle.
.Parameter Server
    The server to select the single line in.
#>
function New-SingleSelectFrom {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true, Position=0)]
        [ValidateScript({$_ -match "ORA.*" -or $_ -match "SS\d+"})]
        [string] $Server
    )
    switch -regex ($Server) {
        'SS\d+' { "" }
        'ORA.*' { "FROM dual" }
        default { Write-Error "Server $Server not yet supported for single line selection" }
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
