function Get-GitHubFolderTree {
    param(
        [string]$owner,
        [string]$repo,
        [string]$token,
        [string]$ref = "HEAD",     # use HEAD by default
        [string]$targetPath = "Poly.PKit/orgs"  # target folder in repo
    )

    Write-Debug "Entering Get-GitHubFolderTree..."
    Write-Debug "Owner: $owner"
    Write-Debug "Repo: $repo"
    Write-Debug "Ref: $ref"
    Write-Debug "TargetPath: $targetPath"

    $acceptHeader = "application/vnd.github+json"
    $apiVersionHeader = "2022-11-28"
    $authHeader = ""
    if ($token) {
        $authHeader = "Bearer $token"
        Write-Debug "Authorization header will be set."
    }
    else {
        Write-Debug "No token provided."
    }

    # Construct URL using the Git Trees API with recursive=1
    $url = "https://api.github.com/repos/$owner/$repo/git/trees/$ref?recursive=1"
    Write-Debug "Constructed Git Tree URL: $url"

    # Build curl arguments (using native curl.exe)
    $argsList = @(
        "-L",
        "-H", "Accept: $acceptHeader",
        "-H", "Authorization: $authHeader",
        "-H", "X-GitHub-Api-Version: $apiVersionHeader",
        $url
    )
    Write-Debug "Executing curl.exe with arguments: $argsList"
    try {
        $rawOutput = & curl.exe @argsList
        Write-Debug "Raw output from curl.exe: $rawOutput"
    }
    catch {
        Write-Error "curl.exe command failed: $_"
        return $null
    }
    
    try {
        $treeData = $rawOutput | ConvertFrom-Json
        Write-Debug "JSON parsed successfully. Total items in tree: $($treeData.tree.Count)"
    }
    catch {
        Write-Error "Failed to parse JSON: $_"
        return $null
    }
    
    # Filter for folder items: those with type "tree" whose path starts with targetPath.
    $folders = $treeData.tree | Where-Object { $_.type -eq "tree" -and $_.path -like "$targetPath*" }
    Write-Debug "Found $($folders.Count) folder(s) under path '$targetPath'."
    return $folders
}

function Update-OrgFolders {
    [CmdletBinding()]
    param(
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
        # Retrieve the full folder tree using the Git Trees API.
        $targetPath = "Poly.PKit/orgs"
        Write-Debug "Retrieving folder tree for target: $targetPath"
        $folders = Get-GitHubFolderTree -owner $owner -repo $repo -token $token -targetPath $targetPath
        if ($folders) {
            Write-Host "Processing folder tree from GitHub:" -ForegroundColor Cyan
            if ($primaryLogFilePath) {
                Write-Log -message "Processing folder tree from GitHub." -logFilePath $primaryLogFilePath
            }
            foreach ($folder in $folders) {
                Write-Debug "Found folder: $($folder.path)"
                # Remove the leading target path (e.g., "Poly.PKit/orgs") to obtain the relative folder structure.
                $relativePath = $folder.path.Substring($targetPath.Length).TrimStart("/", "\")
                # Build the corresponding local folder path under workingDir\orgs.
                $localFolderPath = Join-Path -Path (Join-Path $workingDir "orgs") $relativePath
                Write-Debug "Local folder path will be: $localFolderPath"
                if (-not (Test-Path -Path $localFolderPath)) {
                    Write-Host "Creating folder: $localFolderPath" -ForegroundColor Green
                    if ($primaryLogFilePath) {
                        Write-Log -message "Creating folder: $localFolderPath" -logFilePath $primaryLogFilePath
                    }
                    New-Item -ItemType Directory -Path $localFolderPath | Out-Null
                }
                else {
                    Write-Host "Folder already exists: $localFolderPath" -ForegroundColor Yellow
                    if ($primaryLogFilePath) {
                        Write-Log -message "Folder already exists: $localFolderPath" -logFilePath $primaryLogFilePath
                    }
                }
            }
        }
        else {
            Write-Host "No folder data retrieved from GitHub." -ForegroundColor Yellow
            if ($primaryLogFilePath) {
                Write-Log -message "No folder data retrieved from GitHub." -logFilePath $primaryLogFilePath
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

Export-ModuleMember -Function Get-GitHubFolderTree, Update-OrgFolders
