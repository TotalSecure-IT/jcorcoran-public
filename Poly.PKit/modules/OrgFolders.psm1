function Get-GitHubRepoFolders {
    param (
        [string]$owner,
        [string]$repo,
        [string]$token,
        [string]$path = "",
        [Parameter(Mandatory = $true)] [string]$jsonLogFilePath
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

    # Convert backslashes to forward slashes for GitHub.
    $pathClean = $path -replace "\\", "/"
    Write-Debug "Cleaned path: '$pathClean'"

    $url = "https://api.github.com/repos/$owner/$repo/contents/$pathClean"
    Write-Debug "Constructed URL: $url"
    Write-Debug "Headers: $(ConvertTo-Json $headers)"
    
    Write-JsonDebug -message "Constructed URL: $url" -jsonLogFilePath $jsonLogFilePath
    Write-JsonDebug -message "Headers: $(ConvertTo-Json $headers)" -jsonLogFilePath $jsonLogFilePath

    try {
        $response = Invoke-WebRequest -Uri $url -Headers $headers -Method Get -ErrorAction Stop
        Write-Debug "HTTP response status code: $($response.StatusCode)"
        Write-JsonDebug -message "HTTP response status code: $($response.StatusCode)" -jsonLogFilePath $jsonLogFilePath
    }
    catch {
        Write-Error "Failed to retrieve data from GitHub API: $_"
        Write-JsonDebug -message "Failed to retrieve data from GitHub API: $_" -jsonLogFilePath $jsonLogFilePath
        return $null
    }

    $responseContentPreview = $response.Content.Substring(0, [Math]::Min(200, $response.Content.Length))
    Write-Debug "Response content (first 200 chars): $responseContentPreview"
    Write-JsonDebug -message "Response content (first 200 chars): $responseContentPreview" -jsonLogFilePath $jsonLogFilePath

    try {
        $content = ConvertFrom-Json $response.Content
        Write-Debug "JSON successfully parsed; received $(if ($content -is [array]) { $content.Count } else { 'an object' })."
        Write-JsonDebug -message "JSON successfully parsed; received $(if ($content -is [array]) { $content.Count } else { 'an object' })." -jsonLogFilePath $jsonLogFilePath
    }
    catch {
        Write-Error "Failed to parse JSON from the response: $_"
        Write-JsonDebug -message "Failed to parse JSON from the response: $_" -jsonLogFilePath $jsonLogFilePath
        return $null
    }
    
    return $content
}

# Helper function to recursively replicate subfolders (only if submenu.txt exists)
function Replicate-Folder {
    param(
        [Parameter(Mandatory = $true)] [string]$remotePath,
        [Parameter(Mandatory = $true)] [string]$localParent,
        [Parameter(Mandatory = $true)] [string]$owner,
        [Parameter(Mandatory = $true)] [string]$repo,
        [Parameter(Mandatory = $true)] [string]$token,
        [Parameter(Mandatory = $false)] [string]$primaryLogFilePath,
        [Parameter(Mandatory = $true)] [string]$jsonLogFilePath
    )
    
    Write-Debug "Replicating folder: RemotePath='$remotePath', LocalParent='$localParent'"
    $contents = Get-GitHubRepoFolders -owner $owner -repo $repo -token $token -path $remotePath -jsonLogFilePath $jsonLogFilePath
    if (-not $contents) {
        Write-Debug "No contents found for $remotePath; skipping."
        return
    }
    
    $dirs = $contents | Where-Object { $_.type -eq "dir" }
    foreach ($dir in $dirs) {
        $dirRemotePath = Join-Path $remotePath $dir.name
        $subContents = Get-GitHubRepoFolders -owner $owner -repo $repo -token $token -path $dirRemotePath -jsonLogFilePath $jsonLogFilePath
        if ($subContents -and ($subContents | Where-Object { $_.type -eq "file" -and $_.name -ieq "submenu.txt" })) {
            $localSubFolder = Join-Path $localParent $dir.name
            if (-not (Test-Path $localSubFolder)) {
                New-Item -ItemType Directory -Path $localSubFolder | Out-Null
                Write-Host "Created local folder: $localSubFolder" -ForegroundColor Green
                if ($primaryLogFilePath) {
                    Write-Log -message "Created local folder: $localSubFolder" -logFilePath $primaryLogFilePath
                }
            }
            else {
                Write-Debug "Local folder already exists: $localSubFolder"
            }
            # Download submenu.txt first.
            $localSubmenu = Join-Path $localSubFolder "submenu.txt"
            $submenuRemote = $subContents | Where-Object { $_.type -eq "file" -and $_.name -ieq "submenu.txt" } | Select-Object -First 1
            if ($submenuRemote -and -not (Test-Path $localSubmenu)) {
                Write-Host "Downloading submenu.txt for folder $dirRemotePath" -ForegroundColor Cyan
                if ($primaryLogFilePath) {
                    Write-Log -message "Downloading submenu.txt for folder $dirRemotePath" -logFilePath $primaryLogFilePath
                }
                try {
                    Invoke-WebRequest -Uri $submenuRemote.download_url -OutFile $localSubmenu -UseBasicParsing
                }
                catch {
                    Write-Error "Failed to download submenu.txt for folder $dirRemotePath $_"
                }
            }
            # Recurse into subfolder.
            Replicate-Folder -remotePath $dirRemotePath -localParent $localSubFolder -owner $owner -repo $repo -token $token -primaryLogFilePath $primaryLogFilePath -jsonLogFilePath $jsonLogFilePath
        }
        else {
            Write-Debug "Skipping folder '$($dir.name)' because submenu.txt was not found in remote path $dirRemotePath."
        }
    }
}

function Update-OrgFolders {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [string]$workingDir,
        [Parameter(Mandatory = $true)]
            [ValidateSet("ONLINE","CACHED")]
            [string]$mode,
        [Parameter(Mandatory = $true)] [string]$owner,
        [Parameter(Mandatory = $true)] [string]$repo,
        [Parameter(Mandatory = $true)] [string]$token,
        [Parameter(Mandatory = $false)] [string]$primaryLogFilePath,
        [Parameter(Mandatory = $true)] [string]$jsonLogFilePath
    )
    Write-Debug "Entering Update-OrgFolders with mode: $mode"
    if ($mode -eq "ONLINE") {
        $apiRoot = "Poly.PKit\Orgs"
        $localOrgsRoot = Join-Path $workingDir "orgs"
        if (-not (Test-Path $localOrgsRoot)) {
            New-Item -ItemType Directory -Path $localOrgsRoot | Out-Null
            Write-Debug "Created root orgs folder: $localOrgsRoot"
        }
        $orgsRemote = Get-GitHubRepoFolders -owner $owner -repo $repo -token $token -path $apiRoot -jsonLogFilePath $jsonLogFilePath
        if ($orgsRemote) {
            foreach ($org in $orgsRemote | Where-Object { $_.type -eq "dir" }) {
                $orgRemotePath = Join-Path $apiRoot $org.name
                $orgContents = Get-GitHubRepoFolders -owner $owner -repo $repo -token $token -path $orgRemotePath -jsonLogFilePath $jsonLogFilePath
                if ($orgContents -and ($orgContents | Where-Object { $_.type -eq "file" -and $_.name -ieq "submenu.txt" })) {
                    $localOrgFolder = Join-Path $localOrgsRoot $org.name
                    if (-not (Test-Path $localOrgFolder)) {
                        New-Item -ItemType Directory -Path $localOrgFolder | Out-Null
                        Write-Host "Created org folder: $localOrgFolder" -ForegroundColor Green
                        if ($primaryLogFilePath) {
                            Write-Log -message "Created org folder: $localOrgFolder" -logFilePath $primaryLogFilePath
                        }
                    }
                    $localSubmenu = Join-Path $localOrgFolder "submenu.txt"
                    $submenuRemote = $orgContents | Where-Object { $_.type -eq "file" -and $_.name -ieq "submenu.txt" } | Select-Object -First 1
                    if ($submenuRemote -and -not (Test-Path $localSubmenu)) {
                        Write-Host "Downloading submenu.txt for org folder $orgRemotePath" -ForegroundColor Cyan
                        if ($primaryLogFilePath) {
                            Write-Log -message "Downloading submenu.txt for org folder $orgRemotePath" -logFilePath $primaryLogFilePath
                        }
                        try {
                            Invoke-WebRequest -Uri $submenuRemote.download_url -OutFile $localSubmenu -UseBasicParsing
                        }
                        catch {
                            Write-Error "Failed to download submenu.txt for org folder $orgRemotePath $_"
                        }
                    }
                    Replicate-Folder -remotePath $orgRemotePath -localParent $localOrgFolder -owner $owner -repo $repo -token $token -primaryLogFilePath $primaryLogFilePath -jsonLogFilePath $jsonLogFilePath
                }
                else {
                    Write-Host "Skipping org folder '$($org.name)' because submenu.txt was not found." -ForegroundColor Yellow
                    if ($primaryLogFilePath) {
                        Write-Log -message "Skipping org folder '$($org.name)' because submenu.txt was not found." -logFilePath $primaryLogFilePath
                    }
                }
            }
        }
        else {
            Write-Host "No organization folders retrieved from GitHub." -ForegroundColor Yellow
            if ($primaryLogFilePath) {
                Write-Log -message "No organization folders retrieved from GitHub." -logFilePath $primaryLogFilePath
            }
        }
    }
    Write-Debug "Exiting Update-OrgFolders."
}

function Sync-OrgFolderContents {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [string]$workingDir,
        [Parameter(Mandatory = $true)] [string]$orgRelativePath,
        [Parameter(Mandatory = $true)] [string]$owner,
        [Parameter(Mandatory = $true)] [string]$repo,
        [Parameter(Mandatory = $true)] [string]$token,
        [Parameter(Mandatory = $false)] [string]$primaryLogFilePath,
        [Parameter(Mandatory = $true)] [string]$jsonLogFilePath
    )
    Write-Debug "Syncing contents for org folder: $orgRelativePath"
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

Export-ModuleMember -Function Get-GitHubRepoFolders, Update-OrgFolders, Sync-OrgFolderContents
