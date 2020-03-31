<%#
.Synopsis
    Wrapper to create a stored procedure from a given query.
-%>
CREATE OR ALTER PROCEDURE <%= $Prefix -join '' %><%= $ChildPath | Get-Basename %> AS
BEGIN
  DECLARE @BenchmarkStartTime DATETIME;
  DECLARE @BenchmarkEndTime DATETIME;

  <%= ($ChildPath | Get-GitHistoryHeader) -replace "`n","`n  " %>
  <%= $Body -replace "`n","`n  " %>
END
