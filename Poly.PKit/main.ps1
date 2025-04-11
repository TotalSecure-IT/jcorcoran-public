# <#
# .SYNOPSIS
#   Poly.PKit v1.0.1b - ONLINE MODE
# .DESCRIPTION
#   Main script for Poly.PKit in ONLINE mode.
# 
# Note: The Write-Host calls are used intentionally for colored interactive output.
# Suppress the following Script Analyzer warnings:
#   PSAvoidUsingWriteHost
#   PSAvoidAssignmentToAutomaticVariables
# #>

Clear-Host
#$DebugPreference = "Continue"

#------------------------------------------------------------------
# Set Working Directories
#------------------------------------------------------------------
# Do not assign to the automatic variable $PSScriptRoot. Instead, define our own.
if ($MyInvocation.MyCommand.Path) {
    $MyScriptRoot = Split-Path $MyInvocation.MyCommand.Path -Parent
} else {
    $MyScriptRoot = (Get-Location).Path
}

# Assume main.ps1 is in the "init" folder; working directory is its parent.
$global:workingDir = Split-Path $MyScriptRoot -Parent
if ([string]::IsNullOrWhiteSpace($global:workingDir)) {
    $global:workingDir = (Get-Location).Path
}

Write-Host "Working Directory set to: $global:workingDir" -ForegroundColor Green

# 'init' folder is where main.ps1 resides.
$initDir = $MyScriptRoot

# Modules folder is inside the init directory.
$modulesFolder = Join-Path $initDir "modules"
if (-not (Test-Path -Path $modulesFolder)) {
    New-Item -ItemType Directory -Path $modulesFolder | Out-Null
}

#------------------------------------------------------------------
# Simulate ONLINE mode
#------------------------------------------------------------------
Write-Host "Mode:" -NoNewline; Write-Host " ONLINE" -ForegroundColor Green

#------------------------------------------------------------------
# Download Modules Manifest and Modules from GitHub
#------------------------------------------------------------------
$modulesManifestURL = "https://raw.githubusercontent.com/TotalSecure-IT/jcorcoran-public/refs/heads/main/Poly.PKit/modules/modules_manifest.txt"
try {
    Write-Host "Downloading modules manifest from GitHub..."
    $manifestResponse = Invoke-WebRequest -Uri $modulesManifestURL -UseBasicParsing
    $moduleList = $manifestResponse.Content -split "\r?\n" | Where-Object { $_.Trim() -ne "" }
}
catch {
    Write-Host "Failed to download modules manifest. Exiting." -ForegroundColor Red
    exit 1
}

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

#------------------------------------------------------------------
# Import Required Modules
#------------------------------------------------------------------
# Logger Module
$loggerModulePath = Join-Path $modulesFolder "logger.psm1"
if (Test-Path -Path $loggerModulePath) {
    Import-Module $loggerModulePath -Force
} else {
    Write-Host "Logger module not available. Continuing without logging functionality." -ForegroundColor Yellow
}

# ConfigLoader Module
$configLoaderModulePath = Join-Path $modulesFolder "ConfigLoader.psm1"
if (Test-Path -Path $configLoaderModulePath) {
    Import-Module $configLoaderModulePath -Force
} else {
    Write-Host "ConfigLoader module not available. Exiting." -ForegroundColor Yellow
    exit 1
}

# OrgFolders Module
$orgFoldersModulePath = Join-Path $modulesFolder "OrgFolders.psm1"
if (Test-Path -Path $orgFoldersModulePath) {
    Import-Module $orgFoldersModulePath -Force
} else {
    Write-Host "OrgFolders module not available. Exiting." -ForegroundColor Yellow
    exit 1
}

# MenuConstructor Module
$menuConstructorModulePath = Join-Path $modulesFolder "MenuConstructor.psm1"
if (Test-Path -Path $menuConstructorModulePath) {
    Import-Module $menuConstructorModulePath -Force
} else {
    Write-Host "MenuConstructor module not available. Exiting." -ForegroundColor Yellow
    exit 1
}

# Onboarding Module
$onboardingModulePath = Join-Path $modulesFolder "Onboarding.psm1"
if (Test-Path $onboardingModulePath) {
    Import-Module $onboardingModulePath -Force
} else {
    Write-Host "Onboarding.psm1 not found. Onboarding functionality will be unavailable." -ForegroundColor Yellow
}

#------------------------------------------------------------------
# Logging Initialization
#------------------------------------------------------------------
$hostName = $env:COMPUTERNAME
if (Get-Module -Name logger) {
    $logInfo = Initialize-Logger -workingDir $global:workingDir -hostName $hostName
    $Global:JsonLogFilePath = $logInfo.JsonLogFilePath
    $hostLogFolder = $logInfo.HostLogFolder
    $primaryLogFilePath = $logInfo.PrimaryLogFilePath
    Write-Log -Message "Primary log file created: $(Split-Path $primaryLogFilePath -Leaf)" -logFilePath $primaryLogFilePath
    Write-SystemLog -hostName $hostName -hostLogFolder $hostLogFolder -primaryLogFilePath $primaryLogFilePath
} else {
    Write-Host "Logger module not loaded. Skipping logging initialization." -ForegroundColor Yellow
    $primaryLogFilePath = $null
    $hostLogFolder = $null
}

#------------------------------------------------------------------
# Configuration File Verification via ConfigLoader
#------------------------------------------------------------------
$config = Get-Config -workingDir $global:workingDir
$owner = $config.owner
$repo  = $config.repo
$token = $config.token

Write-Host "Configuration loaded:"
Write-Host "  owner: " -NoNewline; Write-Host "$owner" -ForegroundColor Green
Write-Host "  repo : " -NoNewline; Write-Host "$repo" -ForegroundColor Green
Write-Host "  token: " -NoNewline; Write-Host "$token" -ForegroundColor Green

#------------------------------------------------------------------
# Basic Folder Creation (configs, orgs, and modules)
#------------------------------------------------------------------
$configsPath = Join-Path $global:workingDir "configs"
if (-Not (Test-Path -Path $configsPath)) {
    Write-Host "Warning: 'configs' folder not found. It should exist prior to script launch." -ForegroundColor Yellow
    if ($primaryLogFilePath) { Write-Log -Message "Warning: 'configs' folder not found." -logFilePath $primaryLogFilePath }
} else {
    Write-Host "'configs' folder exists."
    if ($primaryLogFilePath) { Write-Log -Message "'configs' folder exists." -logFilePath $primaryLogFilePath }
}

$orgsPath = Join-Path $global:workingDir "orgs"
if (-Not (Test-Path -Path $orgsPath)) {
    Write-Host "Creating folder 'orgs'..."
    if ($primaryLogFilePath) { Write-Log -Message "Creating folder 'orgs'." -logFilePath $primaryLogFilePath }
    New-Item -ItemType Directory -Path $orgsPath | Out-Null
} else {
    Write-Host "Folder 'orgs' already exists."
    if ($primaryLogFilePath) { Write-Log -Message "Folder 'orgs' already exists." -logFilePath $primaryLogFilePath }
}

#------------------------------------------------------------------
# Download Banner Files to 'configs' Folder
#------------------------------------------------------------------
$configsPath = Join-Path $global:workingDir "configs"
$mainbannerURL = "https://raw.githubusercontent.com/TotalSecure-IT/jcorcoran-public/refs/heads/main/Poly.PKit/configs/mainbanner.txt"
$motdURL = "https://raw.githubusercontent.com/TotalSecure-IT/jcorcoran-public/refs/heads/main/Poly.PKit/configs/motd.txt"
try {
    Invoke-WebRequest -Uri $mainbannerURL -OutFile (Join-Path $configsPath "mainbanner.txt") -UseBasicParsing
    Write-Host "Downloaded mainbanner.txt from GitHub." -ForegroundColor Cyan
    if ($primaryLogFilePath) {
        Write-Log -Message "Downloaded mainbanner.txt from GitHub." -logFilePath $primaryLogFilePath
    }
}
catch {
    Write-Host "Failed to download mainbanner.txt from GitHub." -ForegroundColor Red
    if ($primaryLogFilePath) {
        Write-Log -Message "Failed to download mainbanner.txt from GitHub." -logFilePath $primaryLogFilePath
    }
}

try {
    Invoke-WebRequest -Uri $motdURL -OutFile (Join-Path $configsPath "motd.txt") -UseBasicParsing
    Write-Host "Downloaded motd.txt from GitHub." -ForegroundColor Cyan
    if ($primaryLogFilePath) {
        Write-Log -Message "Downloaded motd.txt from GitHub." -logFilePath $primaryLogFilePath
    }
}
catch {
    Write-Host "Failed to download motd.txt from GitHub." -ForegroundColor Red
    if ($primaryLogFilePath) {
        Write-Log -Message "Failed to download motd.txt from GitHub." -logFilePath $primaryLogFilePath
    }
}

#------------------------------------------------------------------
# Additional Functionality: Organization Folders
#------------------------------------------------------------------
if (Test-Path -Path $orgFoldersModulePath) {
    Import-Module $orgFoldersModulePath -Force
    Write-Host "OrgFolders module imported." -ForegroundColor Cyan
    if ($primaryLogFilePath) { 
        Write-Log -Message "OrgFolders module imported." -logFilePath $primaryLogFilePath 
    }
    Update-OrgFolders -workingDir $global:workingDir -mode "ONLINE" -owner "TotalSecure-IT" -repo "jcorcoran-public" -token $token -orgsFolderSha "8b8cde2fe87d2155653ddbdaa7530e01b84047bf" -primaryLogFilePath $primaryLogFilePath
} else {
    Write-Host "OrgFolders module not found. Skipping organization processing." -ForegroundColor Yellow
    if ($primaryLogFilePath) { 
        Write-Log -Message "OrgFolders module not found. Skipping organization processing." -logFilePath $primaryLogFilePath 
    }
}

Start-Sleep -Seconds 1
Clear-Host

# Call the main menu loop:
Show-MainMenuLoop -workingDir $global:workingDir
