/*****************************************    SQLTEMPLATE STANDARD WRAPPER    *****************************************
** Name: JUnit
** Description: JUnit XML wrapper for a test cases query.
** Parameters:
**     * TestSuiteName: Name of the test suite.
** Owners: Aram Panasenco <apanasenco@coh.org>
**********************************************************************************************************************/
SELECT '<?xml version="1.0" encoding="UTF-8"?>' AS test_result <%= New-SingleSelectFrom $Server %> UNION ALL
SELECT '<testsuites>' AS test_result <%= New-SingleSelectFrom $Server %> UNION ALL
SELECT '<testsuite name="<%= $TestSuiteName %>">' AS test_result <%= New-SingleSelectFrom $Server %> UNION ALL
<%= $Body %>
UNION ALL
SELECT '</testsuite>' AS test_result <%= New-SingleSelectFrom $Server %> UNION ALL
SELECT '</testsuites>' AS test_result <%= New-SingleSelectFrom $Server %>
