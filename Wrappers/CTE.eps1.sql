<%#
.Synopsis
    Wrapper to create a CTE from a given query.
-%>
<%= $ChildPath | Get-Basename %> AS (
  <%= $Body -replace "`n","`n  " %>
)
