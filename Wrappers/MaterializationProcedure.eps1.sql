<%#
.Synopsis
    Wrapper to create a stored procedure from a given query.
-%>
CREATE OR ALTER PROCEDURE <%= $Prefix -join '' %><%= $ChildPath | Get-Basename %> AS
BEGIN
  DECLARE @BenchmarkStartTime DATETIME;
  DECLARE @BenchmarkEndTime DATETIME;

  <%= $ChildPath | Get-GitHistoryHeader %>
  <%= ($Binding | Use-Sql -Path $ChildPath -Wrapper Materialize) -replace "`n","`n  " %>
END
