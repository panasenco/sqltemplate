<%#
.Synopsis
    Converts strings to integers.
.Parameter Server
    The server to convert the strings in.
.Parameter Body
    The string expression to convert to integer.
-%>
<%-
switch -regex ($Server) {
    'ORA.*' {
-%>
TO_NUMBER(<%= $Body %>)
<%-
    }
    'SS\d\d.*' {
-%>
CAST(<%= $Body %> AS int)
<%-
    }
    default { Write-Error "Server $Server not yet supported for string to integer conversion." }
}
-%>
