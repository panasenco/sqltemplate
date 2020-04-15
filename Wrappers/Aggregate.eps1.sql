<%#
.Synopsis
    Generates a string aggregation statement for grouped queries.
.Parameter Server
    The server to generate the aggregation statement for.
.Parameter Body
    The SQL expression to aggregate.
.Parameter GroupField
    SS13 ONLY. The fully qualified field to group by. The part after the last period is assumed to be the field name.
    The part before the last period is assumed to be the fully qualified table name. Only mandatory for SQL Server 13.
.Parameter Filter
    SS13 ONLY. WHERE filter to apply to the table before aggregating.
.Parameter Separator
    The separator to use when aggregating.
.Parameter Order
    Order of aggregation.
-%>
<%-
switch -regex ($Server) {
    'ORA.*' {
-%>
LISTAGG(<%= $Body %>, '<%= $Separator %>') WITHIN GROUP (ORDER BY <%= $Order %>)<% -%>
<%-
    }
    'SS\d\d.*' {
        if ($GroupField) {
            # Do not just split by period because the table name could contain periods.
            $Table = ($GroupField | Select-String -Pattern '.*(?=\.[^\.]*)').Matches[0].Value
            $Field = ($GroupField | Select-String -Pattern '[^\.]*$').Matches[0].Value
        } else {
            Write-Error 'GroupField param mandatory for SQL Server 13'
        }
-%>
STUFF((
      SELECT
        N'<%= $Separator %>' + <%= $Body %>
      FROM <%= $Table %> t2
      WHERE <%= $Table %>.<%= $Field %> = t2.<%= $Field %><% if ($Filter) { %>
        AND <%= $Filter %><% } %>
      ORDER BY <%= $Order %>
      FOR XML PATH (N''), ROOT('root'), type
      ).value('/root[1]','VARCHAR(MAX)')
    , 1, <%= $($Separator.Length) %>, N'') 
<%-
    }
    default { Write-Error "Server $Server not yet supported for string aggregation" }
}
-%>
