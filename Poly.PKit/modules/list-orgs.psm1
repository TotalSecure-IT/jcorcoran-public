function Get-GitHubRepoFolders {
    param (
        [string]$owner,
        [string]$repo,
        [string]$token,
        [string]$path = ""
    )

    $headers = @{}
    if ($token) {
        $headers.Authorization = "token $token"
    }

    $url = "https://api.github.com/repos/$owner/$repo/contents/$path"
    
    try {
        $response = Invoke-WebRequest -Uri $url -Headers $headers -Method Get -ErrorAction Stop
    }
    catch {
        Write-Error "Failed to retrieve data from GitHub API: $_"
        return $null
    }
    
    $content = ConvertFrom-Json $response.Content

    $folders = $content | Where-Object { $_.type -eq "dir" }
    return $folders
}

# $owner, $repo, and $token are populated via the configuration loader
# Get top-level repository folders
$folders = Get-GitHubRepoFolders -owner $owner -repo $repo -token $token

# Print folder names
foreach ($folder in $folders) {
    Write-Host $folder.name
}

# List subfolders in a specific folder (using forward slashes in the path)
$subfolders = Get-GitHubRepoFolders -owner $owner -repo $repo -token $token -path "Poly.PKit/orgs"
Write-Host "Subfolders in Poly.PKit/orgs:"
foreach ($subfolder in $subfolders) {
    Write-Host $subfolder.name
}
