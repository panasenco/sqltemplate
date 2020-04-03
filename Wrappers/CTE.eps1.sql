<%#
.Synopsis
    Wrapper to create a CTE from a given query.
-%>
<%= $Basename %> AS (
  <%= $Body -replace "`n","`n  " %>
)
