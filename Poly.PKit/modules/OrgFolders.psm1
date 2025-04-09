# Get the entire repository tree using Git Trees API (recursive)
function Get-RepoTree {
    param(
        [Parameter(Mandatory=$true)][string]$owner,
        [Parameter(Mandatory=$true)][string]$repo,
        [Parameter(Mandatory=$true)][string]$token,
        [string]$branch = "main",
        [string]$jsonLogFilePath = $Global:JsonLogFilePath
    )
    $headers = @{}
    if ($token) { $headers.Authorization = "token $token" }
    $url = "https://api.github.com/repos/$owner/$repo/git/trees/$branch?recursive=1"
    Write-Debug "Repo Tree URL: $url"
    Write-JsonDebug -message "Repo Tree URL: $url" -jsonLogFilePath $jsonLogFilePath
    try {
        $response = Invoke-WebRequest -Uri $url -Headers $headers -Method Get -ErrorAction Stop
        Write-Debug "Received repo tree."
        Write-JsonDebug -message "Received repo tree." -jsonLogFilePath $jsonLogFilePath
    }
    catch {
        Write-Error "Failed to get repository tree: $_"
        Write-JsonDebug -message "Failed to get repository tree: $_" -jsonLogFilePath $jsonLogFilePath
        return $null
    }
    $treeData = ConvertFrom-Json $response.Content
    return $treeData.tree
}

# Replicate the folder structure locally and build a download list for submenu.txt files.
function Replicate-FolderStructure {
    param(
        [Parameter(Mandatory=$true)][string]$workingDir,
        [Parameter(Mandatory=$true)][string]$owner,
        [Parameter(Mandatory=$true)][string]$repo,
        [Parameter(Mandatory=$true)][string]$token,
        [string]$branch = "main",
        [string]$jsonLogFilePath = $Global:JsonLogFilePath,
        [Parameter(Mandatory=$false)][string]$primaryLogFilePath
    )
    # Get the entire tree once
    $treeItems = Get-RepoTree -owner $owner -repo $repo -token $token -branch $branch -jsonLogFilePath $jsonLogFilePath
    if (-not $treeItems) {
        Write-Error "Failed to retrieve repository tree."
        return $null
    }
    # Filter for items that are files named "submenu.txt" and that reside under "Poly.PKit/Orgs/"
    $submenuFiles = $treeItems | Where-Object {
        $_.type -eq "blob" -and
        $_.path -match "^Poly\.Pkit/Orgs/.+/submenu\.txt$"
    }
    Write-Debug "Found $($submenuFiles.Count) submenu.txt files in the repository tree."
    Write-JsonDebug -message "Found $($submenuFiles.Count) submenu.txt files in the repository tree." -jsonLogFilePath $jsonLogFilePath

    $downloadList = @()
    foreach ($item in $submenuFiles) {
        # Remove the leading path "Poly.Pkit/Orgs/" to get the relative folder
        $relativeFolder = $item.path -replace "^Poly\.Pkit/Orgs/", "" -replace "/submenu\.txt$",""
        $localFolder = Join-Path (Join-Path $workingDir "orgs") $relativeFolder
        if (-not (Test-Path $localFolder)) {
            New-Item -ItemType Directory -Path $localFolder | Out-Null
            Write-Host "Created local folder: $localFolder" -ForegroundColor Green
            if ($primaryLogFilePath) {
                Write-Log -message "Created local folder: $localFolder" -logFilePath $primaryLogFilePath
            }
        }
        # Construct remote raw URL for the submenu.txt file.
        $remoteSubmenuURL = "https://raw.githubusercontent.com/$owner/$repo/$branch/$($item.path)"
        $localSubmenu = Join-Path $localFolder "submenu.txt"
        $downloadList += [PSCustomObject]@{
            RemoteSubmenuURL = $remoteSubmenuURL
            LocalSubmenuPath = $localSubmenu
        }
    }
    return $downloadList
}

# Download submenu.txt files in parallel with a throttle limit.
function Download-SubmenusParallel {
    param(
        [Parameter(Mandatory=$true)][array]$downloadList,
        [Parameter(Mandatory=$true)][string]$jsonLogFilePath,
        [int]$throttle = 4
    )
    Write-Debug "Starting parallel download of submenu.txt files with throttle limit $throttle..."
    Write-JsonDebug -message "Starting parallel download of submenu.txt files with throttle limit $throttle..." -jsonLogFilePath $jsonLogFilePath
    $downloadList | ForEach-Object -Parallel {
        param($item, $jsonLogFilePath)
        try {
            Invoke-WebRequest -Uri $item.RemoteSubmenuURL -OutFile $item.LocalSubmenuPath -UseBasicParsing
            Write-Output "Downloaded submenu.txt to $($item.LocalSubmenuPath)"
        }
        catch {
            Write-Error "Error downloading submenu from $($item.RemoteSubmenuURL): $_"
        }
    } -ThrottleLimit $throttle -ArgumentList $jsonLogFilePath
}

# Updated Update-OrgFolders: Replicates folder structure first, then downloads submenu.txt files in parallel.
function Update-OrgFolders {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$workingDir,
        [Parameter(Mandatory=$true)][ValidateSet("ONLINE","CACHED")][string]$mode,
        [Parameter(Mandatory=$true)][string]$owner,
        [Parameter(Mandatory=$true)][string]$repo,
        [Parameter(Mandatory=$true)][string]$token,
        [Parameter(Mandatory=$false)][string]$primaryLogFilePath,
        [string]$jsonLogFilePath = $Global:JsonLogFilePath,
        [string]$branch = "main"
    )
    Write-Debug "Entering Update-OrgFolders with mode: $mode"
    if ($mode -eq "ONLINE") {
        # First, replicate the folder structure and get a list of submenu.txt download tasks.
        $downloadList = Replicate-FolderStructure -workingDir $workingDir -owner $owner -repo $repo -token $token -branch $branch -primaryLogFilePath $primaryLogFilePath -jsonLogFilePath $jsonLogFilePath
        if ($downloadList -and $downloadList.Count -gt 0) {
            Write-Host "Downloading missing submenu.txt files in parallel..."
            Download-SubmenusParallel -downloadList $downloadList -jsonLogFilePath $jsonLogFilePath -throttle 4
        }
        else {
            Write-Debug "No submenu.txt files needed to download."
        }
    }
    Write-Debug "Exiting Update-OrgFolders."
}

# For backward compatibility with on-demand syncing
function Sync-OrgFolderContents {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$workingDir,
        [Parameter(Mandatory = $true)][string]$orgRelativePath,
        [Parameter(Mandatory = $true)][string]$owner,
        [Parameter(Mandatory = $true)][string]$repo,
        [Parameter(Mandatory = $true)][string]$token,
        [Parameter(Mandatory = $false)][string]$primaryLogFilePath,
        [string]$jsonLogFilePath = $Global:JsonLogFilePath,
        [string]$branch = "main"
    )
    Write-Debug "Syncing contents for org folder: $orgRelativePath"
    # Use the original approach to download missing files in a given folder via the content API.
    # (This function remains largely unchanged.)
    $apiRoot = "Poly.PKit\Orgs"
    if ($orgRelativePath -ne "") {
        $remotePath = Join-Path $apiRoot $orgRelativePath
    }
    else {
        $remotePath = $apiRoot
    }
    $contents = Get-GitHubRepoFolders -owner $owner -repo $repo -token $token -path $remotePath -jsonLogFilePath $jsonLogFilePath
    if (-not $contents) {
        Write-Error "No contents retrieved for remote path $remotePath"
        return
    }
    $localFolder = Join-Path (Join-Path $workingDir "orgs") $orgRelativePath
    if (-not (Test-Path $localFolder)) {
        Write-Error "Local folder $localFolder does not exist. Cannot sync."
        return
    }
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

Export-ModuleMember -Function Get-RepoTree, Replicate-FolderStructure, Download-SubmenusParallel, Update-OrgFolders, Sync-OrgFolderContents
