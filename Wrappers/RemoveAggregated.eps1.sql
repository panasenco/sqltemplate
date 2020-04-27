<%#
.Synopsis
    Removes values from aggregated strings.
.Parameter Body
    The aggregated string to remove values from.
.Parameter Separator
    The separator used during aggregation.
.Parameter RemoveList
    List of values to remove from body.
-%>
<%=
$ExpandedList = ($RemoveList | foreach {"$Separator$_"}) + ($RemoveList | foreach {"$_$Separator"}) + $RemoveList
foreach ($Remove in $ExpandedList) {
    $Body = "REPLACE($Body, '$Remove', '')"
}
$Body
%>

