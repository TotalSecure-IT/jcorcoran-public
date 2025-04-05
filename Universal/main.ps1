param(
    [string]$UsbRoot
)

# Remove any extraneous quotes from the passed USB root path.
$UsbRoot = $UsbRoot.Trim('"')

# Define the main log file path in the USB root.
$mainLogFile = Join-Path $UsbRoot ("{0}-main-log.log" -f (Get-Date -Format "yyyyMMdd_HHmmss"))

# Function to write timestamped entries to the main log.
function Write-MainLog {
    param(
        [string]$Message
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $mainLogFile -Value "$timestamp - $Message"
}

Write-MainLog "Main script started."

# ========================================================
# Universal Onboarding Script Main Module
# Run this script with: powershell.exe -ExecutionPolicy Bypass -File .\UniversalOnboarding.ps1
# ========================================================

# ----------------------------
# Customization Settings
# ----------------------------
$BannerColor = "Yellow"              # Color for the banner text
$MenuHighlightBackground = "Red"      # Background for the highlighted menu item
$MenuHighlightForeground = "White"    # Text color for the highlighted menu item
$MenuDefaultForeground = "Gray"       # Default text color for menu items

# Starting positions (line numbers in the console)
$BannerStartRow = 0
$MessageBodyStartRow = 7
$MenuStartRow = 20

# ----------------------------
# Admin Privilege Check
# ----------------------------
function Test-Admin {
    $currentUser = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $currentUser.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
}

if (-not (Test-Admin)) {
    Write-Host "This script must be run as Administrator. Please restart the script as an admin." -ForegroundColor Red
    Write-MainLog "Script not run as Administrator. Exiting."
    Write-Host "Press any key to exit..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit
}

# ----------------------------
# Environment Checks (Winget & PowerShell 7)
# ----------------------------
function Check-Environment {
    # Check for Winget
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Host "Winget is not installed. Installing winget..." -ForegroundColor Cyan
        Write-MainLog "Winget not found; initiating installation."
        # Insert silent installation code for winget here.
    }
    else {
        Write-Host "Winget is installed. Checking for upgrades..." -ForegroundColor Cyan
        Write-MainLog "Winget found; checking for upgrades."
        # Insert code to upgrade winget if an update is available.
    }

    # Check for PowerShell 7
    if (-not (Get-Command pwsh -ErrorAction SilentlyContinue)) {
        Write-Host "PowerShell 7 is not installed. Installing PowerShell 7..." -ForegroundColor Cyan
        Write-MainLog "PowerShell 7 not found; initiating installation."
        # Insert installation code for PowerShell 7 here.
    }
}
Check-Environment

# ----------------------------
# Create Required Folder Structure
# ----------------------------
$BaseDir = "C:\TotalSecureUOBS"
$Folders = @("Company_Banners", "Company_Scripts", "Installers")

if (-not (Test-Path $BaseDir)) {
    New-Item -Path $BaseDir -ItemType Directory -Force | Out-Null
    Write-MainLog "Created base directory: $BaseDir."
}
foreach ($folder in $Folders) {
    $folderPath = Join-Path $BaseDir $folder
    if (-not (Test-Path $folderPath)) {
        New-Item -Path $folderPath -ItemType Directory -Force | Out-Null
        Write-MainLog "Created folder: $folderPath."
    }
}

# Set the working directory to C:\TotalSecureUOBS regardless of launch location
Set-Location $BaseDir
Write-MainLog "Set working directory to $BaseDir."

# ----------------------------
# Global Component Downloads (if any)
# ----------------------------
function Download-GlobalComponents {
    Write-Host "Downloading global components from GitHub..." -ForegroundColor Cyan
    Write-MainLog "Downloading global components from GitHub."

    $companiesUrl = "https://raw.githubusercontent.com/TotalSecure-IT/jcorcoran-public/refs/heads/main/Universal/companies.txt"
    $mainBannerUrl = "https://raw.githubusercontent.com/TotalSecure-IT/jcorcoran-public/refs/heads/main/Universal/mainbanner.txt"

    $destCompanies = Join-Path $UsbRoot "companies.txt"
    $destBanner = Join-Path $UsbRoot "mainbanner.txt"

    try {
        Invoke-WebRequest -Uri $companiesUrl -OutFile $destCompanies -UseBasicParsing -ErrorAction Stop
        Write-Host "Downloaded companies.txt to $destCompanies" -ForegroundColor Green
        Write-MainLog "Downloaded companies.txt to $destCompanies."
    }
    catch {
        Write-Host "Error downloading companies.txt: $_" -ForegroundColor Red
        Write-MainLog "Error downloading companies.txt: $_"
    }

    try {
        Invoke-WebRequest -Uri $mainBannerUrl -OutFile $destBanner -UseBasicParsing -ErrorAction Stop
        Write-Host "Downloaded mainbanner.txt to $destBanner" -ForegroundColor Green
        Write-MainLog "Downloaded mainbanner.txt to $destBanner."
    }
    catch {
        Write-Host "Error downloading mainbanner.txt: $_" -ForegroundColor Red
        Write-MainLog "Error downloading mainbanner.txt: $_"
    }
}
Download-GlobalComponents

# ----------------------------
# Interactive Menu Function
# ----------------------------
function Show-InteractiveMenu {
    # Read banner from file in USB root
    $bannerFile = Join-Path $UsbRoot "mainbanner.txt"
    if (Test-Path $bannerFile) {
        $bannerContent = Get-Content $bannerFile -Raw
    }
    else {
        $bannerContent = "== Universal Onboarding Script =="
    }
    
    # Build menu items from companies.txt in USB root
    $companiesFile = Join-Path $UsbRoot "companies.txt"
    if (-not (Test-Path $companiesFile)) {
        Write-Host "Error: companies.txt file not found in $UsbRoot. Exiting." -ForegroundColor Red
        Write-MainLog "companies.txt not found in $UsbRoot. Exiting script."
        Write-Host "Press any key to exit..."
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        exit
    }
    $companies = Get-Content $companiesFile | Where-Object { $_.Trim() -ne "" } | Sort-Object
    $menuItems = $companies + "Quit"

    # Clear screen and display banner and instructions
    Clear-Host
    [console]::SetCursorPosition(0, $BannerStartRow)
    Write-Host $bannerContent -ForegroundColor $BannerColor

    [console]::SetCursorPosition(0, $MessageBodyStartRow)
    Write-Host "Please select one of the available options below:" -ForegroundColor $MenuDefaultForeground

    $selectedIndex = 0
    $exitMenu = $false

    while (-not $exitMenu) {
        for ($i = 0; $i -lt $menuItems.Count; $i++) {
            $consoleWidth = [console]::WindowWidth
            $menuItemText = $menuItems[$i]
            $leftPadding = [math]::Floor(($consoleWidth - $menuItemText.Length) / 2)
            $centeredText = (" " * $leftPadding) + $menuItemText
            $centeredText = $centeredText.PadRight($consoleWidth)
            
            [console]::SetCursorPosition(0, $MenuStartRow + $i)
            if ($i -eq $selectedIndex) {
                Write-Host $centeredText -ForegroundColor $MenuHighlightForeground -BackgroundColor $MenuHighlightBackground -NoNewline
                Write-Host ""
            }
            else {
                Write-Host $centeredText -ForegroundColor $MenuDefaultForeground -BackgroundColor "Black" -NoNewline
                Write-Host ""
            }
        }
        $key = [console]::ReadKey($true)
        switch ($key.Key) {
            'UpArrow' {
                if ($selectedIndex -eq 0) {
                    $selectedIndex = $menuItems.Count - 1
                }
                else {
                    $selectedIndex--
                }
            }
            'DownArrow' {
                if ($selectedIndex -eq ($menuItems.Count - 1)) {
                    $selectedIndex = 0
                }
                else {
                    $selectedIndex++
                }
            }
            'Enter' {
                $exitMenu = $true
            }
        }
    }
    return $menuItems[$selectedIndex]
}

# ----------------------------
# Download File Helper with Error Handling
# ----------------------------
function Download-File {
    param(
        [string]$url,
        [string]$destination
    )
    try {
         Invoke-WebRequest -Uri $url -OutFile $destination -UseBasicParsing -ErrorAction Stop
         Write-Host "Downloaded file: $destination" -ForegroundColor Green
         Write-MainLog "Downloaded file: $destination"
    }
    catch {
         Write-Host "Error downloading file from $url to $destination`nError details: $_" -ForegroundColor Red
         Write-MainLog "Error downloading file from $url to $destination. Details: $_"
         throw $_
    }
}

# ----------------------------
# Company-Specific Setup Function (Using Manifest)
# ----------------------------
function Setup-Company {
    param(
        [string]$companyName
    )

    # Convert company name to a folder-friendly name (spaces replaced with hyphens)
    $companyFolderName = $companyName -replace '\s+', '-'

    # Create company-specific directories under Company_Banners and Company_Scripts
    $companyBannerDir = Join-Path "$BaseDir\Company_Banners" $companyFolderName
    $companyScriptsDir = Join-Path "$BaseDir\Company_Scripts" $companyFolderName

    try {
        if (-not (Test-Path $companyBannerDir)) {
             New-Item -Path $companyBannerDir -ItemType Directory -Force | Out-Null
             Write-MainLog "Created company banner directory: $companyBannerDir."
        }
        if (-not (Test-Path $companyScriptsDir)) {
             New-Item -Path $companyScriptsDir -ItemType Directory -Force | Out-Null
             Write-MainLog "Created company scripts directory: $companyScriptsDir."
        }
    }
    catch {
        throw "Error creating company directories: $_"
    }

    # Construct manifest URL using the adjusted company name
    $manifestUrl = "https://raw.githubusercontent.com/TotalSecure-IT/jcorcoran-public/refs/heads/main/Universal/$companyFolderName/manifest.txt"
    Write-MainLog "Using manifest URL: $manifestUrl"

    # Download manifest file to a temporary location
    $tempManifestFile = Join-Path $env:TEMP "manifest_$companyFolderName.txt"
    try {
         Download-File -url $manifestUrl -destination $tempManifestFile
    }
    catch {
         throw "Error downloading manifest file from $manifestUrl $_"
    }

    # Parse manifest file (each line should be: filename = "url")
    $manifestContent = Get-Content $tempManifestFile -Raw
    $manifestLines = $manifestContent -split "`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }

    # Initialize an array to collect any download errors
    $downloadErrors = @()

    foreach ($line in $manifestLines) {
         if ($line -match '^(.*?)\s*=\s*"(.*?)"$') {
             $fileName = $matches[1].Trim()
             $fileUrl = $matches[2].Trim()
         }
         else {
             $downloadErrors += "Invalid manifest line format: $line"
             continue
         }
         
         # Determine destination based on the file name
         switch ($fileName.ToLower()) {
             "banner.txt" {
                $destPath = Join-Path $companyBannerDir "banner.txt"
             }
             "appslist.json" {
                $destPath = Join-Path $companyScriptsDir "appslist.json"
             }
             "deploy.ps1" {
                $destPath = Join-Path $companyScriptsDir "deploy.ps1"
             }
             default {
                Write-Host "Skipping unrecognized file in manifest: $fileName" -ForegroundColor Yellow
                Write-MainLog "Skipping unrecognized file in manifest: $fileName"
                continue
             }
         }
         try {
             Download-File -url $fileUrl -destination $destPath
         }
         catch {
             $downloadErrors += "Error downloading $fileName from $fileUrl $_"
         }
    }
    
    # Summarize any download errors and prompt the user to acknowledge before proceeding
    if ($downloadErrors.Count -gt 0) {
         Write-Host "The following errors were encountered while downloading files from the manifest:" -ForegroundColor Red
         Write-MainLog "Encountered errors during manifest downloads:"
         foreach ($err in $downloadErrors) {
             Write-Host $err -ForegroundColor Red
             Write-MainLog $err
         }
         Write-Host "Press any key to continue..."
         $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    }
    
    # Remove the temporary manifest file
    Remove-Item $tempManifestFile -Force
    Write-MainLog "Removed temporary manifest file: $tempManifestFile."

    # Return a hashtable with paths (deploy.ps1 is needed for launching)
    return @{
         "BannerDir"  = $companyBannerDir
         "ScriptsDir" = $companyScriptsDir
         "DeployPS1"  = Join-Path $companyScriptsDir "deploy.ps1"
         "FolderName" = $companyFolderName
    }
}

# ----------------------------
# Cleanup Function for Company Folders
# ----------------------------
function Cleanup-CompanyFolders {
    param(
        [string]$bannerDir,
        [string]$scriptsDir
    )
    try {
         if (Test-Path $bannerDir) {
            Remove-Item -Path $bannerDir -Recurse -Force
            Write-MainLog "Cleaned up banner directory: $bannerDir."
         }
         if (Test-Path $scriptsDir) {
            Remove-Item -Path $scriptsDir -Recurse -Force
            Write-MainLog "Cleaned up scripts directory: $scriptsDir."
         }
    }
    catch {
         Write-Host "Error cleaning up company folders: $_" -ForegroundColor Red
         Write-MainLog "Error cleaning up company folders: $_"
    }
}

# ----------------------------
# Main Execution Loop for Company Selection, Setup & Confirmation
# ----------------------------
$confirmed = $false
while (-not $confirmed) {

    # Main Execution Loop for Company Selection & Setup
    while ($true) {
        $selectedOption = Show-InteractiveMenu
        if ($selectedOption -eq "Quit") {
             Write-Host "Exiting script. Goodbye!" -ForegroundColor Cyan
             Write-MainLog "User selected Quit. Exiting script."
             exit
        }
        try {
            # Attempt to set up the company-specific files and directories via the manifest.
            $companySetup = Setup-Company -companyName $selectedOption
            break
        }
        catch {
            # Clean up and return to the interactive menu if setup fails.
            $companyFolderName = $selectedOption -replace '\s+', '-'
            $bannerDir = Join-Path "$BaseDir\Company_Banners" $companyFolderName
            $scriptsDir = Join-Path "$BaseDir\Company_Scripts" $companyFolderName
            Cleanup-CompanyFolders -bannerDir $bannerDir -scriptsDir $scriptsDir
            Write-Host "An error occurred during company setup: $_" -ForegroundColor Red
            Write-MainLog "Error during company setup for $selectedOption $_"
            Write-Host "Press any key to return to the main menu..."
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            # Loop will restart and show the interactive menu again.
        }
    }

    # ----------------------------
    # Confirm Deployment Prompt
    # ----------------------------
    $confirmed = $null
    do {
        $userInput = Read-Host "Are you sure you want to deploy the $selectedOption script? (y/n)"
        if ($userInput.ToLower() -eq "y") {
            $confirmed = $true
        }
        elseif ($userInput.ToLower() -eq "n") {
            $confirmed = $false
        }
        else {
            Write-Host "Please enter 'y' or 'n'."
        }
    } while ($confirmed -eq $null)

    if (-not $confirmed) {
        # Clean up the already created company folders and return to the main menu.
        $companyFolderName = $selectedOption -replace '\s+', '-'
        $bannerDir = Join-Path "$BaseDir\Company_Banners" $companyFolderName
        $scriptsDir = Join-Path "$BaseDir\Company_Scripts" $companyFolderName
        Cleanup-CompanyFolders -bannerDir $bannerDir -scriptsDir $scriptsDir
        Write-Host "Returning to the main menu..." -ForegroundColor Cyan
        Write-MainLog "User cancelled deployment for $selectedOption. Returning to menu."
        Write-Host "Press any key to continue..."
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        # Outer loop will restart.
    }
}

# ----------------------------
# Launch Company-Specific Script
# ----------------------------

# Determine the config path on the USB drive.
$configPath = Join-Path $UsbRoot "configs"

Clear-Host
try {
    Write-Host "Launching $selectedOption onboarding script..." -ForegroundColor Cyan
    Write-Host "Using script file: $($companySetup.DeployPS1)" -ForegroundColor Cyan
    Write-MainLog "Launching deploy script for $selectedOption."
    # Use the call operator (&) to execute the deploy script with the ConfigPath parameter.
    & $companySetup.DeployPS1 -ConfigPath (Join-Path $configPath $companySetup.FolderName) -CompanyFolderName $companySetup.FolderName

}
catch {
    Write-Host "Error launching company script: $_" -ForegroundColor Red
    Write-MainLog "Error launching company script for $selectedOption $_"
    Write-Host "Press any key to exit..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit
}

Write-MainLog "Main script finished."
