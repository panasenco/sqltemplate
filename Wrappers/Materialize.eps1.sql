<%#
.Synopsis
    Wrapper to materialize a table from a given query. Meant to be called from MaterializationProcedure.
.Description
    In SQL Server, this is kind of a hack. First, find the last existing materialization (the index of the last FROM
    already following an INTO statement), if any.
    The INTO statement is inserted before the first of the least indented FROMs following the last existing
    materialization.
    The DROP statements are inserted before the first of the least indented WITHs or SELECTs preceding the above FROM
    and following the last existing materialization.
.Parameter TablePrefix
    The prefix (including trailing period if any) to prepend to the basename to construct the table name
-%>
<%-
if ($Server -notmatch '^SS.*') { Write-Error "Only SQL Server currently supported for materialization" }
# Find the index of the last existing INTO FROM statement
$LastExistingMaterialization = (($Body | Select-String -Pattern '(?<=INTO[^\r\n]*\r\n[^\S\r\n]*FROM)|^' `
    -AllMatches)[0].matches | Sort-Object -Property Index -Descending)[0].Index
# Find the index of the first FROM that is least indented and following the last existing materialization.
$PreIntoIndex = (($Body | Select-String -Pattern '\r?\n[^\S\r\n]*FROM' -AllMatches)[0].matches |
    Sort-Object -Property Length,Index | where {$_.Index -ge $LastExistingMaterialization})[0].Index
$PreDropIndex = (($Body | Select-String -Pattern '(\r?\n|^)[^\S\r\n]*(SELECT|WITH)' -AllMatches)[0].matches |
    Sort-Object -Property Length,Index | where {$_.Index -ge $LastExistingMaterialization -and `
    $_.Index -lt $PreIntoIndex })[0].Index
-%>
<%= $Body.Substring(0,$PreDropIndex) %>
<%- if ($Body -notmatch 'DECLARE @BenchmarkStartTime DATETIME;') { -%>
DECLARE @BenchmarkStartTime DATETIME;
DECLARE @BenchmarkEndTime DATETIME;
<%- } -%>
SET @BenchmarkStartTime = GETDATE();
IF OBJECT_ID('<%= $TablePrefix %><%= $Basename %>', 'V') IS NOT NULL DROP VIEW <%= $TablePrefix %><%= $Basename %>;
IF OBJECT_ID('<%= $TablePrefix %><%= $Basename %>', 'U') IS NOT NULL DROP TABLE <%= $TablePrefix %><%= $Basename %>;
<%= $Body.Substring($PreDropIndex, $PreIntoIndex-$PreDropIndex) %>
INTO <%= $TablePrefix %><%= $Basename -%>
<%= $Body.Substring($PreIntoIndex) %>
SET @BenchmarkEndTime = GETDATE();
SELECT FORMAT(DATEDIFF(millisecond, @BenchmarkStartTime, @BenchmarkEndTime)/1000.0, '.##') +
    's to create <%= $TablePrefix %><%= $Basename %>' AS msg
