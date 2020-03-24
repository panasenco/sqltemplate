<%#
.Synopsis
    Wrapper to create a view with a given prefix from the query
-%>
CREATE OR ALTER VIEW <%= $Prefix %><%= $ChildPath | Get-Basename %> AS
  <%= $ChildPath | Get-GitHistoryHeader %>
  <%= ($Binding | Use-Sql -Path $ChildPath) -replace "`n","`n  " %>
