<%#
.Synopsis
    Mocha JSON wrapper for a test cases query.
    Handles CTEs gracefully by inserting header before first least indented select.
.Binding TestSuiteName
    Name of the test suite.
-%>
<%-
$SelectMatches = $Body | Select-String -Pattern '(\r?\n|^)[^\S\r\n]*SELECT' -AllMatches
if ($SelectMatches) {
    $PreHeaderIndex = ($SelectMatches.matches | Sort-Object -Property Length,Index)[0].Index
    $LastSelectIndex = ($SelectMatches.matches | Sort-Object -Property Index -Descending)[0].Index
} else {
    $PreHeaderIndex = 0
    $LastSelectIndex = 0
}
-%>
<%= $Body.Substring(0, $PreHeaderIndex) %>
<%= $Binding | Invoke-SqlTemplate -Template ("'" + '{ "suite": {' + "' AS test_result") -Wrapper 'SelectSingle' %>
UNION ALL
<%= $Binding | Invoke-SqlTemplate -Template ("'" + '"title": "' + $TestSuiteName + '",' + "' AS test_result") `
    -Wrapper 'SelectSingle' %>
UNION ALL
<%= $Binding | Invoke-SqlTemplate -Template ("'" + '"tests": [' + "' AS test_result") -Wrapper 'SelectSingle' %>
UNION ALL
<%= $Body.Substring($PreHeaderIndex, $LastSelectIndex-$PreHeaderIndex) -replace '^\r?\n' %>
<%= $Body.Substring($LastSelectIndex) -replace '^\r?\n' -replace ",(?=\s*')" %>
UNION ALL
<%= $Binding | Invoke-SqlTemplate -Template "']' AS test_result" -Wrapper 'SelectSingle' %>
UNION ALL
<%= $Binding | Invoke-SqlTemplate -Template "'} }' AS test_result" -Wrapper 'SelectSingle' %>
