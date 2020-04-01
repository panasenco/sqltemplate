<%#
.Synopsis
    Gets the length of a character string.
.Parameter Server
    The server to get the length in.
.Parameter Body
    The string expression to find the length of.
-%>
<%-
switch -regex ($Server) {
    'ORA.*' {
-%>
LENGTH(<%= $Body %>)<% -%>
<%-
    }
    'SS\d\d.*' {
-%>
LEN(<%= $Body %>)<% -%>
<%-
    }
    default { Write-Error "Server $Server not yet supported for string length finding." }
}
-%>
