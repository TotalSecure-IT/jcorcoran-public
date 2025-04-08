<#
*~~~~~~~~~~~~~~~~~~~~~*
|  Poly.PKit v1.0.1b  |
*~~~~~~~~~~~~~~~~~~~~~*
#>

Clear-Host

#------------------------------------------------------------------
# Set Working Directories
#------------------------------------------------------------------
# workingDir is the parent folder where launcher.bat resides.
$workingDir = Split-Path -Parent $PSScriptRoot
Set-Location $workingDir

# init folder is where main.ps1 resides.
$initDir = $PSScriptRoot

# Modules folder is inside init.
$modulesFolder = Join-Path $initDir "modules"
if (-not (Test-Path -Path $modulesFolder)) {
    New-Item -ItemType Directory -Path $modulesFolder | Out-Null
}

#------------------------------------------------------------------
# Determine Mode (ONLINE vs CACHED) and Download Modules if ONLINE
#------------------------------------------------------------------
$mode = $null
if ($args -contains '--online-mode') {
    $mode = "ONLINE"
    Write-Host "Mode:" -NoNewline
    Write-Host " ONLINE" -ForegroundColor Green
}
elseif ($args -contains '--cached-mode') {
    $mode = "CACHED"
    Write-Host "Mode:" -NoNewline
    Write-Host " CACHED" -ForegroundColor Red
}
else {
    Write-Host "No mode specified. Defaulting to CACHED."
    $mode = "CACHED"
}

if ($mode -eq "ONLINE") {
    # Download modules manifest from GitHub.
    $modulesManifestURL = "https://raw.githubusercontent.com/TotalSecure-IT/jcorcoran-public/refs/heads/main/Poly.PKit/modules/modules_manifest.txt"
    try {
        Write-Host "Downloading modules manifest from GitHub..."
        $manifestResponse = Invoke-WebRequest -Uri $modulesManifestURL -UseBasicParsing
        $moduleList = $manifestResponse.Content -split "\r?\n" | Where-Object {$_.Trim() -ne ""}
    }
    catch {
        Write-Host "Failed to download modules manifest. Exiting." -ForegroundColor Red
        exit 1
    }

    # Download each module from the manifest.
    foreach ($moduleFile in $moduleList) {
        $moduleFileTrimmed = $moduleFile.Trim()
        $moduleURL = "https://raw.githubusercontent.com/TotalSecure-IT/jcorcoran-public/refs/heads/main/Poly.PKit/modules/$moduleFileTrimmed"
        $localModulePath = Join-Path $modulesFolder $moduleFileTrimmed
        try {
            Invoke-WebRequest -Uri $moduleURL -OutFile $localModulePath -UseBasicParsing
            Write-Host "Downloaded module: $moduleFileTrimmed" -ForegroundColor Cyan
        }
        catch {
            Write-Host "Failed to download module: $moduleFileTrimmed" -ForegroundColor Red
        }
    }
}
elseif ($mode -eq "CACHED") {
    Write-Host "Skipping module downloads in CACHED mode." -ForegroundColor Yellow
}

#------------------------------------------------------------------
# Import Required Modules
#------------------------------------------------------------------

# Logger Module
$loggerModulePath = Join-Path $modulesFolder "logger.psm1"
if (Test-Path -Path $loggerModulePath) {
    Import-Module $loggerModulePath -Force
}
else {
    Write-Host "Logger module not available. Continuing without logging functionality." -ForegroundColor Yellow
}

# ConfigLoader Module
$configLoaderModulePath = Join-Path $modulesFolder "ConfigLoader.psm1"
if (Test-Path -Path $configLoaderModulePath) {
    Import-Module $configLoaderModulePath -Force
}
else {
    Write-Host "ConfigLoader module not available. Exiting." -ForegroundColor Yellow
    Read-Host "Press Enter to exit..."
    exit 1
}

# OrgFolders Module (optional; used later)
$orgBannerModulePath = Join-Path $modulesFolder "OrgFolders.psm1"
# (We'll check for it later when calling its functionality)

#------------------------------------------------------------------
# Logging Initialization
#------------------------------------------------------------------
$hostName = $env:COMPUTERNAME
if (Get-Module -Name logger) {
    $logInfo = Initialize-Logger -workingDir $workingDir -hostName $hostName
    $hostLogFolder = $logInfo.HostLogFolder
    $primaryLogFilePath = $logInfo.PrimaryLogFilePath
    Write-Log -message "Primary log file created: $(Split-Path $primaryLogFilePath -Leaf)" -logFilePath $primaryLogFilePath
    Write-SystemLog -hostName $hostName -hostLogFolder $hostLogFolder -primaryLogFilePath $primaryLogFilePath
}
else {
    Write-Host "Logger module not loaded. Skipping logging initialization." -ForegroundColor Yellow
    $primaryLogFilePath = $null
    $hostLogFolder = $null
}

#------------------------------------------------------------------
# Configuration File Verification via ConfigLoader
#------------------------------------------------------------------
$config = Get-Config -workingDir $workingDir
$owner = $config.owner
$repo  = $config.repo
$token = $config.token

Write-Host "Configuration loaded:"
Write-Host "  owner: " -NoNewline
Write-Host "$owner" -ForegroundColor Green
Write-Host "  repo : " -NoNewline
Write-Host "$repo" -ForegroundColor Green
Write-Host "  token: " -NoNewline
Write-Host "$token" -ForegroundColor Green

#------------------------------------------------------------------
# Basic Folder Creation (configs, Orgs, and modules in working directory)
#------------------------------------------------------------------
# Verify 'configs' folder exists.
$configsPath = Join-Path $workingDir "configs"
if (-Not (Test-Path -Path $configsPath)) {
    Write-Host "Warning: 'configs' folder not found. It should exist prior to script launch." -ForegroundColor Yellow
    if ($primaryLogFilePath) { Write-Log -message "Warning: 'configs' folder not found." -logFilePath $primaryLogFilePath }
}
else {
    Write-Host "'configs' folder exists."
    if ($primaryLogFilePath) { Write-Log -message "'configs' folder exists." -logFilePath $primaryLogFilePath }
}

# Create 'Orgs' folder if needed.
$orgsPath = Join-Path $workingDir "Orgs"
if (-Not (Test-Path -Path $orgsPath)) {
    Write-Host "Creating folder 'Orgs'..."
    if ($primaryLogFilePath) { Write-Log -message "Creating folder 'Orgs'." -logFilePath $primaryLogFilePath }
    New-Item -ItemType Directory -Path $orgsPath | Out-Null
}
else {
    Write-Host "Folder 'Orgs' already exists."
    if ($primaryLogFilePath) { Write-Log -message "Folder 'Orgs' already exists." -logFilePath $primaryLogFilePath }
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


#------------------------------------------------------------------
# Additional Functionality: Organization Folders and Banner Download
#------------------------------------------------------------------
if (Test-Path -Path $orgBannerModulePath) {
    Import-Module $orgBannerModulePath -Force
    Write-Host "OrgFolders module imported." -ForegroundColor Cyan
    if ($primaryLogFilePath) { Write-Log -message "OrgFolders module imported." -logFilePath $primaryLogFilePath }
    
    Update-OrgFolders -workingDir $workingDir -mode $mode -owner $owner -repo $repo -token $token -primaryLogFilePath $primaryLogFilePath
}
else {
    Write-Host "OrgFolders module not found. Skipping additional organization and banner processing." -ForegroundColor Yellow
    if ($primaryLogFilePath) { Write-Log -message "OrgFolders module not found. Skipping additional org and banner processing." -logFilePath $primaryLogFilePath }
}