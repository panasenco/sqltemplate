<%#
.Synopsis
    Converts strings to dates.
.Parameter Server
    The server to convert the strings in.
.Parameter Body
    The string expression to convert to date.
.Parameter FromFormat
    The Oracle-style format mask to use for the conversion.
-%>
<%-
switch -regex ($Server) {
    'ORA.*' {
-%>
TO_DATE(<%= $Body %>, '<%= $FromFormat %>')<% -%>
<%-
    }
    'SS\d\d.*' {
        # Determine the T-SQL datetime style code
        $SqlStyleCode = switch ($FromFormat) {
            'MM/DD/YYYY' { 101 }
            'YYYYMMDD'   { 112 }
            default { Write-Error "Can't find matching T-SQL style code for datetime format '$FromFormat'" }
        }
-%>
CONVERT(DATETIME, <%= $Body %>, <%= $SqlStyleCode %>)<% -%>
<%-
    }
    default { Write-Error "Server $Server not yet supported for string to datetime conversion." }
}
-%>
