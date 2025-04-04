# ========================================================
# Universal Onboarding Script Main Module
# Run this script with: powershell.exe -ExecutionPolicy Bypass -File .\UniversalOnboarding.ps1
# ========================================================

# ----------------------------
# Customization Settings
# ----------------------------
# Colors: (Note that Write-Host supports a set of named colors; you can modify or translate these to ANSI as needed)
$BannerColor = "Yellow"              # Color for the banner text
$MenuHighlightBackground = "Red"      # Background for the highlighted menu item
$MenuHighlightForeground = "White"    # Text color for the highlighted menu item
$MenuDefaultForeground = "Gray"       # Default text color for menu items

# Starting positions (line numbers in the console)
$BannerStartRow = 0
$MessageBodyStartRow = 5
$MenuStartRow = 7

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
# Download Company-Specific Components (Placeholder)
# ----------------------------
function Download-CompanyComponents {
    Write-Host "Downloading company-specific components from GitHub..." -ForegroundColor Cyan
    # Example placeholder:
    # $url = "https://raw.githubusercontent.com/YourRepo/CompanyScript.ps1"
    # $destination = Join-Path $BaseDir "Company_Scripts\CompanyScript.ps1"
    # Invoke-WebRequest -Uri $url -OutFile $destination -UseBasicParsing
}
Download-CompanyComponents

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

    # Clear screen and set positions
    Clear-Host

    # Position and display the banner
    [console]::SetCursorPosition(0, $BannerStartRow)
    Write-Host $bannerContent -ForegroundColor $BannerColor

    # Display the message body (instructions)
    [console]::SetCursorPosition(0, $MessageBodyStartRow)
    Write-Host "Please select one of the available options below:" -ForegroundColor $MenuDefaultForeground

    # Define menu items and sort them alphabetically
    $menuItems = @("Child Care Aware", "Watson Electric", "OCCK", "Quit") | Sort-Object

    $selectedIndex = 0
    $exitMenu = $false

    while (-not $exitMenu) {
        # Render menu items starting at the defined row
        for ($i = 0; $i -lt $menuItems.Count; $i++) {
            [console]::SetCursorPosition(0, $MenuStartRow + $i)
            if ($i -eq $selectedIndex) {
                # Highlight the selected item (full-width bar using PadRight)
                Write-Host ($menuItems[$i].PadRight([console]::WindowWidth)) -ForegroundColor $MenuHighlightForeground -BackgroundColor $MenuHighlightBackground -NoNewline
                Write-Host ""
            }
            else {
                Write-Host ($menuItems[$i].PadRight([console]::WindowWidth)) -ForegroundColor $MenuDefaultForeground -BackgroundColor "Black" -NoNewline
                Write-Host ""
            }
        }

        # Capture user key input
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
# Main Script Execution
# ----------------------------
$selectedOption = Show-InteractiveMenu
Write-Host "You selected: $selectedOption" -ForegroundColor Green

# Launch the corresponding module or script based on selection
switch ($selectedOption) {
    "Child Care Aware" {
         Write-Host "Launching Child Care Aware onboarding..." -ForegroundColor Cyan
         # Example: & ".\Company_Scripts\ChildCareAware.ps1"
    }
    "OCCK" {
         Write-Host "Launching OCCK onboarding..." -ForegroundColor Cyan
         # Example: & ".\Company_Scripts\OCCK.ps1"
    }
    "Quit" {
         Write-Host "Exiting script. Goodbye!" -ForegroundColor Cyan
         exit
    }
    "Watson Electric" {
         Write-Host "Launching Watson Electric onboarding..." -ForegroundColor Cyan
         # Example: & ".\Company_Scripts\WatsonElectric.ps1"
    }
    default {
         Write-Host "Invalid option. Exiting." -ForegroundColor Red
         exit
    }
}
