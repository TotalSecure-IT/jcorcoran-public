# Simple counters to track discovered/skipped folders and discovered menu files.
$global:OrgFoldersDiscovered  = 0
$global:OrgFoldersSkipped     = 0
$global:MenuFilesDiscovered   = 0

function Refresh-LiveStats {
    Clear-Host
    Write-Host "Organization Folders discovered: " -NoNewline -ForegroundColor White
    Write-Host $global:OrgFoldersDiscovered -ForegroundColor Green

    Write-Host "Menu files discovered: " -NoNewline -ForegroundColor White
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
        [Parameter(Mandatory=$true)][string]$orgsFolderSha
    )
    <#
      Retrieves the top-level Orgs folder items from a known tree SHA,
      e.g. "8b8cde2fe87d2155653ddbdaa7530e01b84047bf".
      We'll only use items with type=tree for subfolders.
    #>

    $headers = @{
        Authorization = "token $token"
        Accept        = "application/vnd.github+json"
    }
    $url = "https://api.github.com/repos/$owner/$repo/git/trees/$orgsFolderSha"
    try {
        $response = Invoke-WebRequest -Uri $url -Headers $headers -Method GET -ErrorAction Stop
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
        [Parameter(Mandatory=$true)][string]$orgsFolderSha, # e.g. "8b8cde2fe87d2155653ddbdaa7530e01b84047bf"
        [Parameter(Mandatory=$false)][string]$primaryLogFilePath
    )
    if ($mode -ne "ONLINE") {
        Write-Host "CACHED mode not implemented. Exiting..."
        return
    }

    Write-Host "Using orgsFolderSha='$orgsFolderSha' to replicate subfolders..."
    Refresh-LiveStats

    # 1) Get top-level Orgs folder items
    $orgsItems = Get-OrgsFolderTree -owner $owner -repo $repo -token $token -orgsFolderSha $orgsFolderSha
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
                # Discovered a new folder
                $global:OrgFoldersDiscovered++
                Refresh-LiveStats

                New-Item -ItemType Directory -Path $subLocalFolder | Out-Null
            }
            else {
                # We skip if folder already exists
                $global:OrgFoldersSkipped++
                Refresh-LiveStats
            }

            # 3) Attempt to download submenu.txt from raw GitHub if missing
            $localSubmenu = Join-Path $subLocalFolder "submenu.txt"
            if (-not (Test-Path $localSubmenu)) {
                $rawSubmenuUrl = "https://raw.githubusercontent.com/TotalSecure-IT/jcorcoran-public/refs/heads/main/Poly.PKit/Orgs/$($item.path)/submenu.txt"
                try {
                    Invoke-WebRequest -Uri $rawSubmenuUrl -OutFile $localSubmenu -UseBasicParsing -ErrorAction Stop
                    $global:MenuFilesDiscovered++
                    Refresh-LiveStats
                }
                catch {
                    # If 404 or other error, we ignore
                }
            }
        }
        # We ignore items of type=blob, etc.
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
