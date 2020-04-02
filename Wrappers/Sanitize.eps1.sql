<%#
.Synopsis
    Sanitizes provided input string, making sure the output is free of nonprinting characters.
.Parameter Server
    The server to quote the identifier for.
.Parameter Body
    The string expression to sanitize.
-%>
<%-
switch -regex ($Server) {
    'ORA.*' {
-%>
<%# This is the desired effect - just removing special characters -%>
REGEXP_REPLACE(<%= $Body %>, '[[:cntrl:]]')<% -%>
<%-
    }
    'SS\d\d.*' {
-%>
<%# This does additional processing in addition to sanitizing, but it gets the job done. -%>
STRING_ESCAPE(<%= $Body %>, 'json')<% -%>
<%-
    }
    default { Write-Error "Server $Server not yet supported for string sanitization." }
}
-%>
