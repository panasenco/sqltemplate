<%#
.Synopsis
    Wrapper to create an inline view from the query
-%>
(
  <%= ($Binding | Use-Sql -Path $ChildPath) -replace "`n","`n  " %>
) <%= $ChildPath | Get-Basename %>
