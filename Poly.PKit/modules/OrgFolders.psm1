function Get-GitHubRepoFolders {
    param (
        [string]$owner,
        [string]$repo,
        [string]$token,
        [string]$path = ""
    )

    Write-Debug "Entering Get-GitHubRepoFolders..."
    Write-Debug "Owner: $owner"
    Write-Debug "Repo: $repo"
    Write-Debug "Original path parameter: '$path'"

    $headers = @{}
    if ($token) {
        $headers.Authorization = "token $token"
        Write-Debug "Authorization header set to: token ****"
    }
    else {
        Write-Debug "No token provided."
    }

    # Replace backslashes with forward slashes for the API URL.
    $pathClean = $path -replace "\\", "/"
    Write-Debug "Cleaned path: '$pathClean'"

    $url = "https://api.github.com/repos/$owner/$repo/contents/$pathClean"
    Write-Debug "Constructed URL: $url"
    Write-Debug "Headers: $(ConvertTo-Json $headers)"

    try {
        $response = Invoke-WebRequest -Uri $url -Headers $headers -Method Get -ErrorAction Stop
        Write-Debug "HTTP response status code: $($response.StatusCode)"
    }
    catch {
        Write-Error "Failed to retrieve data from GitHub API: $_"
        return $null
    }

    Write-Debug "Response content (first 200 chars): $($response.Content.Substring(0, [Math]::Min(200, $response.Content.Length)))"
    try {
        $content = ConvertFrom-Json $response.Content
        Write-Debug "JSON successfully parsed; received $(if($content -is [array]) { $content.Count } else { 'an object' })."
    }
    catch {
        Write-Error "Failed to parse JSON from the response: $_"
        return $null
    }
    
    # Return all items (both files and directories)
    return $content
}

# Private helper function to replicate a remote folder recursively.
function Replicate-Folder {
    param(
        [string]$remotePath,        # e.g. "Poly.PKit\Orgs\MyOrg"
        [string]$localParent,       # Parent local folder under which to create the folder.
        [string]$owner,
        [string]$repo,
        [string]$token,
        [string]$primaryLogFilePath
    )
    Write-Debug "Replicating folder: RemotePath='$remotePath', LocalParent='$localParent'"

    $contents = Get-GitHubRepoFolders -owner $owner -repo $repo -token $token -path $remotePath
    if (-not $contents) {
        Write-Debug "No contents found for $remotePath; skipping."
        return
    }

    # Check if this remote folder contains a submenu.txt file.
    $submenu = $contents | Where-Object { $_.type -eq "file" -and $_.name -ieq "submenu.txt" }
    if (-not $submenu) {
        Write-Debug "Folder '$remotePath' does not contain submenu.txt. Skipping replication."
        return
    }

    # Determine the folder name from remotePath and create the local folder.
    $folderName = Split-Path $remotePath -Leaf
    $localFolder = Join-Path $localParent $folderName
    if (-not (Test-Path $localFolder)) {
        New-Item -ItemType Directory -Path $localFolder | Out-Null
        Write-Host "Created local folder: $localFolder" -ForegroundColor Green
        if ($primaryLogFilePath) {
            Write-Log -message "Created local folder: $localFolder" -logFilePath $primaryLogFilePath
        }
    }
    else {
        Write-Debug "Local folder already exists: $localFolder"
    }

    # Download submenu.txt first if not present.
    $localSubmenu = Join-Path $localFolder "submenu.txt"
    if (-not (Test-Path $localSubmenu)) {
        Write-Host "Downloading submenu.txt for folder $remotePath" -ForegroundColor Cyan
        if ($primaryLogFilePath) {
            Write-Log -message "Downloading submenu.txt for folder $remotePath" -logFilePath $primaryLogFilePath
        }
        try {
            Invoke-WebRequest -Uri $submenu.download_url -OutFile $localSubmenu -UseBasicParsing
        }
        catch {
            Write-Error "Failed to download submenu.txt for folder $remotePath $_"
        }
    }

    # Process subdirectories recursively.
    $subDirs = $contents | Where-Object { $_.type -eq "dir" }
    foreach ($dir in $subDirs) {
        $newRemotePath = Join-Path $remotePath $dir.name
        # Call Replicate-Folder recursively. The current local folder becomes the new local parent.
        Replicate-Folder -remotePath $newRemotePath -localParent $localFolder -owner $owner -repo $repo -token $token -primaryLogFilePath $primaryLogFilePath
    }
}

function Update-OrgFolders {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$workingDir,
        [Parameter(Mandatory = $true)]
        [ValidateSet("ONLINE","CACHED")]
        [string]$mode,
        [Parameter(Mandatory = $true)]
        [string]$owner,
        [Parameter(Mandatory = $true)]
        [string]$repo,
        [Parameter(Mandatory = $true)]
        [string]$token,
        [Parameter(Mandatory = $false)]
        [string]$primaryLogFilePath
    )
    Write-Debug "Entering Update-OrgFolders with mode: $mode"
    if ($mode -eq "ONLINE") {
        $apiRoot = "Poly.PKit\Orgs"
        $localOrgsRoot = Join-Path $workingDir "orgs"
        if (-not (Test-Path $localOrgsRoot)) {
            New-Item -ItemType Directory -Path $localOrgsRoot | Out-Null
            Write-Debug "Created root orgs folder: $localOrgsRoot"
        }
        # Recursively replicate folders from the API root.
        Replicate-Folder -remotePath $apiRoot -localParent $localOrgsRoot -owner $owner -repo $repo -token $token -primaryLogFilePath $primaryLogFilePath
    }
    Write-Debug "Exiting Update-OrgFolders."
}

function Sync-OrgFolderContents {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$workingDir,
        # Relative path within the orgs folder (e.g. "MyOrg\SubFolder")
        [Parameter(Mandatory = $true)]
        [string]$orgRelativePath,
        [Parameter(Mandatory = $true)]
        [string]$owner,
        [Parameter(Mandatory = $true)]
        [string]$repo,
        [Parameter(Mandatory = $true)]
        [string]$token,
        [Parameter(Mandatory = $false)]
        [string]$primaryLogFilePath
    )
    Write-Debug "Syncing contents for org folder: $orgRelativePath"
    $apiRoot = "Poly.PKit\Orgs"
    # Build the full remote path.
    if ($orgRelativePath -ne "") {
        $remotePath = Join-Path $apiRoot $orgRelativePath
    }
    else {
        $remotePath = $apiRoot
    }
    $contents = Get-GitHubRepoFolders -owner $owner -repo $repo -token $token -path $remotePath
    if (-not $contents) {
        Write-Error "No contents retrieved for remote path $remotePath"
        return
    }
    # Identify the corresponding local folder.
    $localFolder = Join-Path (Join-Path $workingDir "orgs") $orgRelativePath
    if (-not (Test-Path $localFolder)) {
        Write-Error "Local folder $localFolder does not exist. Cannot sync."
        return
    }
    # Gather remote files and order them so that submenu.txt is handled first.
    $files = $contents | Where-Object { $_.type -eq "file" }
    $orderedFiles = @()
    if ($files) {
        foreach ($file in $files) {
            if ($file.name -ieq "submenu.txt") {
                $orderedFiles += $file
            }
        }
        foreach ($file in $files) {
            if ($file.name -ieq "submenu.txt") { continue }
            $orderedFiles += $file
        }
    }
    foreach ($file in $orderedFiles) {
        $localFilePath = Join-Path $localFolder $file.name
        if (-not (Test-Path $localFilePath)) {
            Write-Host "Downloading missing file: $($file.name) to $localFilePath" -ForegroundColor Cyan
            if ($primaryLogFilePath) {
                Write-Log -message "Downloading missing file: $($file.name) to $localFilePath" -logFilePath $primaryLogFilePath
            }
            try {
                Invoke-WebRequest -Uri $file.download_url -OutFile $localFilePath -UseBasicParsing
            }
            catch {
                Write-Error "Failed to download file $($file.name): $_"
            }
        }
        else {
            Write-Debug "File already exists locally: $localFilePath"
        }
    }
}

Export-ModuleMember -Function Get-GitHubRepoFolders, Update-OrgFolders, Sync-OrgFolderContents
