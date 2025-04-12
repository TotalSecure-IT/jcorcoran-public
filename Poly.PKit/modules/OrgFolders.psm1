<#
.SYNOPSIS
    Replicates remote organization subfolders locally.
.DESCRIPTION
    Retrieves the GitHub tree for the given organization folder SHA and creates local folders.
    Updates live stats about discovered folders and downloaded submenu files.
.EXAMPLE
    Update-OrgFolder -workingDir "C:\MyWorkingDir" -mode "ONLINE" -owner "TotalSecure-IT" `
      -repo "jcorcoran-public" -token "mytoken" -orgsFolderSha "8b8cde2fe87d2155653ddbdaa7530e01b84047bf" `
      -primaryLogFilePath "C:\MyWorkingDir\logs\MyHost.log"
#>

#region Script-Scope Variables
# Instead of global variables, we use script scope:
$script:OrgFoldersDiscovered    = 0
$script:OrgFoldersSkipped       = 0
$script:MenuFilesDiscovered     = 0
$script:StatsTableLine          = $null
#endregion Script-Scope Variables

function Invoke-LiveStat {
    <#
    .SYNOPSIS
        Updates the live console stats.
    .DESCRIPTION
        Writes out counts for discovered folders, menu files, and skipped folders.
    #>
    if (-not $script:StatsTableLine) { return }
    $startX = 0
    $startY = $script:StatsTableLine
    $oldPos = $Host.UI.RawUI.CursorPosition

    $Host.UI.RawUI.CursorPosition = [System.Management.Automation.Host.Coordinates]::new($startX, $startY)
    Write-Host "Organization Folders discovered: " -NoNewLine -ForegroundColor White
    Write-Host $script:OrgFoldersDiscovered -ForegroundColor Green

    $Host.UI.RawUI.CursorPosition = [System.Management.Automation.Host.Coordinates]::new($startX, $startY + 1)
    Write-Host "Menu files discovered:          " -NoNewLine -ForegroundColor White
    Write-Host $script:MenuFilesDiscovered -ForegroundColor Green

    $Host.UI.RawUI.CursorPosition = [System.Management.Automation.Host.Coordinates]::new($startX, $startY + 2)
    Write-Host "Organization Folders skipped:   " -NoNewLine -ForegroundColor White
    Write-Host $script:OrgFoldersSkipped -ForegroundColor Green

    $Host.UI.RawUI.CursorPosition = $oldPos
}

function Get-OrgFolderTree {
    <#
    .SYNOPSIS
        Retrieves GitHub tree data for the organization folder.
    .DESCRIPTION
        Uses provided owner, repo, token, and SHA to retrieve the GitHub tree.
    .EXAMPLE
        $tree = Get-OrgFolderTree -owner "TotalSecure-IT" -repo "jcorcoran-public" `
          -token "mytoken" -orgsFolderSha "..."
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$owner,
        [Parameter(Mandatory=$true)][string]$repo,
        [Parameter(Mandatory=$true)][string]$token,
        [Parameter(Mandatory=$true)][string]$orgsFolderSha
    )
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
            Write-Error "Tree data not found or empty for SHA: $orgsFolderSha"
            return $null
        }
    }
    catch {
        Write-Error "Failed to retrieve OrgFolder tree: $_"
        return $null
    }
}

function Update-OrgFolder {
    <#
    .SYNOPSIS
        Creates a local folder for an organization item.
    .DESCRIPTION
        Creates the folder if it does not exist; increments counters appropriately.
    .EXAMPLE
        Update-OrgFolder -orgPath "C:\MyWorkingDir\orgs\MyOrg" -primaryLogFilePath "C:\MyWorkingDir\logs\log.txt"
    #>
    param(
        [Parameter(Mandatory=$true)][string]$orgPath,
        [Parameter(Mandatory=$false)][string]$primaryLogFilePath
    )
    if (-not (Test-Path $orgPath)) {
        $script:OrgFoldersDiscovered++
        Invoke-LiveStat
        New-Item -ItemType Directory -Path $orgPath | Out-Null
        if ($primaryLogFilePath) {
            Write-Log "Created org folder: $orgPath" -logFilePath $primaryLogFilePath
        }
    }
    else {
        $script:OrgFoldersSkipped++
        Invoke-LiveStat
    }
}

function Update-OrgFolders {
    <#
    .SYNOPSIS
        Replicates organization subfolders from GitHub.
    .DESCRIPTION
        Retrieves the tree using Get-OrgFolderTree, creates local folders,
        and attempts to download submenu.txt files.
    .EXAMPLE
        Update-OrgFolders -workingDir "C:\MyWorkingDir" -mode "ONLINE" -owner "TotalSecure-IT" `
          -repo "jcorcoran-public" -token "mytoken" -orgsFolderSha "..." -primaryLogFilePath "C:\MyWorkingDir\logs\log.txt"
    #>
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [Parameter(Mandatory=$true)][string]$workingDir,
        [Parameter(Mandatory=$true)][ValidateSet("ONLINE", "CACHED")][string]$mode,
        [Parameter(Mandatory=$true)][string]$owner,
        [Parameter(Mandatory=$true)][string]$repo,
        [Parameter(Mandatory=$true)][string]$token,
        [Parameter(Mandatory=$true)][string]$orgsFolderSha,
        [Parameter(Mandatory=$false)][string]$primaryLogFilePath
    )

    if ($mode -ne "ONLINE") {
        Write-Host "CACHED mode not implemented. Exiting..." -ForegroundColor Yellow
        return
    }

    Write-Host "Using orgsFolderSha='$orgsFolderSha' to replicate subfolders..."
    $script:StatsTableLine = $Host.UI.RawUI.CursorPosition.Y + 1
    Invoke-LiveStat

    $orgsItems = Get-OrgFolderTree -owner $owner -repo $repo -token $token -orgsFolderSha $orgsFolderSha
    if (-not $orgsItems) {
        Write-Error "No subfolders found in OrgFolders for SHA: $orgsFolderSha"
        return
    }

    $orgsRoot = Join-Path $workingDir "orgs"
    if (-not (Test-Path $orgsRoot)) {
        New-Item -ItemType Directory -Path $orgsRoot | Out-Null
    }

    foreach ($item in $orgsItems) {
        if ($item.type -eq "tree") {
            $subLocalFolder = Join-Path $orgsRoot $item.path
            Update-OrgFolder -orgPath $subLocalFolder -primaryLogFilePath $primaryLogFilePath

            $localSubmenu = Join-Path $subLocalFolder "submenu.txt"
            if (-not (Test-Path $localSubmenu)) {
                $rawSubmenuUrl = "https://raw.githubusercontent.com/TotalSecure-IT/jcorcoran-public/refs/heads/main/Poly.PKit/Orgs/$($item.path)/submenu.txt"
                try {
                    Invoke-WebRequest -Uri $rawSubmenuUrl -OutFile $localSubmenu -UseBasicParsing -ErrorAction Stop
                    $script:MenuFilesDiscovered++
                    Invoke-LiveStat
                    if ($primaryLogFilePath) {
                        Write-Log "Downloaded submenu.txt for $($item.path)" -logFilePath $primaryLogFilePath
                    }
                }
                catch {
                    Write-Error "Failed to download submenu.txt for $($item.path): $_"
                }
            }
        }
    }
}

Export-ModuleMember -Function Update-OrgFolders, Get-OrgFolderTree, Invoke-LiveStat
