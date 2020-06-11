<%#
.Synopsis
    NUnit XML wrapper for a test cases query.
    Handles CTEs gracefully by inserting header before first least indented select.
-%>
<%-
$PreHeaderIndex = (($Body | Select-String -Pattern '(\r?\n|^)[^\S\r\n]*SELECT' -AllMatches)[0].matches |
    Sort-Object -Property Length,Index)[0].Index
-%>
<%= $Body.Substring(0,$PreHeaderIndex) %>
<%= $Binding | Invoke-SqlTemplate -Template `
    ("'" + '<?xml version="1.0" encoding="UTF-8"?><test-results><test-suite><results>' + "' AS test_result") `
    -Wrapper 'SelectSingle' %>
UNION ALL
<%= $Body.Substring($PreHeaderIndex) -replace '^\r?\n' %>
UNION ALL
<%= $Binding | Invoke-SqlTemplate -Template "'</results></test-suite></test-results>' AS test_result" -Wrapper 'SelectSingle' %>
