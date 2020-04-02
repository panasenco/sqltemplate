<%#
.Synopsis
    Quotes the given identifier with quoting characters appropriate for the given server.
.Parameter Server
    The server to quote the identifier for.
.Parameter Body
    The identifier to quote.
-%>
<%-
switch -regex ($Server) {
    'ORA.*' {
-%>
"<%= $Body %>"<% -%>
<%-
    }
    'SS\d\d.*' {
-%>
[<%= $Body %>]<% -%>
<%-
    }
    default { Write-Error "Server $Server not yet supported for ID quoting." }
}
-%>
