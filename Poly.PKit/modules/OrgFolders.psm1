function Get-GitHubRepoFolders {
    param (
        [string]$owner,
        [string]$repo,
        [string]$token,
        [string]$path = ""
    )

    # Comment $DebugPreference to silence the debug messages from this module.
    $DebugPreference = "Continue"

    Write-Debug "Entering Get-GitHubRepoFolders..."
    Write-Debug "Owner: $owner"
    Write-Debug "Repo: $repo"
    Write-Debug "Path parameter received: '$path'"

    $headers = @{}
    if ($token) {
        $headers.Authorization = "token $token"
        Write-Debug "Authorization header set."
    }
    else {
        Write-Debug "No token provided; proceeding without Authorization header."
    }

    # Construct URL; note that this will include the path parameter exactly as provided.
    $url = "https://api.github.com/repos/$owner/$repo/contents/$path"
    Write-Debug "Constructed URL: $url"
    Write-Debug "Headers: $(ConvertTo-Json $headers)"

    try {
        $response = Invoke-WebRequest -Uri $url -Headers $headers -Method Get -ErrorAction Stop
        Write-Debug "HTTP response status code: $($response.StatusCode)"
    }
    catch {
        Write-Error "Failed to retrieve data from GitHub API: $_"
        Write-Debug "Response Content: $($_.Exception.Response.Content)"
        return $null
    }
    
    Write-Debug "Response Content (raw): $($response.Content)"
    try {
        $content = ConvertFrom-Json $response.Content
        Write-Debug "JSON successfully parsed."
    }
    catch {
        Write-Error "Failed to parse JSON from response: $_"
        return $null
    }

    $folders = $content | Where-Object { $_.type -eq "dir" }
    Write-Debug "Found $($folders.Count) folder(s) in the response."
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

    Write-Debug "Entering Update-OrgFolders with mode: $mode"
    if ($mode -eq "ONLINE") {
        Write-Debug "Attempting to retrieve organization folders from GitHub using Get-GitHubRepoFolders..."
        # Use the backslash in the path as per your original working script.
        $orgsFromGitHub = Get-GitHubRepoFolders -owner $owner -repo $repo -token $token -path "Poly.Pkit\orgs"
        if ($orgsFromGitHub) {
            Write-Host "Processing organization folders obtained from GitHub:" -ForegroundColor Cyan
            if ($primaryLogFilePath) {
                Write-Log -message "Processing organization folders obtained from GitHub." -logFilePath $primaryLogFilePath
            }
            foreach ($org in $orgsFromGitHub) {
                Write-Debug "Processing folder: $($org.name)"
                # Define the target folder under workingDir\orgs.
                $localOrgPath = Join-Path -Path (Join-Path $workingDir "orgs") -ChildPath $org.name
                Write-Debug "Local target folder path: $localOrgPath"
                if (-not (Test-Path -Path $localOrgPath)) {
                    Write-Host "Creating folder under orgs: $($org.name)" -ForegroundColor Green
                    if ($primaryLogFilePath) {
                        Write-Log -message "Creating folder under orgs: $($org.name)" -logFilePath $primaryLogFilePath
                    }
                    New-Item -ItemType Directory -Path $localOrgPath | Out-Null
                    Write-Debug "Folder created: $localOrgPath"
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
    Write-Debug "Exiting Update-OrgFolders."
}

Export-ModuleMember -Function Get-GitHubRepoFolders, Update-OrgFolders
