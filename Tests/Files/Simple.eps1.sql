SELECT <% $Columns | Each { %>'<%= $_ %>' AS <%= $_ %>, <% } %>4 AS x
