sqltemplate
===========
SqlTemplate is a templating tool based on [Embedded PowerShell](http://straightdave.github.io/eps/) that aims to
resolve the following frequent SQL pain points:


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


Generating many similar columns 
-------------------------------
Pivot tables are evil, incomprehensible, and impossible to optimize. With SqlTemplate you can take full advantage of
[Embedded PowerShell](https://github.com/straightdave/eps) and generate view columns using scripting. For example:

```
> @{Columns=@('a','b','c')} | Invoke-SqlTemplate -Template 'SELECT <% $Columns | Each { %><%= $_ %> AS <%= $_ %>, <% } %>4 AS x'
SELECT a AS a, b AS b, c AS c, 4 AS x
```
