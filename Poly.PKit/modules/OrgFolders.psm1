function Get-GitHubRepoFolders {
    param (
        [string]$owner,
        [string]$repo,
        [string]$token,
        [string]$path = ""
    )

    $headers = @{}
    if ($token) {
        $headers.Authorization = "token $token"
    }

    $url = "https://api.github.com/repos/$owner/$repo/contents/$path"
    
    try {
        $response = Invoke-WebRequest -Uri $url -Headers $headers -Method Get -ErrorAction Stop
    }
    catch {
        Write-Error "Failed to retrieve data from GitHub API: $_"
        return $null
    }
    
    $content = ConvertFrom-Json $response.Content
    $folders = $content | Where-Object { $_.type -eq "dir" }
    return $folders
}

function Update-OrgFolders {
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
        # Use Get-GitHubRepoFolders to obtain organization folders from GitHub.
        $orgsFromGitHub = Get-GitHubRepoFolders -owner $owner -repo $repo -token $token -path "Poly.PKit/orgs"
        if ($orgsFromGitHub) {
            Write-Host "Processing organization folders obtained from GitHub:" -ForegroundColor Cyan
            if ($primaryLogFilePath) {
                Write-Log -message "Processing organization folders obtained from GitHub." -logFilePath $primaryLogFilePath
            }
            foreach ($org in $orgsFromGitHub) {
                # Define the target folder under workingDir\orgs.
                $localOrgPath = Join-Path -Path (Join-Path $workingDir "orgs") -ChildPath $org.name
                if (-not (Test-Path -Path $localOrgPath)) {
                    Write-Host "Creating folder under orgs: $($org.name)" -ForegroundColor Green
                    if ($primaryLogFilePath) {
                        Write-Log -message "Creating folder under orgs: $($org.name)" -logFilePath $primaryLogFilePath
                    }
                    New-Item -ItemType Directory -Path $localOrgPath | Out-Null
                }
                else {
                    Write-Host "Folder under orgs already exists: $($org.name)" -ForegroundColor Yellow
                    if ($primaryLogFilePath) {
                        Write-Log -message "Folder under orgs already exists: $($org.name)" -logFilePath $primaryLogFilePath
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
    elseif ($mode -eq "CACHED") {
        # In cached mode simply print messages.
        Write-Host "This app is bleeding edge with internet." -ForegroundColor Yellow
        if ($primaryLogFilePath) {
            Write-Log -message "Message: This app is bleeding edge with internet." -logFilePath $primaryLogFilePath
        }
        Write-Host "Running in CACHED mode." -ForegroundColor Red
        if ($primaryLogFilePath) {
            Write-Log -message "Running in CACHED mode for folder creation." -logFilePath $primaryLogFilePath
        }
        Write-Host "This app is much prettier with internet." -ForegroundColor Yellow
        if ($primaryLogFilePath) {
            Write-Log -message "Message: This app is much prettier with internet." -logFilePath $primaryLogFilePath
        }
        Write-Host "Running in CACHED mode." -ForegroundColor Red
        if ($primaryLogFilePath) {
            Write-Log -message "Running in CACHED mode for banner download." -logFilePath $primaryLogFilePath
        }
    }
}

Export-ModuleMember -Function Get-GitHubRepoFolders, Update-OrgFolders
