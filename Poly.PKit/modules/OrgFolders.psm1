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
      Fetches the top-level Orgs folder items (subfolders) from a known tree SHA.
      Example: orgsFolderSha = "8b8cde2fe87d2155653ddbdaa7530e01b84047bf"
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
            Write-Error "Tree data not found or empty for Orgs folder."
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

function Get-SubfolderTree {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$owner,
        [Parameter(Mandatory=$true)][string]$repo,
        [Parameter(Mandatory=$true)][string]$token,
        [Parameter(Mandatory=$true)][string]$subfolderSha,
        [Parameter(Mandatory=$false)][string]$primaryLogFilePath,
        [string]$jsonLogFilePath = $Global:JsonLogFilePath
    )
    <#
      Given a subfolder SHA, retrieve its file listing (including submenu.txt if present).
    #>

    $headers = @{
        Authorization = "token $token"
        Accept        = "application/vnd.github+json"
    }
    $url = "https://api.github.com/repos/$owner/$repo/git/trees/$subfolderSha"
    if ($jsonLogFilePath) {
        Write-JsonDebug -message "Fetching subfolder tree from: $url" -jsonLogFilePath $jsonLogFilePath
    }

    try {
        $response = Invoke-WebRequest -Uri $url -Headers $headers -Method GET -ErrorAction Stop
        $treeData = ConvertFrom-Json $response.Content
        if ($treeData -and $treeData.tree) {
            return $treeData.tree
        }
        else {
            Write-Error "Subfolder tree data not found or empty for SHA: $subfolderSha"
            return $null
        }
    }
    catch {
        Write-Error "Failed to retrieve subfolder tree for SHA $subfolderSha: $_"
        if ($jsonLogFilePath) {
            Write-JsonDebug -message "Failed to retrieve subfolder tree for SHA $subfolderSha: $_" -jsonLogFilePath $jsonLogFilePath
        }
        return $null
    }
}

function Get-BlobContentBase64 {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$owner,
        [Parameter(Mandatory=$true)][string]$repo,
        [Parameter(Mandatory=$true)][string]$token,
        [Parameter(Mandatory=$true)][string]$blobSha,
        [Parameter(Mandatory=$false)][string]$primaryLogFilePath,
        [string]$jsonLogFilePath = $Global:JsonLogFilePath
    )
    <#
      Retrieves a blob from the Git Blobs API, which returns base64-encoded content for files.
      We decode it and return the raw string content.
    #>

    $headers = @{
        Authorization = "token $token"
        Accept        = "application/vnd.github+json"
    }
    $url = "https://api.github.com/repos/$owner/$repo/git/blobs/$blobSha"
    if ($jsonLogFilePath) {
        Write-JsonDebug -message "Fetching blob: $url" -jsonLogFilePath $jsonLogFilePath
    }
    try {
        $response = Invoke-WebRequest -Uri $url -Headers $headers -Method GET -ErrorAction Stop
        $blobData = ConvertFrom-Json $response.Content
        if ($blobData -and $blobData.content -and $blobData.encoding -ieq "base64") {
            $decoded = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($blobData.content))
            return $decoded
        }
        else {
            Write-Error "Blob not found or not base64-encoded for SHA $blobSha."
            return $null
        }
    }
    catch {
        Write-Error "Failed to retrieve blob for SHA $blobSha: $_"
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
      1) Retrieves the top-level items in "Orgs" folder using the known orgsFolderSha
      2) Creates each local folder
      3) For each subfolder, fetch the subfolder tree. If a submenu.txt is found, retrieve the blob's content in base64, decode, and write out.
    #>

    Write-Debug "Entering Update-OrgFolders with mode: $mode"
    if ($mode -eq "ONLINE") {
        Write-Host "Retrieving subfolders from Orgs folder (SHA=$orgsFolderSha)..." -ForegroundColor Cyan

        # Step 1: get the immediate Orgs subfolders from the known tree SHA
        $orgsItems = Get-OrgsFolderTree -owner $owner -repo $repo -token $token -orgsFolderSha $orgsFolderSha -primaryLogFilePath $primaryLogFilePath -jsonLogFilePath $jsonLogFilePath
        if (-not $orgsItems) {
            Write-Error "No subfolders found under Orgs. Exiting..."
            return
        }

        # Create local "orgs" folder if needed
        $orgsRoot = Join-Path $workingDir "orgs"
        if (-not (Test-Path $orgsRoot)) {
            New-Item -ItemType Directory -Path $orgsRoot | Out-Null
            Write-Debug "Created root orgs folder: $orgsRoot"
        }

        # Step 2: replicate subfolders
        foreach ($item in $orgsItems) {
            if ($item.type -eq "tree") {
                # e.g. item.path = "Brethren-Mutual", item.sha = "0b967bd..."
                $subLocalFolder = Join-Path $orgsRoot $item.path
                if (-not (Test-Path $subLocalFolder)) {
                    New-Item -ItemType Directory -Path $subLocalFolder | Out-Null
                    Write-Host "Created local org folder: $subLocalFolder" -ForegroundColor Green
                    if ($primaryLogFilePath) {
                        Write-Log -message "Created local org folder: $subLocalFolder" -logFilePath $primaryLogFilePath
                    }
                }
                else {
                    Write-Debug "Org folder already exists locally: $subLocalFolder"
                }

                # Step 3: retrieve subfolder tree to see if there's a submenu.txt
                $subfolderTree = Get-SubfolderTree -owner $owner -repo $repo -token $token -subfolderSha $item.sha -primaryLogFilePath $primaryLogFilePath -jsonLogFilePath $jsonLogFilePath
                if ($subfolderTree) {
                    $submenuItem = $subfolderTree | Where-Object { $_.type -eq "blob" -and $_.path -ieq "submenu.txt" }
                    if ($submenuItem) {
                        $localSubmenu = Join-Path $subLocalFolder "submenu.txt"
                        if (-not (Test-Path $localSubmenu)) {
                            Write-Host "Downloading submenu.txt for org folder $($item.path)" -ForegroundColor Cyan
                            # Retrieve the blob for the submenu, decode from base64
                            $submenuContent = Get-BlobContentBase64 -owner $owner -repo $repo -token $token -blobSha $($submenuItem.sha) -primaryLogFilePath $primaryLogFilePath -jsonLogFilePath $jsonLogFilePath
                            if ($submenuContent) {
                                $submenuContent | Out-File -FilePath $localSubmenu -Encoding UTF8
                                Write-Debug "submenu.txt saved to $localSubmenu"
                            }
                        }
                        else {
                            Write-Debug "submenu.txt already exists locally for $($item.path)"
                        }
                    }
                }
            }
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
    <#
       A placeholder for older logic if needed.
       For each folder, do a direct contents call. Not fully implemented here.
    #>
    Write-Host "Sync-OrgFolderContents not fully implemented in this snippet."
}


Export-ModuleMember -Function Get-OrgsFolderTree, Get-SubfolderTree, Get-BlobContentBase64, Update-OrgFolders, Sync-OrgFolderContents
