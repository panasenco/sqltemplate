<%#
.Synopsis
    Concatenates a list in a server-appropriate manner.
.Parameter Server
    The server to concatenate the strings in.
.Parameter Body
    A string consisting of string expressions separated by newlines.
    The string expressions will be concatenated.
-%>
<%-
$StringExpressions = $Body -replace "`r" -split "`n"
switch -regex ($Server) {
    'ORA.*' {
-%>
<%= $StringExpressions -join ' || ' -%>
<%-
    }
    'SS\d\d.*' {
-%>
<%= $StringExpressions -join ' + ' -%>
<%-
    }
    default { Write-Error "Server $Server not yet supported for string concatenation." }
}
-%>
