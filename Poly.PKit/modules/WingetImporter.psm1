# WingetImporter.psm1
# -----------------------------------------
# For "ONBOARD" action: downloads apps.json and banner.txt,
# prints the banner once, then runs winget import to install from the local apps.json.
#
# Export a single function: Invoke-Onboard

Export-ModuleMember -Function Invoke-Onboard

$Global:BannerBlankLines = 3  # number of empty lines to insert after banner

function Invoke-Onboard {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$appsJson,
        [Parameter(Mandatory=$true)][string]$folderName,
        [Parameter(Mandatory=$true)][string]$workingDir
    )
    <#
       Steps:
         1) Download apps.json into workingDir\orgs\$folderName\apps.json
         2) Download banner.txt into the same folder
         3) Clear the screen
         4) Print the banner once, followed by a few blank lines
         5) Run winget import on the local apps.json so that winget’s output appears normally
         6) Wait for user input before continuing
    #>

    # 1) Download apps.json
    $orgFolder     = Join-Path (Join-Path $workingDir "orgs") $folderName
    if (-not (Test-Path $orgFolder)) {
        New-Item -ItemType Directory -Path $orgFolder | Out-Null
    }
    $appsJsonLocal = Join-Path $orgFolder "apps.json"
    try {
        Invoke-WebRequest -Uri $appsJson -OutFile $appsJsonLocal -UseBasicParsing -ErrorAction Stop
    }
    catch {
        Write-Host "Error downloading apps.json: $_" -ForegroundColor Red
        Write-Host "Press any key to return..."
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        return
    }

    # 2) Download banner.txt
    $bannerUrl   = "https://raw.githubusercontent.com/TotalSecure-IT/jcorcoran-public/refs/heads/main/Poly.PKit/orgs/$folderName/banner.txt"
    $bannerLocal = Join-Path $orgFolder "banner.txt"
    try {
        Invoke-WebRequest -Uri $bannerUrl -OutFile $bannerLocal -UseBasicParsing -ErrorAction Stop
    }
    catch {
        Write-Host "Error downloading banner.txt: $_" -ForegroundColor Yellow
        Write-Host "Proceeding without a banner..."
        $bannerLocal = $null
    }

    # 3) Clear the screen
    Clear-Host

    # 4) Print the banner once
    if ($bannerLocal -and (Test-Path $bannerLocal)) {
        # Print each line of the banner with a custom foreground color (adjust as needed)
        Get-Content $bannerLocal | ForEach-Object { Write-Host $_ -ForegroundColor Yellow }
    }
    else {
        Write-Host "No banner found for $folderName." -ForegroundColor Yellow
    }
    # Print a few blank lines
    for ($i = 1; $i -le $Global:BannerBlankLines; $i++) {
        Write-Host ""
    }

    # 5) Run winget import using the local apps.json file
    $wingetArgs = "import `"$appsJsonLocal`" --accept-package-agreements --accept-source-agreements --disable-interactivity"
    Write-Host "Executing: winget $wingetArgs" -ForegroundColor Green
    # Call winget directly in PowerShell so that its output is not intercepted or wrapped by cmd
    & winget import $appsJsonLocal --accept-package-agreements --accept-source-agreements --disable-interactivity

    # 6) Wait for user input before returning control
    Write-Host "winget install finished. Press any key to continue..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

