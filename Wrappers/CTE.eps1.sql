<%#
.Synopsis
    Wrapper to create a CTE from a given query.
-%>
<%= $ChildPath | Get-Basename %> AS (
  <%= ($Binding | Use-Sql -Path $ChildPath) -replace "`n","`n  " %>
)
