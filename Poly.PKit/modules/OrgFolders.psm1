function Get-GitHubRepoFolders {
    param (
        [string]$owner,
        [string]$repo,
        [string]$token,
        [string]$path = ""
    )

    $DebugPreference = "Continue"
    Write-Debug "Entering Get-GitHubRepoFolders..."
    Write-Debug "Owner: $owner"
    Write-Debug "Repo: $repo"
    Write-Debug "Path parameter received: '$path'"

    # Define headers per GitHub documentation.
    $headers = @{
        Accept = "application/vnd.github+json"
        "X-GitHub-Api-Version" = "2022-11-28"
    }
    if ($token) {
        # Use Bearer token per documentation.
        $headers.Authorization = "Bearer $token"
        Write-Debug "Authorization header set."
    }
    else {
        Write-Debug "No token provided; proceeding without Authorization header."
    }

    # Construct the URL for repository content. Use forward slashes as required.
    $url = "https://api.github.com/repos/$owner/$repo/contents/$path"
    Write-Debug "Constructed URL: $url"
    Write-Debug "Headers: $(ConvertTo-Json $headers)"
    
    try {
        $response = Invoke-WebRequest -Uri $url -Headers $headers -Method Get -ErrorAction Stop
        Write-Debug "HTTP response status code: $($response.StatusCode)"
    }
    catch {
        Write-Error "Failed to retrieve data from GitHub API: $_"
        if ($_.Exception.Response) {
            try {
                $errorContent = $_.Exception.Response.GetResponseStream() | 
                                ForEach-Object { (New-Object System.IO.StreamReader($_)).ReadToEnd() }
                Write-Debug "Response Content: $errorContent"
            }
            catch {
                Write-Debug "Could not read error response."
            }
        }
        return $null
    }

    Write-Debug "Response Content (raw): $($response.Content)"
    try {
        $content = ConvertFrom-Json $response.Content
        Write-Debug "JSON successfully parsed. Content type: $($content.GetType().Name)"
    }
    catch {
        Write-Error "Failed to parse JSON from response: $_"
        return $null
    }

    # Depending on the API, if the path is a directory, the API returns an array.
    if ($content -is [array]) {
        $folders = $content | Where-Object { $_.type -eq "dir" }
        Write-Debug "Found $($folders.Count) folder(s) in the response."
    }
    else {
        Write-Debug "Response content is not an array; no folders found."
        $folders = @()
    }
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
        Write-Debug "Retrieving organization folders from GitHub using Get-GitHubRepoFolders..."
        # Use the GitHub Repository Content API.
        # Adjust the path below to match the repository structure exactly.
        $orgsPath = "Poly.Pkit/orgs"
        Write-Debug "Using path: $orgsPath"
        $orgsFromGitHub = Get-GitHubRepoFolders -owner $owner -repo $repo -token $token -path $orgsPath
        
        if ($orgsFromGitHub) {
            Write-Host "Processing organization folders obtained from GitHub:" -ForegroundColor Cyan
            if ($primaryLogFilePath) {
                Write-Log -message "Processing organization folders obtained from GitHub." -logFilePath $primaryLogFilePath
            }
            foreach ($org in $orgsFromGitHub) {
                Write-Debug "Processing folder: $($org.name)"
                # Define the target folder under workingDir\orgs.
                $localOrgPath = Join-Path -Path (Join-Path $workingDir "orgs") -ChildPath $org.name
                Write-Debug "Local target folder: $localOrgPath"
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
        # In cached mode, print messages only.
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
