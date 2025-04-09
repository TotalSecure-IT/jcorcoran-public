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
    Write-Debug "Original path parameter: '$path'"

    # Use your original header format: "token <token>"
    $headers = @{}
    if ($token) {
        $headers.Authorization = "token $token"
        Write-Debug "Authorization header set to: token ****"
    }
    else {
        Write-Debug "No token provided."
    }

    # Convert any backslashes in $path to forward slashes,
    # because GitHub expects URL paths with forward slashes.
    $pathClean = $path -replace "\\", "/"
    Write-Debug "Cleaned path: '$pathClean'"

    $url = "https://api.github.com/repos/$owner/$repo/contents/$pathClean"
    Write-Debug "Constructed URL: $url"
    Write-Debug "Headers: $(ConvertTo-Json $headers)"

    try {
        $response = Invoke-WebRequest -Uri $url -Headers $headers -Method Get -ErrorAction Stop
        Write-Debug "HTTP response status code: $($response.StatusCode)"
    }
    catch {
        Write-Error "Failed to retrieve data from GitHub API: $_"
        return $null
    }

    # Show the first 200 characters of the returned content for debugging.
    Write-Debug "Response content (first 200 chars): $($response.Content.Substring(0, [Math]::Min(200, $response.Content.Length)))"
    try {
        $content = ConvertFrom-Json $response.Content
        Write-Debug "JSON successfully parsed; received $(if($content -is [array]) { $content.Count } else { 'an object' })."
    }
    catch {
        Write-Error "Failed to parse JSON from the response: $_"
        return $null
    }
    
    # The API should return an array of objects (one per item in the directory).
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
        # Use the working path exactly as in your original script.
        $apiPath = "Poly.PKit\Orgs"
        Write-Debug "Using API path parameter: '$apiPath'"
        $orgsFromGitHub = Get-GitHubRepoFolders -owner $owner -repo $repo -token $token -path $apiPath
        
        if ($orgsFromGitHub) {
            Write-Host "Processing organization folders obtained from GitHub:" -ForegroundColor Cyan
            if ($primaryLogFilePath) {
                Write-Log -message "Processing organization folders obtained from GitHub." -logFilePath $primaryLogFilePath
            }
            foreach ($org in $orgsFromGitHub) {
                Write-Debug "Processing folder: $($org.name)"
                # Define the target folder under workingDir\Orgs (replicating the structure)
                $localOrgPath = Join-Path -Path (Join-Path $workingDir "Orgs") -ChildPath $org.name
                Write-Debug "Local folder path: $localOrgPath"
                if (-not (Test-Path -Path $localOrgPath)) {
                    Write-Host "Creating folder under Orgs: $($org.name)" -ForegroundColor Green
                    if ($primaryLogFilePath) {
                        Write-Log -message "Creating folder under Orgs: $($org.name)" -logFilePath $primaryLogFilePath
                    }
                    New-Item -ItemType Directory -Path $localOrgPath | Out-Null
                    Write-Debug "Folder created: $localOrgPath"
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
    Write-Debug "Exiting Update-OrgFolders."
}

Export-ModuleMember -Function Get-GitHubRepoFolders, Update-OrgFolders
