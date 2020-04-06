<%#
.Synopsis
    Wrapper to create a stored procedure from a given query.
.Parameter ProcedurePrefix
    The prefix (including trailing period if any) to prepend to the basename to construct the stored procedure name
-%>
CREATE OR ALTER PROCEDURE <%= $ProcedurePrefix %><%= $Basename %> AS
BEGIN
  <%= $Body -replace "`n","`n  " %>
END
