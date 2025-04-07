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

    $response = Invoke-WebRequest -Uri $url -Headers $headers -Method Get -ErrorAction Stop

    $content = ConvertFrom-Json $response.Content

    $folders = $content | Where-Object { $_.type -eq "dir" }

    return $folders
}

# Example usage:
$owner = ""
$repo = ""
$token = ""
$folders = Get-GitHubRepoFolders -owner $owner -repo $repo -token $token

# Print folder names
foreach ($folder in $folders) {
    Write-Host $folder.name
}

# List subfolders in a specific folder
$subfolders = Get-GitHubRepoFolders -owner $owner -repo $repo -token $token -path "Poly.PKit\orgs" # Replace "folder_name"
Write-Host "Subfolders in folder_name:"
foreach ($subfolder in $subfolders) {
    Write-Host $subfolder.name
}