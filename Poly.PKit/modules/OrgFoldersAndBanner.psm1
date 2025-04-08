function Update-OrgFoldersAndBanners {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$workingDir,
        [Parameter(Mandatory = $true)]
        [ValidateSet("ONLINE","CACHED")]
        [string]$mode,
        [Parameter(Mandatory = $true)]
        [string]$owner,
        [Parameter(Mandatory = $true)]
        [string]$repo,
        [Parameter(Mandatory = $true)]
        [string]$token,
        [Parameter(Mandatory = $false)]
        [string]$primaryLogFilePath
    )

    if ($mode -eq "ONLINE") {
        # Import the list-orgs module if available.
        $listOrgsModulePath = Join-Path $workingDir "modules\list-orgs.psm1"
        if (Test-Path -Path $listOrgsModulePath) {
            Import-Module $listOrgsModulePath -Force
            Write-Host "list-orgs module imported." -ForegroundColor Cyan
            if ($primaryLogFilePath) {
                Write-Log -message "list-orgs module imported." -logFilePath $primaryLogFilePath
            }
            
            # Retrieve organization folders from GitHub using list-orgs (function assumed to be Get-GitHubRepoFolders).
            $orgsFromGitHub = Get-GitHubRepoFolders -owner $owner -repo $repo -token $token -path "Poly.PKit/orgs"
            if ($orgsFromGitHub) {
                Write-Host "Processing organization folders obtained from GitHub:" -ForegroundColor Cyan
                if ($primaryLogFilePath) {
                    Write-Log -message "Processing organization folders obtained from GitHub." -logFilePath $primaryLogFilePath
                }
                foreach ($org in $orgsFromGitHub) {
                    # Define target folder under workingDir\Orgs.
                    $localOrgPath = Join-Path -Path (Join-Path $workingDir "Orgs") -ChildPath $org.name
                    if (-not (Test-Path -Path $localOrgPath)) {
                        Write-Host "Creating folder under Orgs: $($org.name)" -ForegroundColor Green
                        if ($primaryLogFilePath) {
                            Write-Log -message "Creating folder under Orgs: $($org.name)" -logFilePath $primaryLogFilePath
                        }
                        New-Item -ItemType Directory -Path $localOrgPath | Out-Null
                    }
                    else {
                        Write-Host "Folder under Orgs already exists: $($org.name)" -ForegroundColor Yellow
                        if ($primaryLogFilePath) {
                            Write-Log -message "Folder under Orgs already exists: $($org.name)" -logFilePath $primaryLogFilePath
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
        else {
            Write-Host "list-orgs module not found; skipping organization folder creation." -ForegroundColor Yellow
            if ($primaryLogFilePath) {
                Write-Log -message "list-orgs module not found; skipping organization folder creation." -logFilePath $primaryLogFilePath
            }
        }
        
        # Download banner files and save them under workingDir\configs.
        $configsPath = Join-Path $workingDir "configs"
        $mainbannerURL = "https://raw.githubusercontent.com/TotalSecure-IT/jcorcoran-public/refs/heads/main/Poly.PKit/configs/mainbanner.txt"
        $motdURL = "https://raw.githubusercontent.com/TotalSecure-IT/jcorcoran-public/refs/heads/main/Poly.PKit/configs/motd.txt"
        try {
            Invoke-WebRequest -Uri $mainbannerURL -OutFile (Join-Path $configsPath "mainbanner.txt") -UseBasicParsing
            Write-Host "Downloaded mainbanner.txt from GitHub." -ForegroundColor Cyan
            if ($primaryLogFilePath) {
                Write-Log -message "Downloaded mainbanner.txt from GitHub." -logFilePath $primaryLogFilePath
            }
        }
        catch {
            Write-Host "Failed to download mainbanner.txt from GitHub." -ForegroundColor Red
            if ($primaryLogFilePath) {
                Write-Log -message "Failed to download mainbanner.txt from GitHub." -logFilePath $primaryLogFilePath
            }
        }
        
        try {
            Invoke-WebRequest -Uri $motdURL -OutFile (Join-Path $configsPath "motd.txt") -UseBasicParsing
            Write-Host "Downloaded motd.txt from GitHub." -ForegroundColor Cyan
            if ($primaryLogFilePath) {
                Write-Log -message "Downloaded motd.txt from GitHub." -logFilePath $primaryLogFilePath
            }
        }
        catch {
            Write-Host "Failed to download motd.txt from GitHub." -ForegroundColor Red
            if ($primaryLogFilePath) {
                Write-Log -message "Failed to download motd.txt from GitHub." -logFilePath $primaryLogFilePath
            }
        }
    }
    elseif ($mode -eq "CACHED") {
        # In cached mode, simply print messages.
        Write-Host "This app is bleeding edge with internet." -ForegroundColor Yellow
        if ($primaryLogFilePath) {
            Write-Log -message "Message: This app is bleeding edge with internet." -logFilePath $primaryLogFilePath
        }
        Write-Host "Running in CACHED mode." -ForegroundColor Yellow
        if ($primaryLogFilePath) {
            Write-Log -message "Running in CACHED mode for folder creation." -logFilePath $primaryLogFilePath
        }
        
        Write-Host "This app is much prettier with internet." -ForegroundColor Yellow
        if ($primaryLogFilePath) {
            Write-Log -message "Message: This app is must prettier with internet." -logFilePath $primaryLogFilePath
        }
        Write-Host "Running in CACHED mode." -ForegroundColor Yellow
        if ($primaryLogFilePath) {
            Write-Log -message "Running in CACHED mode for banner download." -logFilePath $primaryLogFilePath
        }
    }
}

Export-ModuleMember -Function Update-OrgFoldersAndBanners
