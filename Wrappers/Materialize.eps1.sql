<%#
.Synopsis
    Wrapper to materialize a table from a given query. Meant to be called from MaterializationProcedure.
-%>
$Basename = $ChildPath | Get-Basename
$Body = $Binding | Use-Sql -Path $ChildPath
# Insert pre-creation drop and benchmark initialization blocks after the last benchmark completion block,
# or at the beginning of the body if there is no benchmark completion block in the body.
$PreCreationIndex = (($Body | Select-String -Pattern '(?<=@BenchmarkStartTime,\s*@BenchmarkEndTime[^\r]+\r\n)|^' `
    -AllMatches)[0].matches | Sort-Object -Descending -Property Index)[0].Index
$PostCreationBody = $Body.Substring($PreCreationIndex) 
# Find the index of the first FROM that is least indented and not already following an INTO.
$MainFromIndex = (($PostCreationBody | Select-String -Pattern '(?<=[\n])[^\S\r\n]*FROM' `
    -AllMatches)[0].matches | Sort-Object -Property Length,Index)[0].Index
-%>
<%= $Body.Substring(0,$PreCreationIndex) %>
SET @BenchmarkStartTime = GETDATE();
IF OBJECT_ID('<%= $Prefix[0] %><%= $Basename %>', 'U') IS NOT NULL DROP TABLE <%= $Prefix[0] %><%= $Basename %>;
IF OBJECT_ID('<%= $Prefix[0] %><%= $Basename %>', 'V') IS NOT NULL DROP VIEW <%= $Prefix[0] %><%= $Basename %>;
<%= $PostCreationBody.Substring(0,$MainFromIndex) -%>
INTO <%= $Prefix[0] %><%= $Basename %>
<%= $PostCreationBody.Substring($MainFromIndex) %>
SET @BenchmarkEndTime = GETDATE();
SELECT FORMAT(DATEDIFF(millisecond, @BenchmarkStartTime, @BenchmarkEndTime)/1000.0, '.##') +
    's to create <%= $Prefix[0] %><%= $Basename %>' AS msg
