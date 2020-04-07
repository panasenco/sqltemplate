<%#
.Synopsis
    JUnit XML wrapper for a single test case.
.Binding TestName
    Name of the test case.
-%>
<%= $Binding | Invoke-SqlTemplate -Template ("'<testcase name=" + '"' + $TestName + '">' + "'" + "`r`n" +
    "CASE WHEN $Body THEN '' ELSE '<failure/>' END`r`n" +
    "'</testcase>'") -Wrapper 'Concatenate' %> AS test_result
