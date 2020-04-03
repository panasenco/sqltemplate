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
.Parameter Path
    The path to the .eps1.sql template file to apply (does not modify the file, just goes to stdout).
    NOTE The file is only processed with EPS templating if the path ends in .eps1.sql!
.Parameter Template
    The string template to apply.
.Parameter Wrapper
    Array of names of standard wrapper templates (in the Wrappers directory of the SqlTemplate module) to apply, in
    order from innermost to outermost.
#>
function Invoke-SqlTemplate {
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline=$true)]
        [Hashtable] $Binding = @{},
        [string] $Path,
        [string] $Template,
        [string[]] $Wrapper
    )
    
    if (-not $Path) {
        # Invoke the template
        $Body = $Binding.Clone() | Invoke-EpsTemplate -Template $Template
    } elseif ($Path -match '.*\.eps1\.sql\s*$') {
        # Invoke the template only if the extension is .eps1.sql
        $Body = $Binding.Clone() | Invoke-EpsTemplate -Path $Path
    } else {
        # Return the raw file contents if no name and the file extension is not .eps1.sql
        $Body = Get-Content -Raw -Path $Path
    }
    
    if ($Wrapper) {
        # Create a clean copy of the binding
        $BindingCopy = $Binding.Clone()
        $BindingCopy.Remove('Body')
        $BindingCopy.Remove('ChildPath')
        $BindingCopy.Add('ChildPath', $Path)
        # Apply the wrappers in order from innermost to outermost
        foreach ($WrapperName in $Wrapper) {
            $Body = ($BindingCopy + @{Body=$Body}) |
                Invoke-EpsTemplate -Path "$((Get-Module -Name SqlTemplate).ModuleBase)\Wrappers\$WrapperName.eps1.sql"
        }
    }
    
    $Body
}

<#
.Synopsis
    Get the SQL object name corresponding to a SQL source file with a given filepath.
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
