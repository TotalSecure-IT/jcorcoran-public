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
        # Insert silent installation code for winget here.
    }
    else {
        Write-Host "Winget is installed. Checking for upgrades..." -ForegroundColor Cyan
        # Insert code to upgrade winget if an update is available.
    }

    # Check for PowerShell 7
    if (-not (Get-Command pwsh -ErrorAction SilentlyContinue)) {
        Write-Host "PowerShell 7 is not installed. Installing PowerShell 7..." -ForegroundColor Cyan
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
}
foreach ($folder in $Folders) {
    $folderPath = Join-Path $BaseDir $folder
    if (-not (Test-Path $folderPath)) {
        New-Item -Path $folderPath -ItemType Directory -Force | Out-Null
    }
}

# Set the working directory to C:\TotalSecureUOBS regardless of launch location
Set-Location $BaseDir

# ----------------------------
# Global Component Downloads (if any)
# ----------------------------
function Download-GlobalComponents {
    Write-Host "Downloading global components from GitHub..." -ForegroundColor Cyan
    # Placeholder for any non-company-specific downloads.
}
Download-GlobalComponents

# ----------------------------
# Interactive Menu Function
# ----------------------------
function Show-InteractiveMenu {
    # Read banner from file (mainbanner.txt)
    $bannerFile = ".\mainbanner.txt"
    if (Test-Path $bannerFile) {
        $bannerContent = Get-Content $bannerFile -Raw
    }
    else {
        $bannerContent = "== Universal Onboarding Script =="
    }
    
    # Build menu items from companies.txt (one company per line)
    $companiesFile = ".\companies.txt"
    if (Test-Path $companiesFile) {
        $companies = Get-Content $companiesFile | Where-Object { $_.Trim() -ne "" }
        $companies = $companies | Sort-Object
    }
    else {
        # Fallback default companies if companies.txt is missing
        $companies = @("Child Care Aware", "OCCK", "Watson Electric") | Sort-Object
    }
    # Append "Quit" (this remains unsorted and always appears at the bottom)
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
                if ($selectedIndex -gt 0) { $selectedIndex-- }
            }
            'DownArrow' {
                if ($selectedIndex -lt $menuItems.Count - 1) { $selectedIndex++ }
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
    }
    catch {
         Write-Host "Error downloading file from $url to $destination`nError details: $_" -ForegroundColor Red
         throw $_
    }
}

# ----------------------------
# Company-Specific Setup Function
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
        }
        if (-not (Test-Path $companyScriptsDir)) {
             New-Item -Path $companyScriptsDir -ItemType Directory -Force | Out-Null
        }
    }
    catch {
        throw "Error creating company directories: $_"
    }

    # Define file paths for the three company-specific files
    $companyBannerFile = Join-Path $companyBannerDir "banner.txt"
    $companyDeployBat = Join-Path $companyScriptsDir ("$companyFolderName-deploy.bat")
    $companyDeployPS1 = Join-Path $companyScriptsDir ("$companyFolderName-deploy.ps1")

    # Placeholder URLs for the company-specific files (update with actual GitHub links later)
    $bannerUrl = "https://raw.githubusercontent.com/YourRepo/Placeholder/banner.txt"
    $deployBatUrl = "https://raw.githubusercontent.com/YourRepo/Placeholder/$companyFolderName-deploy.bat"
    $deployPS1Url = "https://raw.githubusercontent.com/YourRepo/Placeholder/$companyFolderName-deploy.ps1"

    # Download the files; any error here will be thrown
    Download-File -url $bannerUrl -destination $companyBannerFile
    Download-File -url $deployBatUrl -destination $companyDeployBat
    Download-File -url $deployPS1Url -destination $companyDeployPS1

    # Return a hashtable with the created file paths and directories for later use
    return @{
         "BannerDir"  = $companyBannerDir
         "ScriptsDir" = $companyScriptsDir
         "BannerFile" = $companyBannerFile
         "DeployBat"  = $companyDeployBat
         "DeployPS1"  = $companyDeployPS1
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
         }
         if (Test-Path $scriptsDir) {
            Remove-Item -Path $scriptsDir -Recurse -Force
         }
    }
    catch {
         Write-Host "Error cleaning up company folders: $_" -ForegroundColor Red
    }
}

# ----------------------------
# Main Execution Loop for Company Selection & Setup
# ----------------------------
while ($true) {
    $selectedOption = Show-InteractiveMenu

    if ($selectedOption -eq "Quit") {
         Write-Host "Exiting script. Goodbye!" -ForegroundColor Cyan
         exit
    }

    try {
         # Attempt to set up the company-specific files and directories.
         $companySetup = Setup-Company -companyName $selectedOption
         # If no errors occurred, break out of the loop.
         break
    }
    catch {
         # If any error occurs, clean up and return to the menu.
         $companyFolderName = $selectedOption -replace '\s+', '-'
         $bannerDir = Join-Path "$BaseDir\Company_Banners" $companyFolderName
         $scriptsDir = Join-Path "$BaseDir\Company_Scripts" $companyFolderName
         Cleanup-CompanyFolders -bannerDir $bannerDir -scriptsDir $scriptsDir
         Write-Host "An error occurred during company setup: $_" -ForegroundColor Red
         Write-Host "Press any key to return to the main menu..."
         $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
         # Loop will restart and show the interactive menu again.
    }
}

# ----------------------------
# Prompt for Additional User Input
# ----------------------------
Write-Host "Please answer the following questions before proceeding:" -ForegroundColor Cyan
$deploymentParam1 = Read-Host "Enter deployment parameter 1"
$deploymentParam2 = Read-Host "Enter deployment parameter 2"
$deploymentConfig = @{
    "Param1" = $deploymentParam1
    "Param2" = $deploymentParam2
}

# ----------------------------
# Launch Company-Specific Script
# ----------------------------
Clear-Host
try {
    Write-Host "Launching $selectedOption onboarding script..." -ForegroundColor Cyan
    Write-Host "Using script file: $($companySetup.DeployPS1)" -ForegroundColor Cyan
    # Dot-source the company-specific PowerShell script so it runs within the same session.
    . $companySetup.DeployPS1
}
catch {
    Write-Host "Error launching company script: $_" -ForegroundColor Red
    Write-Host "Press any key to exit..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit
}
