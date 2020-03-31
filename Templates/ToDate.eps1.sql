<%#
.Synopsis
    Converts strings to dates.
.Parameter Server
    The server to convert the strings in.
.Parameter StringExpression
    The string expression to convert to date.
.Parameter Format
    The Oracle-style format mask to use for the conversion.
-%>
<%-
switch -regex ($Server) {
    'ORA.*' {
-%>
TO_DATE(<%= $StringExpression %>, '<%= $Format %>')
<%-
    }
    'SS\d\d.*' {
        # Determine the T-SQL datetime style code
        $SqlStyleCode = switch ($Format) {
            'MM/DD/YYYY' { 101 }
            default { Write-Error "Can't find matching T-SQL style code for datetime format '$Format'" }
        }
-%>
CONVERT(DATETIME, <%= $StringExpression %>, <%= $SqlStyleCode %>)
<%-
    }
    default { Write-Error "Server $Server not yet supported for string to datetime conversion." }
}
-%>
