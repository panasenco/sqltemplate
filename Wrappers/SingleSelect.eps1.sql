<%#
.Synopsis
    SELECT expression for a one-row query. The FROM expression is blank in SQL Server, "FROM dual" in Oracle.
.Parameter Server
    The server to select the single row in.
.Parameter Body
    The expression to select as the single row.
-%>
<%-
switch -regex ($Server) {
    'ORA.*' {
-%>
SELECT <%= $Body %> FROM dual<% -%>
<%-
    }
    'SS\d\d.*' {
-%>
SELECT <%= $Body %><% -%>
<%-
    }
    default { Write-Error "Server $Server not yet supported for single selection." }
}
-%>
