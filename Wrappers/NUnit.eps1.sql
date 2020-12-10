<%#
.Synopsis
    NUnit XML wrapper for a test cases query.
    Handles CTEs gracefully by inserting header before first least indented select.
.Binding NUnit_*
    These bindings are placed as properties of the test suite.
-%>
<%-
$PreHeaderIndex = (($Body | Select-String -Pattern '(\r?\n|^)[^\S\r\n]*SELECT' -AllMatches)[0].matches |
    Sort-Object -Property Length,Index)[0].Index
$Properties = $Binding.Keys | foreach {
    $PropNames = $_ | Select-String -Pattern '(?<=^NUnit).*'
    if ($PropNames.Count -gt 0) {
        '<property name="' + $PropNames.Matches[0].Value + '" value= "' + $Binding[$_] + '"/>"'
    }
}
if ($Properties.Count -gt 0) {
    $PropertiesString = "<properties>$($Properties -join '')</properties>"
} else {
    $PropertiesString = ''
}
-%>
<%= $Body.Substring(0,$PreHeaderIndex) %>
<%= $Binding | Invoke-SqlTemplate -Template `
    ("'" + '<?xml version="1.0" encoding="UTF-8"?><test-results><test-suite>' + $PropertiesString + '<results>' + `
     "' AS test_result") -Wrapper 'SelectSingle' %>
UNION ALL
<%= $Body.Substring($PreHeaderIndex) -replace '^\r?\n' %>
UNION ALL
<%= $Binding | Invoke-SqlTemplate -Template "'</results></test-suite></test-results>' AS test_result" -Wrapper 'SelectSingle' %>
