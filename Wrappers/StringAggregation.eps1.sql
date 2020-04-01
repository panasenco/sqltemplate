<%#
.Synopsis
    Generates a string aggregation statement for grouped queries.
.Parameter Server
    The server to generate the aggregation statement for.
.Parameter Body
    The SQL expression to aggregate.
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
-%>
STUFF((
      SELECT
        N'<%= $Separator %>' + <%= $Body %>
      FROM <%= $Table %> t2
      WHERE <%= $Table %>.<%= $Field %>=t2.<%= $Field %>
      ORDER BY <%= $Order %>
      FOR XML PATH (N''), ROOT('root'), type
      ).value('/root[1]','VARCHAR(MAX)')
    , 1, <%= $($Separator.Length) %>, N'') 
<%-
    }
    default { Write-Error "Server $Server not yet supported for list aggregation" }
}
-%>
