<%#
.Synopsis
    Outputs substring function - SUBSTR for Oracle, SUBSTRING for everything else.
.Parameter Server
    The server to output substring function for.
.Parameter Body
    The string to get substring from.
.Parameter Position
    The starting position of the substring. Defaults to 1 if not provided.
.Parameter Length
    The length of the substring.
-%>
<%-
if (-not $Position) { $Position = 1 }
switch -regex ($Server) {
    'ORA.*' {
-%>
SUBSTR(<%= $Body %>, <%= $Position %>, <%= $Length %>)<% -%>
<%-
    }
    default {
-%>
SUBSTRING(<%= $Body %>, <%= $Position %>, <%= $Length %>)<% -%>
<%-
    }
}
-%>
