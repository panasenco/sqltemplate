<#
.Synopsis
    Processes a SQL Embedded PowerShell template (https://github.com/panasenco/sqltemplate).
.Description
    SqlTemplate is a templating tool based on Embedded PowerShell that aims to resolve the following frequent SQL pain
    points:
     * Reusing subqueries and CTEs across multiple queries
     * Writing queries meant to run on different SQL platforms
     * Generating many similar columns
    Read the guide and browse the source code at https://github.com/panasenco/sqltemplate
.Parameter Binding
    Hashtable containing value bindings to pass on to Invoke-EpsTemplate. There are some reserved bindings:
     - Server: The type of server to compile the query for. The server binding allows the use of platform-agnostic
           cmdlets like New-Concat, New-StringAgg, New-ToDate, and more in your EPS template files.
     - Body: The body of the nested template for wrapper templates.
     - ChildPath: The path to the nested template file for wrapper templates.
     - Basename: The nested template's name (e.g. basename of ChildPath) for wrapper templates.
.Parameter Path
    The path to the .eps1.sql template file to apply (does not modify the file, just goes to stdout).
    NOTE The file is only processed with EPS templating if the path ends in .eps1.sql!
.Parameter Template
    The string template to apply.
.Parameter Wrapper
    Array of names of standard wrapper templates (in the Wrappers directory of the SqlTemplate module) to apply, in
    order from innermost to outermost.
.Example
    Reusing subqueries and CTEs across multiple queries
    ---------------------------------------------------
    In the worlds of reporting and data warehousing, situations arise where creating views is more trouble than it's worth:
     * You may want to be able to run the same complex query on multiple different servers. Keeping those views in sync
       would become a synchronization nightmare.
     * You may have requirements to redo QC and end-user validation for each change to a reporting view, no matter how
       small. Then each change to a view that 10 reports depend on would trigger 10 rounds of QC.
     * You may want to create a report that you can send to a colleague at a different institution who's using the same
       type of system.
     * You may not have the security access to create views on the server you want to query.
    This is equivalent to static linking in the software development world.

    With SqlTemplate, reusing subqueries and CTEs is very easy. Suppose you have the following 3 files:

    **subquery1.eps1.sql**
    ```
    SELECT 'This is the first subquery' AS var1
    ```

    **subquery2.eps1.sql**
    ```
    SELECT 'This is the second subquery' AS var2
    ```


    **subquery3.eps1.sql**
    ```
    SELECT 'This is the third subquery' AS var3
    ```

    Then you can create the following file that can use them without having to copy-and-paste their contents:

    **mainquery.eps1.sql**
    ```
    WITH <%= Invoke-SqlTemplate -Path .\subquery1.eps1.sql -Wrapper 'CTE' %>,
    <%= Invoke-SqlTemplate -Path .\subquery2.eps1.sql -Wrapper 'CTE' %>
    SELECT
      subquery1.var1,
      subquery2.var2,
      subquery3.var3
    FROM subquery1
    LEFT JOIN subquery2 ON 2=2
    LEFT JOIN <%= Invoke-SqlTemplate -Path .\subquery3.eps1.sql -Wrapper 'Inline' %> ON 3=3
    ```
    Note that the two special wrappers 'CTE' and 'Inline' above allow you to easily include CTEs and subqueries without
    having to worry about the indentation and formatting:

    Invoking the template shows that it successfully included the subqueries:
    ```
    > Invoke-SqlTemplate -Path .\mainquery.eps1.sql
    WITH subquery1 AS (
      SELECT 'This is the first subquery' AS var1
    ),
    subquery2 AS (
      SELECT 'This is the second subquery' AS var2
    )
    SELECT
      subquery1.var1,
      subquery2.var2,
      subquery3.var3
    FROM subquery1
    LEFT JOIN subquery2 ON 2=2
    LEFT JOIN (
      SELECT 'This is the third subquery' AS var3
    ) subquery3 ON 3=3
    ```
.Example
    Writing queries meant to run on different SQL platforms
    -------------------------------------------------------
    In a data warehousing setting, you will frequently want to run the same query on data in the source system as well as
    data in the data warehouse to identify possible ETL issues. SqlTemplate allows you to write one file that will
    'compile' to the syntax of a particular SQL implementation.

    Here's an example that shows how to generate a substring command on Oracle and SQL Server:
    ```
    > @{Server='ORA'; Substring="'def'"} | Invoke-SqlTemplate -Template "'abcdefghijk'" -Wrapper 'SubstringIndex'
    INSTR('abcdefghijk', 'def')
    > @{Server='SS13'; Substring="'def'"} | Invoke-SqlTemplate -Template "'abcdefghijk'" -Wrapper 'SubstringIndex'
    CHARINDEX('def', 'abcdefghijk')
    ```

    Wrappers can be nested. Suppose you want to select the above substring as a single row. Single-row selection is
    implemented differently in [Oracle and SQL Server](https://stackoverflow.com/a/35254602/12981893):
    ```
    > @{Server='ORA'; Substring="'def'"} | Invoke-SqlTemplate -Template "'abcdefghijk'" -Wrapper 'SubstringIndex','SelectSingle'
    SELECT INSTR('abcdefghijk', 'def') FROM dual
    > @{Server='SS13'; Substring="'def'"} | Invoke-SqlTemplate -Template "'abcdefghijk'" -Wrapper 'SubstringIndex','SelectSingle'
    SELECT CHARINDEX('def', 'abcdefghijk')
    ```

    Finally, wrappers can of course be included as parts of larger queries using standard
    [EPS templating](https://github.com/straightdave/eps). Suppose you have a file example.eps1.sql (the extension is
    important - Invoke-SqlTemplate won't attempt template processing without it) with the following contents:

    **example.eps1.sql**
    ```
    SELECT
      Customers.key,
      <%= ($Binding + @{ToFormat='YYYYMMDD'}) | Invoke-SqlTemplate -Template 'Purchases.date' `
          -Wrapper 'DateToString','StringToInt' %> AS PurchaseDateKey,
      <%= ($Binding +
              @{Length=($Binding + @{Substring="' '"}) |
                  Invoke-SqlTemplate -Template 'Purchases.fullname' -Wrapper 'SubstringIndex'
              }) | Invoke-SqlTemplate -Template 'Purchases.fullname' -Wrapper 'Substring'
      %> AS PurchaseCode
    FROM Purchases
    LEFT JOIN Customers ON Purchases.customer_key = Customers.key
    ```
    Note that the special variable $Binding above is a copy of the hash table that was piped to the top-level call to
    Invoke-SqlTemplate. It must be explicitly passed to sub-templates to allow the variables to propagate.

    This one template file can produce different queries for different server implementations:
    ```
    > @{Server='ORA'} | Invoke-SqlTemplate -Path .\example.eps1.sql
    SELECT
      Customers.key,
      TO_NUMBER(TO_CHAR(Purchases.date, 'YYYYMMDD')) AS PurchaseDateKey,
      SUBSTR(Purchases.fullname, 1, INSTR(Purchases.fullname, ' ')) AS PurchaseCode
    FROM Purchases
    LEFT JOIN Customers ON Purchases.customer_key = Customers.key
    ```
    ```
    > @{Server='SS13'} | Invoke-SqlTemplate -Path .\example.eps1.sql
    SELECT
      Customers.key,
      CAST(CONVERT(char(8), Purchases.date, 112) AS int) AS PurchaseDateKey,
      SUBSTRING(Purchases.fullname, 1, CHARINDEX(' ', Purchases.fullname)) AS PurchaseCode
    FROM Purchases
    LEFT JOIN Customers ON Purchases.customer_key = Customers.key
    ```
.Example
    Generating many similar columns 
    -------------------------------
    Pivot tables are evil, incomprehensible, and impossible to optimize. With SqlTemplate you can take full advantage of
    [Embedded PowerShell](https://github.com/straightdave/eps) and generate view columns using scripting. For example:

    ```
    > @{Columns=@('a','b','c')} | Invoke-SqlTemplate -Template 'SELECT <% $Columns | Each { %><%= $_ %> AS <%= $_ %>, <% } %>4 AS x'
    SELECT a AS a, b AS b, c AS c, 4 AS x
    ```
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
    
    # Trim trailing whitespace
    $Body = $Body -replace '\s*$'
    
    if ($Wrapper) {
        # Create a clean copy of the binding
        $BindingCopy = $Binding.Clone()
        if ($Path -and -not $Binding.Basename) {
            $BindingCopy.Add('Basename', ((Get-Item -Path $Path).BaseName -split '\.')[0])
        }
        $BindingCopy.Remove('Body')
        $BindingCopy.Remove('ChildPath')
        $BindingCopy.Add('ChildPath', $Path)
        # Apply the wrappers in order from innermost to outermost
        $ModuleFileList = Get-Item (Get-Module -Name SqlTemplate).FileList
        foreach ($WrapperName in $Wrapper) {
            $WrapperFile = $ModuleFileList | where {$_.Basename -eq "$WrapperName.eps1"}
            if (-not $WrapperFile) {
                throw ("Can't find wrapper $WrapperName. Please ensure it's in the Wrappers directory and listed " +
                    "in FileList in SqlTemplate.psd1.")
            }
            $Body = ($BindingCopy + @{Body=$Body}) | Invoke-SqlTemplate -Path $WrapperFile
        }
    }
    
    $Body
}
