<%#
.Synopsis
    Wrapper to materialize a given query.
.Description
    In SQL Server, this is kind of a hack in that it relies on top-level SELECT, INTO, FROM, UNION, and WITH statements
    to be on their own lines and not indented at all.
    First, find the last existing materialization (the index of the last FROM already following an INTO statement), if any.
    The INTO statement is inserted before the first of the least indented FROMs following the last existing
    materialization.
    The DROP statements are inserted before the first of the least indented WITHs or SELECTs preceding the above FROM
    and following the last existing materialization.
.Parameter TablePrefix
    The prefix (including trailing period if any) to prepend to the basename to construct the table name
-%>
<%-
if ($Server -notmatch '^SS.*') { Write-Error "Only SQL Server currently supported for materialization" }
# Loop through the lines to find where to place statements
$BodyLines = $Body -split "`r?`n"
$PreDropIndex = $null
$PreIntoIndex = $null
for ($LineIndex=0; $LineIndex -lt $BodyLines.Length; $LineIndex++) {
    switch -regex ($BodyLines[$LineIndex]) {
        '^INTO' {
            # There is existing materialization - Reset the pre-into and pre-drop indices
            $PreDropIndex = $null
            $PreIntoIndex = $null
        }
        '^(WITH|SELECT)' {
            # Ensure this is the first WITH/SELECT not preceded by a UNION
            if ($PreDropIndex -eq $null -and ($LineIndex -lt 1 -or $BodyLines[$LineIndex-1] -notmatch '^UNION')) {
                $PreDropIndex = $LineIndex
            }
        }
        '^FROM' {
            # Ensure this is the first FROM following the pre-drop line
            if ($PreDropIndex -ne $null -and $PreIntoIndex -eq $null) {
                $PreIntoIndex = $LineIndex
            }
        }
    }
}
-%>
<%- if ($PreDropIndex -ge 1) { -%>
<%= $BodyLines[0..($PreDropIndex-1)] -join "`r`n" %>
<%- } -%>
IF OBJECT_ID('<%= $TablePrefix %><%= $Basename %>', 'V') IS NOT NULL DROP VIEW <%= $TablePrefix %><%= $Basename %>;
IF OBJECT_ID('<%= $TablePrefix %><%= $Basename %>', 'U') IS NOT NULL DROP TABLE <%= $TablePrefix %><%= $Basename %>;
<%= $BodyLines[$PreDropIndex..($PreIntoIndex-1)] -join "`r`n" %>
INTO <%= $TablePrefix %><%= $Basename %>
<%= $BodyLines[$PreIntoIndex..($BodyLines.Length-1)] -join "`r`n" %>
