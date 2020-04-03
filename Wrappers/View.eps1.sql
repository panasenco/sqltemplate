<%#
.Synopsis
    Wrapper to create a view with a given prefix from the query
-%>
CREATE OR ALTER VIEW <%= $Prefix %><%= $Basename %> AS
  <%= $Body -replace "`n","`n  " %>
