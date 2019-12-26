<#
.Synopsis
    Processes a SQL EPS ([Embedded PowerShell](http://straightdave.github.io/eps/)) template.
.Description
    Can process a SQL query with EPS templating, change it to run on a particular server, and package it up as a CTE,
    inline query, or a CREATE OR ALTER VIEW AS statement.
.Parameter Path
    The path to the .sql file to convert (does not modify the file, just goes to stdout).
.Parameter Binding
    Hashtable containing value bindings to pass on to Invoke-EpsTemplate.
    The 'Server' binding is mandatory - it is the type of server to compile the query for. The server binding allows
    the use of platform-agnostic cmdlets like New-Concat, New-StringAgg, and New-ToDate in your EPS template files.
.Parameter InlineReplace
    SQL command where all instances of FROM <table> need to be replaced with FROM ({BODY}) {NAME}.
    Recommended to be passed in through the pipeline.
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
        [Parameter(Mandatory=$true)]
        [ValidateScript({$_.server -match 'ORACLE|SS\d+'})]
        [Hashtable] $Binding,
        [Parameter(ValueFromPipeline=$true)]
        [string] $InlineReplace,
        [switch] $CTE,
        [switch] $Inline,
        [string] $Prefix,
        [switch] $Diff
    )
    # Apply the EPS template
    $Body = $Binding | Invoke-EpsTemplate -Path $Path

    if ($CTE -or $Inline -or $InlineReplace -or $Prefix) {
        # Indent everything two spaces
        $Body = $Body -replace '^','  ' -replace "`n","`n  " -replace '  $'
        # Get the filebasename with lead non-alpha characters stripped
        $BaseName = [regex]::match($Path, '[^\\.]+(?=[^\\]*$)').Groups[0].Value -replace '^[\W\d_]*'
        if ($InlineReplace) {
            # Replace the references to the view/query with inline expressions containing the query body.
            $InlineReplace -replace "?<=((FROM|JOIN)\s+)$BaseName","(`r`n$Body) $BaseName"
        } elseif ($CTE) {
            # Output CTE to be used in a WITH statement
            "$BaseName AS (`r`n$Body)"
        } elseif ($Inline) {
            # Output inline expression to be used with a FROM statement
            "(`r`n$Body) $BaseName"
        } elseif ($Prefix) {
            switch -regex ($Binding.Server) {
                'SS\d+' { # Microsoft SQL Server
                    $Database, $Rest = $Prefix -split '\.',2
                    if ($Diff) {
                        "USE $Database`nGO`n$Body`nEXCEPT SELECT * FROM $Rest$BaseName"
                    } else {
                        "USE $Database`nGO`nCREATE OR ALTER VIEW $Rest$BaseName AS`n$Body"
                    }
                }
                'ORACLE' { # Oracle PL/SQL
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
    Quotes the given identifier with quoting characters appropriate for the given server.
.Parameter Server
    The server to quote the identifier for.
.Parameter Name
    The identifier name to quote.
#>
function New-QuotedId {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [ValidateScript({$_ -eq "ORACLE" -or $_ -match "SS\d+"})]
        [string] $Server,
        [Parameter(Mandatory=$true, Position=0)]
        [string] $Name
    )
    $QuoteChars = switch -regex ($Server) {
        'SS\d+' { '[',']' }
        'ORACLE' { '"', '"' }
        default { Write-Error "Server $Server not yet supported for identifier quoting" }
    }
    $QuoteChars[0] + $Name + $QuoteChars[1]
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
.Parameter Separator
    The separator to use when aggregating.
.Parameter Order
    Order of aggregation.
#>
function New-StringAgg {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [ValidateSet("ORACLE", "SS13")]
        [string] $Server,
        [Parameter(Mandatory=$true, Position=0)]
        [string] $Expression,
        [string] $GroupField = '',
        [string] $Separator = '',
        [string] $Order = '1'
    )
    switch ($Server) {
        'SS13' {
            if ($GroupField) {
                $Table = ($GroupField | Select-String -Pattern '.*(?=\.[^\.]*)').Matches[0].Value
                $Field = ($GroupField | Select-String -Pattern '[^\.]*$').Matches[0].Value
            } else {
                Write-Error 'GroupField param mandatory for SQL Server 13'
            }
@"
STUFF((
      SELECT
        N'$Separator' + $Expression
      FROM $Table t2
      WHERE $Table.$Field=t2.$Field
      ORDER BY $Order
      FOR XML PATH (N'')
    ), 1, $($Separator.Length), N'') 
"@
        }
        'ORACLE' {
            "LISTAGG($Expression, '$Separator') WITHIN GROUP (ORDER BY $Order)"
        }
        default {
            Write-Error "Server $Server not yet supported for list aggregation"
        }
    }
}
