<%#
.Synopsis
    Outputs substring index function - INSTR for Oracle, CHARINDEX for SQL Server.
.Parameter Server
    The server to output the substring index function for.
.Parameter Body
    The string expression to find the substring in.
.Parameter Substring
    The substring expression to search for in the string.
-%>
<%-
switch -regex ($Server) {
    'ORA.*' {
-%>
INSTR(<%= $Body %>, <%= $Substring %>)<% -%>
<%-
    }
    'SS\d\d.*' {
-%>
CHARINDEX(<%= $Substring %>, <%= $Body %>)<% -%>
<%-
    }
    default { Write-Error "Server $Server not yet supported for substring indexing." }
}
-%>
