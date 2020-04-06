<%#
.Synopsis
    Wrapper to create a view with a given prefix from the query
.Parameter TablePrefix
    The prefix (including trailing period if any) to prepend to the basename to construct the view name
-%>
CREATE OR ALTER VIEW <%= $TablePrefix %><%= $Basename %> AS
  <%= $Body -replace "`n","`n  " %>
