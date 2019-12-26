<#
.Synopsis
    Processes a SQL EPS ([Embedded PowerShell](http://straightdave.github.io/eps/)) template.
.Description
    Can process a SQL query with EPS templating, change it to run on a particular server, and package it up as a CTE,
    inline query, or a CREATE OR ALTER VIEW AS statement.
.Parameter Path
    The path to the .sql file to convert (does not modify the file, just goes to stdout).
.Parameter Server
    The type of server to compile the query for. Allows the use of platform-agnostic EPS cmdlets like New-Concat,
    New-StringAgg, and New-ToDate.
.Parameter CTE
    Set this switch to output in the CTE format {NAME} AS ({BODY}).
.Parameter Inline
    Set this switch to output in the inline format ({BODY}) {NAME}.
.Parameter InlineReplace
    SQL command where all instances of FROM <table> need to be replaced with FROM ({BODY}) {NAME}.
    Recommended to be passed in through the pipeline.
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
        [ValidateSet("ORACLE", "SS13")]
        [string] $Server,
        [switch] $CTE,
        [switch] $Inline,
        [Parameter(ValueFromPipeline=$true)]
        [string] $InlineReplace,
        [string] $Prefix,
        [switch] $Diff
    )
    # Apply the EPS template
    $Body = Invoke-EpsTemplate -Path $Path -Binding @{Server=$Server}

    if ($CTE -or $Inline -or $InlineReplace -or $Prefix) {
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
        } elseif ($InlineReplace) {
            # Replace the references to the view/query with inline expressions containing the query body.
            $InlineReplace -replace "?<=((FROM|JOIN)\s+)$BaseName","(`r`n$Body) $BaseName"
        } elseif ($Prefix) {
            switch -regex ($Server) {
                'SS\d+' { # Microsoft SQL Server '13
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
                    Write-Error "Unsupported server type: $Server."
                }
            }
        }
    } else {
        $Body
    }
}
