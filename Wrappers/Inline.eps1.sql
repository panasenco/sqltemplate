<%#
.Synopsis
    Wrapper to create an inline view from the query
-%>
(
  <%= $Body -replace "`n","`n  " %>
) <%= $Basename %>
