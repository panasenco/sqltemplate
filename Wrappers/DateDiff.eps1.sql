<%#
.Synopsis
    Computes the difference between two dates in days.
.Parameter Server
    The server to find the date difference in.
.Parameter Body
    A string consisting of two lines separated by a newline:
    First line: The date expression of the start date.
    Second line: The date expression of the end date.
-%>
<%-
$StartDate, $EndDate = $Body -replace "`r" -split "`n"
switch -regex ($Server) {
    'ORA.*' {
-%>
<%= $EndDate %> - <%= $StartDate -%>
<%-
    }
    'SS\d\d.*' {
-%>
DATEDIFF(day, <%= $StartDate %>, <%= $EndDate %>)<% -%>
<%-
    }
    default { Write-Error "Server $Server not yet supported for date difference calculation." }
}
-%>
