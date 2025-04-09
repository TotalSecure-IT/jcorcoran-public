#------------------------------------------------------------------
# Get-RepoTree
# Uses the Git Trees API to retrieve the entire repository tree recursively.
function Get-RepoTree {
    param(
        [Parameter(Mandatory = $true)][string]$owner,
        [Parameter(Mandatory = $true)][string]$repo,
        [Parameter(Mandatory = $true)][string]$token,
        [string]$branch = "main",
        [string]$jsonLogFilePath = $Global:JsonLogFilePath
    )
    $headers = @{
        Authorization = "token $token"
        Accept        = "application/vnd.github+json"
    }
    
    # Get the commit info for the branch to obtain the tree SHA.
    $commitUrl = "https://api.github.com/repos/$owner/$repo/commits/$branch"
    Write-Debug "Getting commit info from: $commitUrl"
    Write-JsonDebug -message "Getting commit info from: $commitUrl" -jsonLogFilePath $jsonLogFilePath
    try {
        $commitResponse = Invoke-WebRequest -Uri $commitUrl -Headers $headers -Method Get -ErrorAction Stop
        $commit = ConvertFrom-Json $commitResponse.Content
        $treeSha = $commit.commit.tree.sha
        Write-Debug "Obtained tree SHA: $treeSha"
        Write-JsonDebug -message "Obtained tree SHA: $treeSha" -jsonLogFilePath $jsonLogFilePath
    }
    catch {
        Write-Error "Failed to get commit info: $_"
        Write-JsonDebug -message "Failed to get commit info: $_" -jsonLogFilePath $jsonLogFilePath
        return $null
    }
    
    $treeUrl = "https://api.github.com/repos/$owner/$repo/git/trees/$treeSha?recursive=1"
    Write-Debug "Repo tree URL: $treeUrl"
    Write-JsonDebug -message "Repo tree URL: $treeUrl" -jsonLogFilePath $jsonLogFilePath
    try {
        $treeResponse = Invoke-WebRequest -Uri $treeUrl -Headers $headers -Method Get -ErrorAction Stop
        $treeData = ConvertFrom-Json $treeResponse.Content
        Write-Debug "Repo tree retrieved with $($treeData.tree.Count) items."
        Write-JsonDebug -message "Repo tree retrieved with $($treeData.tree.Count) items." -jsonLogFilePath $jsonLogFilePath
    }
    catch {
        Write-Error "Failed to get repository tree: $_"
        Write-JsonDebug -message "Failed to get repository tree: $_" -jsonLogFilePath $jsonLogFilePath
        return $null
    }
    return $treeData.tree
}

#------------------------------------------------------------------
# Replicate-FolderStructure
# Creates local folders for each remote org folder that contains a submenu.txt file
# and builds a download list for missing submenu.txt files.
function Replicate-FolderStructure {
    param(
        [Parameter(Mandatory = $true)][string]$workingDir,
        [Parameter(Mandatory = $true)][string]$owner,
        [Parameter(Mandatory = $true)][string]$repo,
        [Parameter(Mandatory = $true)][string]$token,
        [string]$branch = "main",
        [string]$jsonLogFilePath = $Global:JsonLogFilePath,
        [Parameter(Mandatory = $false)][string]$primaryLogFilePath
    )
    # Retrieve the full repository tree once.
    $treeItems = Get-RepoTree -owner $owner -repo $repo -token $token -branch $branch -jsonLogFilePath $jsonLogFilePath
    if (-not $treeItems) {
        Write-Error "Failed to retrieve repository tree."
        return $null
    }
    # Filter for submenu.txt files that reside under "Poly.PKit/Orgs/" with at least one subfolder.
    $submenuFiles = $treeItems | Where-Object {
        $_.type -eq "blob" -and $_.path -match "^Poly\.PKit/Orgs/.+/submenu\.txt$"
    }
    Write-Debug "Found $($submenuFiles.Count) submenu.txt files in the repository tree."
    Write-JsonDebug -message "Found $($submenuFiles.Count) submenu.txt files in the repository tree." -jsonLogFilePath $jsonLogFilePath

    $downloadList = @()
    foreach ($item in $submenuFiles) {
        # Remove the leading "Poly.PKit/Orgs/" and the trailing "/submenu.txt" to determine relative folder
        $relativeFolder = $item.path -replace "^Poly\.PKit/Orgs/", "" -replace "/submenu\.txt$",""
        $localFolder = Join-Path (Join-Path $workingDir "orgs") $relativeFolder
        if (-not (Test-Path $localFolder)) {
            New-Item -ItemType Directory -Path $localFolder | Out-Null
            Write-Host "Created local folder: $localFolder" -ForegroundColor Green
            if ($primaryLogFilePath) {
                Write-Log -message "Created local folder: $localFolder" -logFilePath $primaryLogFilePath
            }
        }
        # Construct the raw URL for the submenu.txt file.
        $remoteSubmenuURL = "https://raw.githubusercontent.com/$owner/$repo/$branch/$($item.path)"
        $localSubmenu = Join-Path $localFolder "submenu.txt"
        $downloadList += [PSCustomObject]@{
            RemoteSubmenuURL = $remoteSubmenuURL
            LocalSubmenuPath = $localSubmenu
        }
    }
    return $downloadList
}

#------------------------------------------------------------------
# Download-SubmenusParallel
# Downloads submenu.txt files in parallel with a throttle limit.
function Download-SubmenusParallel {
    param(
        [Parameter(Mandatory = $true)][array]$downloadList,
        [Parameter(Mandatory = $true)][string]$jsonLogFilePath,
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

#------------------------------------------------------------------
# Update-OrgFolders
# Main function for replicating the folder structure and downloading submenu.txt files.
function Update-OrgFolders {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$workingDir,
        [Parameter(Mandatory = $true)][ValidateSet("ONLINE","CACHED")][string]$mode,
        [Parameter(Mandatory = $true)][string]$owner,
        [Parameter(Mandatory = $true)][string]$repo,
        [Parameter(Mandatory = $true)][string]$token,
        [Parameter(Mandatory = $false)][string]$primaryLogFilePath,
        [string]$jsonLogFilePath = $Global:JsonLogFilePath,
        [string]$branch = "main"
    )
    Write-Debug "Entering Update-OrgFolders with mode: $mode"
    if ($mode -eq "ONLINE") {
        # Replicate folder structure and build download list.
        $downloadList = Replicate-FolderStructure -workingDir $workingDir -owner $owner -repo $repo -token $token -branch $branch -primaryLogFilePath $primaryLogFilePath -jsonLogFilePath $jsonLogFilePath
        if ($downloadList -and $downloadList.Count -gt 0) {
            Write-Host "Downloading missing submenu.txt files in parallel..." -ForegroundColor Cyan
            Download-SubmenusParallel -downloadList $downloadList -jsonLogFilePath $jsonLogFilePath -throttle 4
        }
        else {
            Write-Debug "No submenu.txt files need to be downloaded."
        }
    }
    Write-Debug "Exiting Update-OrgFolders."
}

#------------------------------------------------------------------
# Sync-OrgFolderContents (unchanged from before)
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
    if ($orgRelativePath -ne "") {
        $remotePath = Join-Path "Poly.PKit/Orgs" $orgRelativePath
    }
    else {
        $remotePath = "Poly.PKit/Orgs"
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
