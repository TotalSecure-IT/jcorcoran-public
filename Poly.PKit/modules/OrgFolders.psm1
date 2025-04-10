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
      Retrieves the top-level Orgs folder tree from a known tree SHA (e.g. "8b8cde2fe87d2155653ddbdaa7530e01b84047bf").
      Each item in the returned array includes: { path, mode, type=tree/blob, sha, url }.
      We'll just use 'path' (subfolder name) and 'type=tree' to build local folders.
    #>

    $headers = @{
        Authorization = "token $token"
        Accept        = "application/vnd.github+json"
    }
    $url = "https://api.github.com/repos/$owner/$repo/git/trees/$orgsFolderSha"
    
    if ($jsonLogFilePath) {
        Write-JsonDebug -message "Fetching Orgs folder tree from: $url" -jsonLogFilePath $jsonLogFilePath
    }
    try {
        $response = Invoke-WebRequest -Uri $url -Headers $headers -Method GET -ErrorAction Stop
        $treeData = ConvertFrom-Json $response.Content
        if ($treeData -and $treeData.tree) {
            return $treeData.tree
        }
        else {
            Write-Error "Tree data not found or empty for Orgs folder SHA: $orgsFolderSha"
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

function Update-OrgFolders {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$workingDir,
        [Parameter(Mandatory=$true)][ValidateSet("ONLINE","CACHED")][string]$mode,
        [Parameter(Mandatory=$true)][string]$owner,
        [Parameter(Mandatory=$true)][string]$repo,
        [Parameter(Mandatory=$true)][string]$token,
        [Parameter(Mandatory=$true)][string]$orgsFolderSha, # e.g. "8b8cde2fe87d2155653ddbdaa7530e01b84047bf"
        [Parameter(Mandatory=$false)][string]$primaryLogFilePath,
        [string]$jsonLogFilePath = $Global:JsonLogFilePath
    )
    <#
      1) Retrieves the subfolders of Orgs from orgsFolderSha
      2) Creates each subfolder locally
      3) Attempts to download submenu.txt from:
         "https://raw.githubusercontent.com/TotalSecure-IT/jcorcoran-public/refs/heads/main/Poly.PKit/Orgs/{subfolder}/submenu.txt"
         If it fails (404), we skip that submenu.
    #>

    Write-Debug "Entering Update-OrgFolders with mode: $mode"
    if ($mode -eq "ONLINE") {
        Write-Host "Using orgsFolderSha='$orgsFolderSha' to replicate subfolders..."
        $orgsItems = Get-OrgsFolderTree -owner $owner -repo $repo -token $token -orgsFolderSha $orgsFolderSha -primaryLogFilePath $primaryLogFilePath -jsonLogFilePath $jsonLogFilePath
        if (-not $orgsItems) {
            Write-Error "No subfolders found under Orgs. Exiting..."
            return
        }

        # Ensure local 'orgs' folder
        $orgsRoot = Join-Path $workingDir "orgs"
        if (-not (Test-Path $orgsRoot)) {
            New-Item -ItemType Directory -Path $orgsRoot | Out-Null
            Write-Debug "Created root orgs folder: $orgsRoot"
        }

        # For each subfolder tree item, create local folder, then attempt to download submenu.txt
        foreach ($item in $orgsItems) {
            if ($item.type -eq "tree") {
                # item.path might be e.g. "Brethren-Mutual"
                $subLocalFolder = Join-Path $orgsRoot $item.path
                if (-not (Test-Path $subLocalFolder)) {
                    New-Item -ItemType Directory -Path $subLocalFolder | Out-Null
                    Write-Host "Created local org folder: $subLocalFolder" -ForegroundColor Green
                    if ($primaryLogFilePath) {
                        Write-Log -message "Created local org folder: $subLocalFolder" -logFilePath $primaryLogFilePath
                    }
                }
                else {
                    Write-Debug "Local org folder already exists: $subLocalFolder"
                }

                # Attempt to download submenu.txt from raw GitHub URL
                $rawSubmenuUrl = "https://raw.githubusercontent.com/TotalSecure-IT/jcorcoran-public/refs/heads/main/Poly.PKit/Orgs/$($item.path)/submenu.txt"
                $localSubmenu = Join-Path $subLocalFolder "submenu.txt"
                if (-not (Test-Path $localSubmenu)) {
                    Write-Host "Attempting to download $rawSubmenuUrl" -ForegroundColor Cyan
                    try {
                        Invoke-WebRequest -Uri $rawSubmenuUrl -OutFile $localSubmenu -UseBasicParsing -ErrorAction Stop
                        Write-Debug "submenu.txt saved to $localSubmenu"
                        if ($primaryLogFilePath) {
                            Write-Log -message "submenu.txt downloaded for subfolder '$($item.path)'" -logFilePath $primaryLogFilePath
                        }
                    }
                    catch {
                        # Probably 404, so we skip
                        Write-Debug "No submenu.txt found at $rawSubmenuUrl. Skipping."
                    }
                }
                else {
                    Write-Debug "submenu.txt already exists locally for $($item.path)"
                }
            }
        }
    }
    else {
        Write-Debug "CACHED mode not implemented here."
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
    Write-Host "Sync-OrgFolderContents is not fully implemented in this snippet."
}


Export-ModuleMember -Function Get-OrgsFolderTree, Update-OrgFolders, Sync-OrgFolderContents
