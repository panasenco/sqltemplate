<%#
.Synopsis
    NUnit XML wrapper for a single test case.
.Binding TableName
    Name of the table being tested.
.Binding TestName
    Name of the test case.
-%>
<%- $TableName = if ($TableName) {$TableName -replace '\.'} else {'customquery'} -%>
<%= $Binding | Invoke-SqlTemplate -Template ("'<test-case name=" + '"sqltest.' + $TableName + '.' +
    ($TestName -replace '\.') + '" executed="True" success="' + "'`r`n" +
    "CASE WHEN $Body THEN 'True' ELSE 'False' END`r`n" + "'" + '"' + "/>'") -Wrapper 'Concatenate' %> AS test_result
