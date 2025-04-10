function Get-OrgsFolderTree {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$owner,
        [Parameter(Mandatory=$true)][string]$repo,
        [Parameter(Mandatory=$true)][string]$token,
        [Parameter(Mandatory=$true)][string]$orgsFolderSha,
        [Parameter(Mandatory=$false)][string]$primaryLogFilePath,
        [string]$jsonLogFilePath = $Global:JsonLogFilePath
    )
    <#
      Retrieves the Git tree for the Orgs folder, using a known tree SHA
      (e.g., 8b8cde2fe87d2155653ddbdaa7530e01b84047bf).
      We do NOT add ?recursive=1 to this call, because we only need the immediate subfolders
      and the user-provided SHA specifically references the Orgs folder contents.
    #>

    $headers = @{
        Authorization = "token $token"
        Accept        = "application/vnd.github+json"
    }
    $treeUrl = "https://api.github.com/repos/$owner/$repo/git/trees/$orgsFolderSha"
    Write-Debug "Fetching Orgs folder tree from: $treeUrl"
    if ($jsonLogFilePath) {
        Write-JsonDebug -message "Fetching Orgs folder tree from: $treeUrl" -jsonLogFilePath $jsonLogFilePath
    }

    try {
        $response = Invoke-WebRequest -Uri $treeUrl -Headers $headers -Method GET -ErrorAction Stop
        $treeData = ConvertFrom-Json $response.Content
        if ($treeData -and $treeData.tree) {
            Write-Debug "Fetched Orgs folder tree with $($treeData.tree.Count) items."
            if ($jsonLogFilePath) {
                Write-JsonDebug -message "Fetched Orgs folder tree with $($treeData.tree.Count) items." -jsonLogFilePath $jsonLogFilePath
            }
            return $treeData.tree
        }
        else {
            Write-Error "Orgs folder tree data not found or empty."
            return $null
        }
    }
    catch {
        Write-Error "Failed to retrieve Orgs folder tree: $_"
        if ($jsonLogFilePath) {
            Write-JsonDebug -message "Failed to retrieve Orgs folder tree: $_" -jsonLogFilePath $jsonLogFilePath
        }
        return $null
    }
}

function Replicate-OrgsFolderStructure {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$workingDir,
        [Parameter(Mandatory=$true)][string]$owner,
        [Parameter(Mandatory=$true)][string]$repo,
        [Parameter(Mandatory=$true)][string]$token,
        [Parameter(Mandatory=$true)][string]$orgsFolderSha,
        [Parameter(Mandatory=$false)][string]$primaryLogFilePath,
        [string]$jsonLogFilePath = $Global:JsonLogFilePath
    )
    <#
      Uses Get-OrgsFolderTree to get subfolders & submenu files. Then:
        - Creates local folders for each subfolder
        - Builds a download list for submenu.txt files in each folder
    #>

    $treeItems = Get-OrgsFolderTree -owner $owner -repo $repo -token $token -orgsFolderSha $orgsFolderSha -primaryLogFilePath $primaryLogFilePath -jsonLogFilePath $jsonLogFilePath
    if (-not $treeItems) {
        Write-Error "Orgs folder tree retrieval failed."
        return $null
    }

    # Each 'tree' item has: path, mode, type=tree/blob, sha, url
    # We only care about 'type=tree' as subfolders, or 'blob' named submenu.txt
    $downloadList = @()

    foreach ($item in $treeItems) {
        if ($item.type -eq "tree") {
            # This is a subfolder under Orgs
            # e.g. path = "Brethren-Mutual"
            $localFolder = Join-Path (Join-Path $workingDir "orgs") $item.path
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
        }
        elseif ($item.type -eq "blob" -and $item.path -ieq "submenu.txt") {
            # This is a file named submenu.txt at the root of Orgs (unlikely, but let's handle it)
            $localSubmenu = Join-Path (Join-Path $workingDir "orgs") $item.path
            if (-not (Test-Path $localSubmenu)) {
                $rawUrl = "https://raw.githubusercontent.com/$owner/$repo/main/Poly.PKit/Orgs/$($item.path)"
                $downloadList += [PSCustomObject]@{
                    RemoteSubmenuURL = $rawUrl
                    LocalSubmenuPath = $localSubmenu
                }
            }
        }
    }
    # Now we have local folders but might not have submenu.txt within them. We need a second step:
    # For each subfolder, fetch the subfolder's tree to see if there's a submenu.txt. We do so in parallel or sequentially?

    # We'll build an array of subfolder trees, each of which we check for a 'submenu.txt' blob. We'll do this sequentially for clarity:
    foreach ($subfolder in $treeItems | Where-Object { $_.type -eq "tree" }) {
        $subName = $subfolder.path    # e.g. "Brethren-Mutual"
        $subSha  = $subfolder.sha     # e.g. "0b967bd926a8657a564d..."
        $subLocalFolder = Join-Path (Join-Path $workingDir "orgs") $subName

        # Call the same API to get that subfolder's contents
        $subTreeUrl = "https://api.github.com/repos/$owner/$repo/git/trees/$subSha"
        if ($jsonLogFilePath) {
            Write-JsonDebug -message "Fetching subfolder tree from: $subTreeUrl" -jsonLogFilePath $jsonLogFilePath
        }
        $headers = @{
            Authorization = "token $token"
            Accept        = "application/vnd.github+json"
        }
        try {
            $subResponse = Invoke-WebRequest -Uri $subTreeUrl -Headers $headers -Method GET -ErrorAction Stop
            $subTreeData = ConvertFrom-Json $subResponse.Content
        }
        catch {
            Write-Error "Failed to retrieve subfolder tree for $subName: $_"
            continue
        }
        if ($subTreeData -and $subTreeData.tree) {
            # Check for a submenu.txt item
            $submenuItem = $subTreeData.tree | Where-Object { $_.type -eq "blob" -and $_.path -ieq "submenu.txt" }
            if ($submenuItem) {
                # If missing locally, add it to the download list
                $localSubmenu = Join-Path $subLocalFolder "submenu.txt"
                if (-not (Test-Path $localSubmenu)) {
                    $rawUrl = "https://raw.githubusercontent.com/$owner/$repo/main/Poly.PKit/Orgs/$subName/submenu.txt"
                    $downloadList += [PSCustomObject]@{
                        RemoteSubmenuURL = $rawUrl
                        LocalSubmenuPath = $localSubmenu
                    }
                }
            }
        }
    }
    return $downloadList
}

function Download-SubmenusParallel {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][array]$downloadList,
        [Parameter(Mandatory=$false)][string]$primaryLogFilePath,
        [string]$jsonLogFilePath = $Global:JsonLogFilePath,
        [int]$throttle = 4
    )
    Write-Debug "Starting parallel download of submenu.txt files with throttle limit $throttle..."
    if ($jsonLogFilePath) {
        Write-JsonDebug -message "Starting parallel download of submenu.txt files with throttle limit $throttle..." -jsonLogFilePath $jsonLogFilePath
    }
    $downloadList | ForEach-Object -Parallel {
        param($item, $primaryLogFilePath)
        try {
            Invoke-WebRequest -Uri $item.RemoteSubmenuURL -OutFile $item.LocalSubmenuPath -UseBasicParsing
            Write-Host "Downloaded submenu.txt to $($item.LocalSubmenuPath)"
        }
        catch {
            Write-Error "Error downloading submenu from $($item.RemoteSubmenuURL): $_"
        }
    } -ThrottleLimit $throttle -ArgumentList $primaryLogFilePath
}

function Update-OrgFolders {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$workingDir,
        [Parameter(Mandatory=$true)][ValidateSet("ONLINE","CACHED")][string]$mode,
        [Parameter(Mandatory=$true)][string]$owner,
        [Parameter(Mandatory=$true)][string]$repo,
        [Parameter(Mandatory=$true)][string]$token,
        [Parameter(Mandatory=$true)][string]$orgsFolderSha,    # e.g. 8b8cde2fe87d2155653ddbdaa7530e01b84047bf
        [Parameter(Mandatory=$false)][string]$primaryLogFilePath,
        [string]$jsonLogFilePath = $Global:JsonLogFilePath
    )
    Write-Debug "Entering Update-OrgFolders with mode: $mode"
    if ($mode -eq "ONLINE") {
        Write-Host "Replicating Orgs folder structure from SHA: $orgsFolderSha ..." -ForegroundColor Cyan
        # 1) Build the entire Orgs folder structure & get a list of missing submenu.txt files
        $downloadList = Replicate-OrgsFolderStructure -workingDir $workingDir -owner $owner -repo $repo -token $token -orgsFolderSha $orgsFolderSha -primaryLogFilePath $primaryLogFilePath -jsonLogFilePath $jsonLogFilePath

        # 2) Download any missing submenu.txt files
        if ($downloadList -and $downloadList.Count -gt 0) {
            Write-Host "Downloading $($downloadList.Count) missing submenu.txt files in parallel (throttle=4)..." -ForegroundColor Cyan
            Download-SubmenusParallel -downloadList $downloadList -primaryLogFilePath $primaryLogFilePath -jsonLogFilePath $jsonLogFilePath -throttle 4
        }
        else {
            Write-Host "No missing submenu.txt files to download."
        }
    }
    Write-Debug "Exiting Update-OrgFolders."
}

function Sync-OrgFolderContents {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$workingDir,
        [Parameter(Mandatory=$true)][string]$orgRelativePath,
        [Parameter(Mandatory=$true)][string]$owner,
        [Parameter(Mandatory=$true)][string]$repo,
        [Parameter(Mandatory=$true)][string]$token,
        [Parameter(Mandatory=$false)][string]$primaryLogFilePath,
        [string]$jsonLogFilePath = $Global:JsonLogFilePath
    )
    Write-Debug "Syncing contents for org folder: $orgRelativePath"
    # For backward compatibility, do a direct /contents/ call for the single org folder.
    $apiRoot = "Poly.PKit/Orgs"
    $remotePath = if ($orgRelativePath) { Join-Path $apiRoot $orgRelativePath } else { $apiRoot }
    # ...
    # Implementation similar to your old approach
    Write-Host "Sync-OrgFolderContents not fully implemented in this snippet."
}

Export-ModuleMember -Function Get-OrgsFolderTree,Replicate-OrgsFolderStructure,Download-SubmenusParallel,Update-OrgFolders,Sync-OrgFolderContents
