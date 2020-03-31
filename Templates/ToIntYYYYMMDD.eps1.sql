<%#
.Synopsis
    Converts dates to yyyymmdd integers.
.Parameter Server
    The server to convert the dates in.
.Parameter Date
    The date expression to convert.
-%>
<%=
    switch -regex ($Server) {
        'SS\d\d.*' { ($Binding + @{StringExpression="CONVERT(char(8), $Date, 112)"}) | Use-Sql -Template 'ToInt' }
        'ORA.*' { ($Binding + @{StringExpression="TO_CHAR($Date, 'YYYYMMDD')"}) | Use-Sql -Template 'ToInt' }
        default { Write-Error "Server $Server not yet supported for date to yyyymmdd int conversion." }
    }
%>
