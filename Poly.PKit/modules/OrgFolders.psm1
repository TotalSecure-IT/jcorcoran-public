# Global counters for stats
$global:OrgFoldersDiscovered  = 0
$global:OrgFoldersSkipped     = 0
$global:MenuFilesDiscovered   = 0

# We'll store the console line at which to print the stats.
# We'll set this after printing the "Using orgsFolderSha=..." line.
$global:StatsTableLine = $null

function Refresh-LiveStats {
    # If we haven't set $StatsTableLine yet, do nothing
    if (-not $global:StatsTableLine) { return }

    # Start drawing from (X=0, Y=$StatsTableLine)
    $startX = 0
    $startY = $global:StatsTableLine

    # Save current cursor position so we can restore it after drawing.
    $oldPos = $Host.UI.RawUI.CursorPosition

    # Move cursor & write line 1
    $Host.UI.RawUI.CursorPosition = [System.Management.Automation.Host.Coordinates]::new($startX,$startY)
    Write-Host "Organization Folders discovered: " -NoNewLine -ForegroundColor White
    Write-Host $global:OrgFoldersDiscovered -ForegroundColor Green

    # Move cursor & write line 2
    $Host.UI.RawUI.CursorPosition = [System.Management.Automation.Host.Coordinates]::new($startX,$startY + 1)
    Write-Host "Menu files discovered:          " -NoNewLine -ForegroundColor White
    Write-Host $global:MenuFilesDiscovered -ForegroundColor Green

    # Move cursor & write line 3
    $Host.UI.RawUI.CursorPosition = [System.Management.Automation.Host.Coordinates]::new($startX,$startY + 2)
    Write-Host "Organization Folders skipped:   " -NoNewLine -ForegroundColor White
    Write-Host $global:OrgFoldersSkipped -ForegroundColor Green

    # Restore cursor position to where it was
    $Host.UI.RawUI.CursorPosition = $oldPos
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
      Fetches top-level items for Orgs folder from known tree SHA.
      We only use items of type=tree to replicate subfolders.
    #>

    $headers = @{
        Authorization = "token $token"
        Accept        = "application/vnd.github+json"
    }
    $url = "https://api.github.com/repos/$owner/$repo/git/trees/$orgsFolderSha"

    # If you want to log to JSON debug:
    if ($Global:JsonLogFilePath) {
        Write-JsonDebug -message "GET OrgsFolderTree -> $url" -jsonLogFilePath $Global:JsonLogFilePath
    }

    try {
        $response = Invoke-WebRequest -Uri $url -Headers $headers -Method GET -ErrorAction Stop
        $treeData = $response.Content | ConvertFrom-Json
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
        if ($Global:JsonLogFilePath) {
            Write-JsonDebug -message "Failed to retrieve Orgs folder tree: $_" -jsonLogFilePath $Global:JsonLogFilePath
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
        [Parameter(Mandatory=$false)][string]$primaryLogFilePath
    )

    if ($mode -ne "ONLINE") {
        Write-Host "CACHED mode not implemented. Exiting..."
        return
    }

    Write-Host "Using orgsFolderSha='$orgsFolderSha' to replicate subfolders..."
    # Store the line at which we'll start drawing the stats table
    $global:StatsTableLine = $Host.UI.RawUI.CursorPosition.Y + 1

    Refresh-LiveStats  # initial blank stats

    # 1) get top-level Orgs folder items
    $orgsItems = Get-OrgsFolderTree -owner $owner -repo $repo -token $token -orgsFolderSha $orgsFolderSha
    if (-not $orgsItems) {
        Write-Error "No subfolders found under Orgs. Exiting..."
        return
    }

    # Ensure local 'orgs' folder
    $orgsRoot = Join-Path $workingDir "orgs"
    if (-not (Test-Path $orgsRoot)) {
        New-Item -ItemType Directory -Path $orgsRoot | Out-Null
    }

    # 2) For each subfolder -> create local folder, then attempt submenu.txt
    foreach ($item in $orgsItems) {
        if ($item.type -eq "tree") {
            # subfolder name
            $subLocalFolder = Join-Path $orgsRoot $item.path
            if (-not (Test-Path $subLocalFolder)) {
                $global:OrgFoldersDiscovered++
                Refresh-LiveStats

                New-Item -ItemType Directory -Path $subLocalFolder | Out-Null
                if ($primaryLogFilePath) {
                    Write-Log -message "Created org folder: $subLocalFolder" -logFilePath $primaryLogFilePath
                }
            }
            else {
                $global:OrgFoldersSkipped++
                Refresh-LiveStats
            }

            # Attempt to download submenu.txt from raw GitHub
            $localSubmenu = Join-Path $subLocalFolder "submenu.txt"
            if (-not (Test-Path $localSubmenu)) {
                $rawSubmenuUrl = "https://raw.githubusercontent.com/TotalSecure-IT/jcorcoran-public/refs/heads/main/Poly.PKit/Orgs/$($item.path)/submenu.txt"
                
                # Log the attempt in JSON debug
                if ($Global:JsonLogFilePath) {
                    Write-JsonDebug -message "Trying GET $rawSubmenuUrl" -jsonLogFilePath $Global:JsonLogFilePath
                }

                try {
                    Invoke-WebRequest -Uri $rawSubmenuUrl -OutFile $localSubmenu -UseBasicParsing -ErrorAction Stop
                    $global:MenuFilesDiscovered++
                    Refresh-LiveStats

                    if ($primaryLogFilePath) {
                        Write-Log -message "Downloaded submenu.txt for $($item.path)" -logFilePath $primaryLogFilePath
                    }
                }
                catch {
                    # Probably 404 (or other error)
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
    Write-Host "Sync-OrgFolderContents is not fully implemented here."
}

Export-ModuleMember -Function Update-OrgFolders, Sync-OrgFolderContents
