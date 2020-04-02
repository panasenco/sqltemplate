<%#
.Synopsis
    JUnit XML wrapper for a test cases query.
.Binding TestSuiteName
    Name of the test suite.
-%>
<%= $Binding |
  Use-Sql -Template ("'<?xml version=" + '"1.0" encoding="UTF-8"?>' + "' AS test_result") -Wrapper 'SelectSingle' %>
UNION ALL
<%= $Binding | Use-Sql -Template "'<testsuites>' AS test_result" -Wrapper 'SelectSingle' %>
UNION ALL
<%= $Binding |
  Use-Sql -Template ("'<testsuite name=" + '"' + $TestSuiteName + '"' + ">' AS test_result") -Wrapper 'SelectSingle' %>
UNION ALL
<%= $Body %>
UNION ALL
<%= $Binding | Use-Sql -Template "'</testsuite>' AS test_result" -Wrapper 'SelectSingle' %>
UNION ALL
<%= $Binding | Use-Sql -Template "'</testsuites>' AS test_result" -Wrapper 'SelectSingle' %>
