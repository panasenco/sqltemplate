<%#
.Synopsis
    NUnit XML wrapper for a single test case.
.Binding GroupName
    Name of the test group (e.g. table being tested).
.Binding TestName
    Name of the test case.
-%>
<%- $GroupName = if ($GroupName) {$GroupName -replace '\.'} else {'customquery'} -%>
<%= $Binding | Invoke-SqlTemplate -Template ("'<test-case name=" + '"sqltest.' + $GroupName + '.' +
    ($TestName -replace '\.') + '" executed="True" success="' + "'`r`n" +
    "CASE WHEN $Body THEN 'True' ELSE 'False' END`r`n" + "'" + '"' + "/>'") -Wrapper 'Concatenate' %> AS test_result
