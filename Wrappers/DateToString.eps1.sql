<%#
.Synopsis
    Converts dates to strings.
.Parameter Server
    The server to convert the dates in.
.Parameter Body
    The date expression to convert.
.Parameter Format
    The Oracle-style format mask to use for the conversion.
-%>
<%-
switch -regex ($Server) {
    'ORA.*' {
-%>
TO_CHAR(<%= $Body %>, '<%= $Format %>')<% -%>
<%-
    }
    'SS\d\d.*' {
        # Determine the T-SQL datetime style code
        $SqlStyleCode = switch ($Format) {
            'MM/DD/YYYY' { 101 }
            'YYYYMMDD'   { 112 }
            default { Write-Error "Can't find matching T-SQL style code for datetime format '$Format'" }
        }
-%>
CONVERT(char(8), <%= $Body %>, <%= $SqlStyleCode %>)<% -%>
<%-
    }
    default { Write-Error "Server $Server not yet supported for datetime to string conversion." }
}
-%>
