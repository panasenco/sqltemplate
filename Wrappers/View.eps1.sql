<%#
.Synopsis
    Wrapper to create a view with a given prefix from the query
-%>
CREATE OR ALTER VIEW <%= $Prefix %><%= $ChildPath | Get-SqlBasename %> AS
  <%= $Body -replace "`n","`n  " %>
