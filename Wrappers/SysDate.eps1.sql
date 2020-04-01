<%#
.Synopsis
    Gets the current system date (no time component).
.Parameter Server
    The server to get the system date for.
-%>
<%-
switch -regex ($Server) {
    'ORA.*' {
-%>
SYSDATE<% -%>
<%-
    }
    'SS\d\d.*' {
-%>
CAST(SYSDATETIME() AS date)<% -%>
<%-
    }
    default { Write-Error "Server $Server not yet supported for system date retrieval." }
}
-%>
