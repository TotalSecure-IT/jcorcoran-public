function Get-GitHubRepoFolders {
    param (
        [string]$owner,
        [string]$repo,
        [string]$token,
        [string]$path = ""
    )

    Write-Debug "Entering Get-GitHubRepoFolders..."
    Write-Debug "Owner: $owner"
    Write-Debug "Repo: $repo"
    Write-Debug "Path parameter received: '$path'"

    # Set headers per GitHub documentation.
    $acceptHeader = "application/vnd.github+json"
    $apiVersionHeader = "2022-11-28"
    $authHeader = ""
    if ($token) {
        $authHeader = "Bearer $token"
        Write-Debug "Authorization header will be used."
    }
    else {
        Write-Debug "No token provided."
    }

    # Construct URL; use forward slashes.
    $url = "https://api.github.com/repos/$owner/$repo/contents/$path"
    Write-Debug "Constructed URL: $url"

    # Build the curl command arguments.
    $argsList = @(
        "-L", `
        "-H", "Accept: $acceptHeader", `
        "-H", "Authorization: $authHeader", `
        "-H", "X-GitHub-Api-Version: $apiVersionHeader", `
        $url
    )
    Write-Debug "Executing curl.exe with arguments: $argsList"
    
    try {
        # Execute curl.exe and capture output.
        $rawOutput = & curl.exe @argsList
        Write-Debug "Raw output from curl.exe: $rawOutput"
    }
    catch {
        Write-Error "Curl command failed: $_"
        return $null
    }
    
    try {
        $content = $rawOutput | ConvertFrom-Json
        Write-Debug "JSON successfully parsed."
    }
    catch {
        Write-Error "Failed to parse JSON: $_"
        return $null
    }
    
    # The API returns an array if the path is a directory.
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
        Write-Debug "Retrieving organization folders via Get-GitHubRepoFolders..."
        # Adjust the path string as needed; using backslash here as required by your repository.
        $orgsPath = "Poly.Pkit\orgs"
        Write-Debug "Using API path: $orgsPath"
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
        Write-Host "This app is bleeding edge with internet." -ForegroundColor Yellow
        if ($primaryLogFilePath) { Write-Log -message "Message: This app is bleeding edge with internet." -logFilePath $primaryLogFilePath }
        Write-Host "Running in CACHED mode." -ForegroundColor Yellow
        if ($primaryLogFilePath) { Write-Log -message "Running in CACHED mode for folder creation." -logFilePath $primaryLogFilePath }
        Write-Host "This app is much prettier with internet." -ForegroundColor Yellow
        if ($primaryLogFilePath) { Write-Log -message "Message: This app is much prettier with internet." -logFilePath $primaryLogFilePath }
        Write-Host "Running in CACHED mode." -ForegroundColor Yellow
        if ($primaryLogFilePath) { Write-Log -message "Running in CACHED mode for banner download." -logFilePath $primaryLogFilePath }
    }
    Write-Debug "Exiting Update-OrgFolders."
}

Export-ModuleMember -Function Get-GitHubRepoFolders, Update-OrgFolders
