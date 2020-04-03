<%#
.Synopsis
    Wrapper to create a stored procedure from a given query.
-%>
CREATE OR ALTER PROCEDURE <%= $Prefix -join '' %><%= $Basename %> AS
BEGIN
  DECLARE @BenchmarkStartTime DATETIME;
  DECLARE @BenchmarkEndTime DATETIME;

  <%= $Body -replace "`n","`n  " %>
END