#
# Module manifest for module 'SqlTemplate'
#
# Generated by: Aram Panasenco
#
# Generated on: 12/26/2019
#

@{

# Script module or binary module file associated with this manifest.
RootModule = 'SqlTemplate.psm1'

# Version number of this module.
ModuleVersion = '1.2.0'

# Supported PSEditions
# CompatiblePSEditions = @()

# ID used to uniquely identify this module
GUID = 'a85569b2-897d-49ee-b3c1-0432c3bb9803'

# Author of this module
Author = 'Aram Panasenco'

# Company or vendor of this module
CompanyName = ''

# Copyright statement for this module
Copyright = @'
MIT License

Copyright (c) 2019 Aram Panasenco

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
'@

# Description of the functionality provided by this module
Description = @'
SqlTemplate is a templating tool based on Embedded PowerShell that aims to resolve the following frequent SQL pain
points:
 * Reusing subqueries and CTEs across multiple queries
 * Writing queries meant to run on different SQL platforms
 * Generating many similar columns
Read the guide and browse the source code at https://github.com/panasenco/sqltemplate
'@

# Minimum version of the Windows PowerShell engine required by this module
# PowerShellVersion = ''

# Name of the Windows PowerShell host required by this module
# PowerShellHostName = ''

# Minimum version of the Windows PowerShell host required by this module
# PowerShellHostVersion = ''

# Minimum version of Microsoft .NET Framework required by this module. This prerequisite is valid for the PowerShell Desktop edition only.
# DotNetFrameworkVersion = ''

# Minimum version of the common language runtime (CLR) required by this module. This prerequisite is valid for the PowerShell Desktop edition only.
# CLRVersion = ''

# Processor architecture (None, X86, Amd64) required by this module
# ProcessorArchitecture = ''

# Modules that must be imported into the global environment prior to importing this module
RequiredModules = @("EPS")

# Assemblies that must be loaded prior to importing this module
# RequiredAssemblies = @()

# Script files (.ps1) that are run in the caller's environment prior to importing this module.
# ScriptsToProcess = @()

# Type files (.ps1xml) to be loaded when importing this module
# TypesToProcess = @()

# Format files (.ps1xml) to be loaded when importing this module
# FormatsToProcess = @()

# Modules to import as nested modules of the module specified in RootModule/ModuleToProcess
# NestedModules = @()

# Functions to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no functions to export.
FunctionsToExport = @('Invoke-SqlTemplate')

# Cmdlets to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no cmdlets to export.
CmdletsToExport = @()

# Variables to export from this module
VariablesToExport = @()

# Aliases to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no aliases to export.
AliasesToExport = @()

# DSC resources to export from this module
# DscResourcesToExport = @()

# List of all modules packaged with this module
# ModuleList = @()

# List of all files packaged with this module
FileList = @(
    '.\Wrappers\Aggregate.eps1.sql',
    '.\Wrappers\Concatenate.eps1.sql',
    '.\Wrappers\CTE.eps1.sql',
    '.\Wrappers\DateDiff.eps1.sql',
    '.\Wrappers\DateToString.eps1.sql',
    '.\Wrappers\ExecuteIfExists.eps1.sql',
    '.\Wrappers\GitHistory.eps1.sql',
    '.\Wrappers\Inline.eps1.sql',
    '.\Wrappers\JUnit.eps1.sql',
    '.\Wrappers\JUnitTest.eps1.sql',
    '.\Wrappers\Materialize.eps1.sql',
    '.\Wrappers\Mocha.eps1.sql',
    '.\Wrappers\NoLock.eps1.sql',
    '.\Wrappers\NUnit.eps1.sql',
    '.\Wrappers\NUnitTest.eps1.sql',
    '.\Wrappers\Procedure.eps1.sql',
    '.\Wrappers\QuotedId.eps1.sql',
    '.\Wrappers\RemoveAggregated.eps1.sql',
    '.\Wrappers\Sanitize.eps1.sql',
    '.\Wrappers\SelectSingle.eps1.sql',
    '.\Wrappers\StringLength.eps1.sql',
    '.\Wrappers\StringToDate.eps1.sql',
    '.\Wrappers\StringToInt.eps1.sql',
    '.\Wrappers\Substring.eps1.sql',
    '.\Wrappers\SubstringIndex.eps1.sql',
    '.\Wrappers\SystemDate.eps1.sql',
    '.\Wrappers\View.eps1.sql'
)

# Private data to pass to the module specified in RootModule/ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
PrivateData = @{

    PSData = @{

        # Tags applied to this module. These help with module discovery in online galleries.
        Tags = @('SQL','Template')

        # A URL to the license for this module.
        LicenseUri = 'https://opensource.org/licenses/MIT'

        # A URL to the main website for this project.
        ProjectUri = 'https://github.com/panasenco/sqltemplate'

        # A URL to an icon representing this module.
        # IconUri = ''

        # ReleaseNotes of this module
        # ReleaseNotes = ''

    } # End of PSData hashtable

} # End of PrivateData hashtable

# HelpInfo URI of this module
# HelpInfoURI = ''

# Default prefix for commands exported from this module. Override the default prefix using Import-Module -Prefix.
# DefaultCommandPrefix = ''

}

