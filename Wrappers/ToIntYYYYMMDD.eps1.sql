<%#
.Synopsis
    Converts dates to yyyymmdd integers.
.Parameter Server
    The server to convert the dates in.
.Parameter Body
    The date expression to convert.
-%>
<%=
    switch -regex ($Server) {
        'SS\d\d.*' { $Binding | Use-Sql -Template "CONVERT(char(8), $Body, 112)" -Wrapper 'ToInt' }
        'ORA.*' { $Binding | Use-Sql -Template "TO_CHAR($Body, 'YYYYMMDD')" -Wrapper 'ToInt' }
        default { Write-Error "Server $Server not yet supported for date to yyyymmdd int conversion." }
    }
-%>
