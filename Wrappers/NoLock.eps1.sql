<%#
.Synopsis
    Wrapper to ensure selects from tables from certain databases are always followed with a (NOLOCK) suffix.
.Description
    ETL processes in data warehousing environments fail when a query holds a long-running select lock on the data.
    This forces the query designers to use (NOLOCK) hints. This wrapper automatically appends (NOLOCK) hints after
    every table found with the provided database list.
.Parameter AppendNoLock
    The regex that matches the database+schema of the tables to append the (NOLOCK) hints after.
-%>
<%- if ($Server -notmatch '^SS.*') { Write-Error "Only SQL Server currently supported for conditional execution" } -%>
<%=
if ($AppendNoLock) {
    $AppendNoLock = $AppendNoLock -replace '\.','\.' -join '|'
    $Body -replace "(($AppendNoLock)\.\w+(?=\s|$))",'$1 (NOLOCK)'
} else {
    $Body
}
%>
