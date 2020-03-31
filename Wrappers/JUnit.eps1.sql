<%#
.Synopsis
    JUnit XML wrapper for a test cases query.
.Binding TestSuiteName
    Name of the test suite.
-%>
SELECT '<?xml version="1.0" encoding="UTF-8"?>' AS test_result <%= New-SingleSelectFrom $Server %> UNION ALL
SELECT '<testsuites>' AS test_result <%= New-SingleSelectFrom $Server %> UNION ALL
SELECT '<testsuite name="<%= $TestSuiteName %>">' AS test_result <%= New-SingleSelectFrom $Server %> UNION ALL
<%= $Body %>
UNION ALL
SELECT '</testsuite>' AS test_result <%= New-SingleSelectFrom $Server %> UNION ALL
SELECT '</testsuites>' AS test_result <%= New-SingleSelectFrom $Server %>
