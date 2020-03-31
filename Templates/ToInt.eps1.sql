<%#
.Synopsis
    Converts strings to integers.
.Parameter Server
    The server to convert the strings in.
.Parameter StringExpression
    The string expression to convert to integer.
-%>
<%-
switch -regex ($Server) {
    'ORA.*' {
-%>
TO_NUMBER(<%= $StringExpression %>)
<%-
    }
    'SS\d\d.*' {
-%>
CAST(<%= $StringExpression %> AS int)
<%-
    }
    default { Write-Error "Server $Server not yet supported for string to integer conversion." }
}
-%>
