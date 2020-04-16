<%#
.Synopsis
    Wrapper to execute a stored procedure only if it exists.
-%>
<%- if ($Server -notmatch '^SS.*') { Write-Error "Only SQL Server currently supported for conditional execution" } -%>
IF OBJECT_ID('<%= $Body %>', 'P') IS NOT NULL
  EXEC <%= $Body %>;
