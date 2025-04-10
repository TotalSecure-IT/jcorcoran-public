# Global counters for stats display
$global:OrgFoldersDiscovered  = 0
$global:OrgFoldersSkipped     = 0
$global:MenuFilesDiscovered   = 0

function Refresh-LiveStats {
    Clear-Host
    Write-Host "Organization Folders created: " -NoNewline -ForegroundColor White
    Write-Host $global:OrgFoldersDiscovered -ForegroundColor Green

    Write-Host "Menu files downloaded: " -NoNewline -ForegroundColor White
    Write-Host $global:MenuFilesDiscovered -ForegroundColor Green

    Write-Host "Organization Folders skipped: " -NoNewline -ForegroundColor White
    Write-Host $global:OrgFoldersSkipped -ForegroundColor Green
}

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
      Retrieves top-level items (subfolders) from the Orgs folder's tree using a known SHA (e.g. "8b8cde2fe87d2155653ddbdaa7530e01b84047bf").
      We'll only use items with type=tree to replicate local folders.
    #>

    $headers = @{
        Authorization = "token $token"
        Accept        = "application/vnd.github+json"
    }

    $url = "https://api.github.com/repos/$owner/$repo/git/trees/$orgsFolderSha"
    if ($jsonLogFilePath) {
        Write-JsonDebug -message "Requesting Orgs folder tree from: $url" -jsonLogFilePath $jsonLogFilePath
    }
    try {
        $response = Invoke-WebRequest -Uri $url -Headers $headers -Method GET -ErrorAction Stop
        if ($jsonLogFilePath) {
            Write-JsonDebug -message "Response status code: $($response.StatusCode)" -jsonLogFilePath $jsonLogFilePath
            # Show first 200 chars if possible
            $contentPreview = $response.Content.Substring(0, [Math]::Min(200, $response.Content.Length))
            Write-JsonDebug -message "Response content (first 200 chars): $contentPreview" -jsonLogFilePath $jsonLogFilePath
        }
        $treeData = $response.Content | ConvertFrom-Json
        if ($treeData -and $treeData.tree) {
            return $treeData.tree
        }
        else {
            Write-Error "No items found for Orgs folder SHA: $orgsFolderSha"
            return $null
        }
    }
    catch {
        Write-Error "Failed to retrieve Orgs folder tree: $_"
        if ($jsonLogFilePath) {
            Write-JsonDebug -message "Error retrieving Orgs folder tree: $_" -jsonLogFilePath $jsonLogFilePath
        }
        return $null
    }
}

function Update-OrgFolders {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$workingDir,
        [Parameter(Mandatory=$true)][ValidateSet("ONLINE","CACHED")][string]$mode,
        [Parameter(Mandatory=$true)][string]$owner,
        [Parameter(Mandatory=$true)][string]$repo,
        [Parameter(Mandatory=$true)][string]$token,
        [Parameter(Mandatory=$true)][string]$orgsFolderSha,
        [Parameter(Mandatory=$false)][string]$primaryLogFilePath,
        [string]$jsonLogFilePath = $Global:JsonLogFilePath
    )
    if ($mode -ne "ONLINE") {
        Write-Host "CACHED mode not implemented. Exiting..."
        return
    }

    Write-Host "Using orgsFolderSha='$orgsFolderSha' to replicate subfolders..."
    Refresh-LiveStats

    # 1) Get top-level Orgs folder items
    $orgsItems = Get-OrgsFolderTree -owner $owner -repo $repo -token $token -orgsFolderSha $orgsFolderSha -primaryLogFilePath $primaryLogFilePath -jsonLogFilePath $jsonLogFilePath
    if (-not $orgsItems) {
        Write-Error "No subfolders found under Orgs. Exiting..."
        return
    }

    # Ensure the local "orgs" folder exists
    $orgsRoot = Join-Path $workingDir "orgs"
    if (-not (Test-Path $orgsRoot)) {
        New-Item -ItemType Directory -Path $orgsRoot | Out-Null
    }

    # 2) For each subfolder, create a local folder if missing, else skip
    foreach ($item in $orgsItems) {
        if ($item.type -eq "tree") {
            $subLocalFolder = Join-Path $orgsRoot $item.path
            if (-not (Test-Path $subLocalFolder)) {
                $global:OrgFoldersDiscovered++
                Refresh-LiveStats

                New-Item -ItemType Directory -Path $subLocalFolder | Out-Null
            }
            else {
                $global:OrgFoldersSkipped++
                Refresh-LiveStats
            }

            # 3) Attempt to download submenu.txt from raw GitHub if missing
            $localSubmenu = Join-Path $subLocalFolder "submenu.txt"
            if (-not (Test-Path $localSubmenu)) {
                $rawSubmenuUrl = "https://raw.githubusercontent.com/$owner/$repo/refs/heads/main/Poly.PKit/Orgs/$($item.path)/submenu.txt"
                if ($jsonLogFilePath) {
                    Write-JsonDebug -message "Trying to download submenu from: $rawSubmenuUrl" -jsonLogFilePath $jsonLogFilePath
                }
                try {
                    Invoke-WebRequest -Uri $rawSubmenuUrl -OutFile $localSubmenu -UseBasicParsing -ErrorAction Stop
                    $global:MenuFilesDiscovered++
                    Refresh-LiveStats
                }
                catch {
                    # If 404 or other error, we ignore
                    if ($jsonLogFilePath) {
                        Write-JsonDebug -message "Failed to download from $rawSubmenuUrl (possibly 404)." -jsonLogFilePath $jsonLogFilePath
                    }
                }
            }
        }
    }
}

function Sync-OrgFolderContents {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$workingDir,
        [Parameter(Mandatory=$true)][string]$orgRelativePath,
        [Parameter(Mandatory=$true)][string]$owner,
        [Parameter(Mandatory=$true)][string]$repo,
        [Parameter(Mandatory=$true)][string]$token
    )
    Write-Host "Sync-OrgFolderContents is not implemented here."
}


Export-ModuleMember -Function Update-OrgFolders, Sync-OrgFolderContents
