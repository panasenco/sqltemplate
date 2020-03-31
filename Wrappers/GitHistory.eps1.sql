<%#
.Synopsis
    Wrapper that includes the Git history of a file as a header.
-%>
<%-
try {
    # This will throw an error if we are not in a valid Git repository
    git rev-parse 2>&1 | Out-Null
    # Determine the remote origin if it exists
    $Origin = git config --get remote.origin.url
    # Get the git log in a nice concise format
    $GitLog = git log --graph --date=short --pretty='format:%ad %an%d %h: %s' -- $ChildPath
    # Replace useless refs in the first line
    $GitLog = $GitLog -replace '(?<=\(.*)HEAD -> \w+, |, origin/\w+(?=.*\))'
    # Warn the user if the file has uncommitted changes
    if (git diff --name-only -- $ChildPath) {
        Write-Warning "$ChildPath has uncommitted changes"
        $GitLog = @("* $(Get-Date -Format 'yyyy-MM-dd') $(git config user.name) UNCOMMITTED CHANGES") + $GitLog
    }
} catch {
    $Origin = ''
    $GitLog = @()
}
-%>
/* File History (<% if ($Origin) { %>origin <%= $Origin %> <% } else { %>no origin <% } %>):
<%- $GitLog | Each { -%>
 <%= $_ %>
<%- } -%>
 */
<%= $Body %>
