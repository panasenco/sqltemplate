<%#
.Synopsis
    Wrapper to create a CTE from a given query.
-%>
<%= $ChildPath | Get-SqlBasename %> AS (
  <%= $Body -replace "`n","`n  " %>
)
