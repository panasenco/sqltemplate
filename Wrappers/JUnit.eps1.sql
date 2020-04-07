<%#
.Synopsis
    JUnit XML wrapper for a test cases query.
    Handles CTEs gracefully by inserting header before first least indented select.
.Binding TestSuiteName
    Name of the test suite.
-%>
<%-
$PreHeaderIndex = (($Body | Select-String -Pattern '(\r?\n|^)[^\S\r\n]*SELECT' -AllMatches)[0].matches |
    Sort-Object -Property Length,Index)[0].Index
-%>
<%= $Body.Substring(0,$PreHeaderIndex) %>
<%= $Binding |
    Invoke-SqlTemplate -Template ("'<?xml version=" + '"1.0" encoding="UTF-8"?>' + "' AS test_result") `
    -Wrapper 'SelectSingle' %>
UNION ALL
<%= $Binding | Invoke-SqlTemplate -Template "'<testsuites>' AS test_result" -Wrapper 'SelectSingle' %>
UNION ALL
<%= $Binding |
    Invoke-SqlTemplate -Template ("'<testsuite name=" + '"' + $TestSuiteName + '"' + ">' AS test_result") `
    -Wrapper 'SelectSingle' %>
UNION ALL
<%= $Body.Substring($PreHeaderIndex) %>
UNION ALL
<%= $Binding | Invoke-SqlTemplate -Template "'</testsuite>' AS test_result" -Wrapper 'SelectSingle' %>
UNION ALL
<%= $Binding | Invoke-SqlTemplate -Template "'</testsuites>' AS test_result" -Wrapper 'SelectSingle' %>
