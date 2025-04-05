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
# Run this script with: powershell.exe -ExecutionPolicy Bypass -File .\main.ps1
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

    $mainMenuUrl = "https://raw.githubusercontent.com/TotalSecure-IT/jcorcoran-public/refs/heads/main/Universal/mainmenu.txt"
    $mainBannerUrl = "https://raw.githubusercontent.com/TotalSecure-IT/jcorcoran-public/refs/heads/main/Universal/mainbanner.txt"
    $motdUrl = "https://raw.githubusercontent.com/TotalSecure-IT/jcorcoran-public/refs/heads/main/Universal/motd.txt"

    $destMainMenu = Join-Path $UsbRoot "mainmenu.txt"
    $destBanner = Join-Path $UsbRoot "mainbanner.txt"
    $destMotd = Join-Path $UsbRoot "motd.txt"

    try {
        Invoke-WebRequest -Uri $mainMenuUrl -OutFile $destMainMenu -UseBasicParsing -ErrorAction Stop
        Write-Host "Downloaded mainmenu.txt to $destMainMenu" -ForegroundColor Green
        Write-MainLog "Downloaded mainmenu.txt to $destMainMenu."
    }
    catch {
        Write-Host "Error downloading mainmenu.txt: $_" -ForegroundColor Red
        Write-MainLog "Error downloading mainmenu.txt: $_"
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

    try {
        Invoke-WebRequest -Uri $motdUrl -OutFile $destMotd -UseBasicParsing -ErrorAction Stop
        Write-Host "Downloaded motd.txt to $destMotd" -ForegroundColor Green
        Write-MainLog "Downloaded motd.txt to $destMotd."
    }
    catch {
        Write-Host "Error downloading motd.txt: $_" -ForegroundColor Red
        Write-MainLog "Error downloading motd.txt: $_"
    }
}
Download-GlobalComponents

# ----------------------------
# Main Menu Function (from mainmenu.txt)
# ----------------------------
function Show-MainMenu {
    $mainMenuFile = Join-Path $UsbRoot "mainmenu.txt"
    if (-not (Test-Path $mainMenuFile)) {
        Write-Host "Error: mainmenu.txt file not found in $UsbRoot. Exiting." -ForegroundColor Red
        Write-MainLog "mainmenu.txt not found in $UsbRoot. Exiting script."
        Write-Host "Press any key to exit..."
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        exit
    }
    $menuItems = Get-Content $mainMenuFile | Where-Object { $_.Trim() -ne "" }
    # Main menu items are hyphenated (for aesthetic purposes)
    Clear-Host
    $bannerFile = Join-Path $UsbRoot "mainbanner.txt"
    if (Test-Path $bannerFile) {
        $bannerContent = Get-Content $bannerFile -Raw
    } else {
        $bannerContent = "== Universal Onboarding Script =="
    }
    [console]::SetCursorPosition(0, $BannerStartRow)
    Write-Host $bannerContent -ForegroundColor $BannerColor
    # Use motd.txt for message body.
    $motdFile = Join-Path $UsbRoot "motd.txt"
    if (Test-Path $motdFile) {
        $motdContent = Get-Content $motdFile -Raw
    } else {
        $motdContent = "Welcome. Please select an option below:"
    }
    [console]::SetCursorPosition(0, $MessageBodyStartRow)
    Write-Host $motdContent -ForegroundColor $MenuDefaultForeground

    # Main menu items remain hyphenated.
    $selectedIndex = 0
    $exitMenu = $false
    while (-not $exitMenu) {
        for ($i = 0; $i -lt $menuItems.Count; $i++) {
            $consoleWidth = [console]::WindowWidth
            $menuItemText = $menuItems[$i]
            # Main menu items are already hyphenated.
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
                } else {
                    $selectedIndex--
                }
            }
            'DownArrow' {
                if ($selectedIndex -eq ($menuItems.Count - 1)) {
                    $selectedIndex = 0
                } else {
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
# Function to Retrieve and Parse Submenu
# ----------------------------
function Get-Submenu {
    param(
        [string]$companyName
    )
    $submenuUrl = "https://raw.githubusercontent.com/TotalSecure-IT/jcorcoran-public/refs/heads/main/Universal/$companyName/submenu.txt"
    try {
        $submenuContent = Invoke-WebRequest -Uri $submenuUrl -UseBasicParsing -ErrorAction Stop | Select-Object -ExpandProperty Content
        $lines = $submenuContent -split "`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }
        $submenuItems = @()
        foreach ($line in $lines) {
            # Expected format: Title | ACTION = (Content)
            if ($line -match "^(.*?)\s*\|\s*(.+)$") {
                $title = $matches[1].Trim()
                $actionPart = $matches[2].Trim()
                if ($actionPart -match "^(MANIFEST|SCRIPT|DO)\s*=\s*\((.+)\)$") {
                    $actionType = $matches[1].Trim()
                    $actionContent = $matches[2].Trim()
                    $submenuItems += [PSCustomObject]@{
                        Title = $title
                        ActionType = $actionType
                        ActionContent = $actionContent
                    }
                }
                else {
                    $submenuItems += [PSCustomObject]@{
                        Title = $title
                        ActionType = ""
                        ActionContent = ""
                    }
                }
            }
        }
        return $submenuItems
    }
    catch {
        Write-MainLog "No submenu.txt found for $companyName. Error: $_"
        return $null
    }
}

# ----------------------------
# Function to Display Submenu Interactively
# ----------------------------
function Show-Submenu {
    param(
        [string]$companyName,
        [array]$submenuItems
    )
    # Check if manifest.txt exists for this company
    $manifestUrl = "https://raw.githubusercontent.com/TotalSecure-IT/jcorcoran-public/refs/heads/main/Universal/$companyName/manifest.txt"
    $hasManifest = $false
    try {
        $null = Invoke-WebRequest -Uri $manifestUrl -UseBasicParsing -ErrorAction Stop
        $hasManifest = $true
    }
    catch {
        $hasManifest = $false
    }
    if ($hasManifest) {
        $deployItem = [PSCustomObject]@{
            Title = "Deploy Onboarding Script"
            ActionType = "MANIFEST"
            ActionContent = $manifestUrl
        }
        $submenuItems = ,$deployItem + ($submenuItems | Sort-Object Title)
    }
    else {
        $submenuItems = $submenuItems | Sort-Object Title
    }
    # Always append "Go back" as last item.
    $goBackItem = [PSCustomObject]@{
        Title = "Go back"
        ActionType = "BACK"
        ActionContent = ""
    }
    $submenuItems += $goBackItem

    # Display submenu with header (the main menu item) above.
    Clear-Host
    $header = "╓" + $companyName
    Write-Host $header -ForegroundColor $MenuHighlightForeground -BackgroundColor $MenuHighlightBackground

    $selectedIndex = 0
    $exitSubmenu = $false
    while (-not $exitSubmenu) {
        # Print submenu items with aesthetic prefixes.
        for ($i = 0; $i -lt $submenuItems.Count; $i++) {
            if ($i -eq ($submenuItems.Count - 1)) {
                $prefix = "╚═ "
            } else {
                $prefix = "╠═ "
            }
            $itemText = $submenuItems[$i].Title
            $displayText = $prefix + $itemText
            # When selected, highlight only the text part (excluding prefix).
            if ($i -eq $selectedIndex) {
                $prefixLen = $prefix.Length
                $consoleWidth = [console]::WindowWidth
                $textWidth = $consoleWidth - $prefixLen
                $paddedText = $itemText.PadRight($textWidth)
                Write-Host $prefix -NoNewline
                Write-Host $paddedText -ForegroundColor $MenuHighlightForeground -BackgroundColor $MenuHighlightBackground
            } else {
                Write-Host $displayText -ForegroundColor $MenuDefaultForeground
            }
        }
        $key = [console]::ReadKey($true)
        switch ($key.Key) {
            'UpArrow' {
                if ($selectedIndex -eq 0) {
                    $selectedIndex = $submenuItems.Count - 1
                }
                else {
                    $selectedIndex--
                }
            }
            'DownArrow' {
                if ($selectedIndex -eq ($submenuItems.Count - 1)) {
                    $selectedIndex = 0
                }
                else {
                    $selectedIndex++
                }
            }
            'Enter' {
                $exitSubmenu = $true
            }
        }
    }
    return $submenuItems[$selectedIndex]
}

# ----------------------------
# Functions to Process Submenu Actions
# ----------------------------
function Process-Manifest {
    param(
        [string]$companyName,
        [string]$manifestUrl
    )
    Write-Host "Processing manifest for $companyName from $manifestUrl" -ForegroundColor Cyan
    $tempManifestFile = Join-Path $env:TEMP "manifest_$companyName.txt"
    try {
        Invoke-WebRequest -Uri $manifestUrl -OutFile $tempManifestFile -UseBasicParsing -ErrorAction Stop
        Write-MainLog "Downloaded manifest for $companyName from submenu."
    }
    catch {
        Write-Host "Error downloading manifest: $_" -ForegroundColor Red
        return
    }
    # Here, you would parse the manifest file, download its files into the appropriate company folder,
    # and then prompt the user to confirm launching the deployment script.
    Write-Host "Manifest processing for $companyName would occur here." -ForegroundColor Cyan
    $confirm = Read-Host "Deploy Onboarding Script? (y/n)"
    if ($confirm.ToLower() -eq "y") {
        Write-Host "Launching deployment script for $companyName..."
        # For example, launch the deploy.ps1 that was downloaded.
    }
    else {
        Write-Host "Deployment cancelled. Returning to main menu."
    }
    Remove-Item $tempManifestFile -Force
}

function Process-Script {
    param(
        [string]$scriptUrl
    )
    Write-Host "Downloading script from $scriptUrl..." -ForegroundColor Cyan
    $tempScript = Join-Path $env:TEMP "tempScript.ps1"
    try {
        Invoke-WebRequest -Uri $scriptUrl -OutFile $tempScript -UseBasicParsing -ErrorAction Stop
        Write-Host "Downloaded script. Executing..."
        & $tempScript
        Remove-Item $tempScript -Force
    }
    catch {
        Write-Host "Error processing script: $_" -ForegroundColor Red
    }
}

function Process-DO {
    param(
        [string]$command
    )
    Write-Host "Executing command: $command" -ForegroundColor Cyan
    Invoke-Expression $command
}

# ----------------------------
# Fallback: Setup-Company (existing manifest processing)
# ----------------------------
function Setup-Company {
    param(
        [string]$companyName
    )

    # Convert company name to folder-friendly name (if needed)
    $companyFolderName = $companyName -replace '\s+', '-'
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
    $manifestUrl = "https://raw.githubusercontent.com/TotalSecure-IT/jcorcoran-public/refs/heads/main/Universal/$companyFolderName/manifest.txt"
    Write-MainLog "Using manifest URL: $manifestUrl"
    # (Proceed with existing manifest processing...)
    Write-Host "Proceeding with standard manifest processing for $companyName." -ForegroundColor Cyan
    return @{ 
        BannerDir = $companyBannerDir; 
        ScriptsDir = $companyScriptsDir; 
        DeployPS1 = Join-Path $companyScriptsDir "deploy.ps1"; 
        FolderName = $companyFolderName 
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
# Main Execution Loop for Main Menu, Submenu & Deployment
# ----------------------------
$confirmed = $false
while (-not $confirmed) {

    # Show main menu from mainmenu.txt
    $selectedOption = Show-MainMenu
    if ($selectedOption -eq "Quit") {
        Write-Host "Exiting script. Goodbye!" -ForegroundColor Cyan
        Write-MainLog "User selected Quit. Exiting script."
        exit
    }

    # Attempt to retrieve submenu.txt for the selected main menu item.
    $submenuItems = Get-Submenu -companyName $selectedOption
    if ($submenuItems) {
        $selectedSubmenuItem = Show-Submenu -companyName $selectedOption -submenuItems $submenuItems
        switch ($selectedSubmenuItem.ActionType.ToUpper()) {
            "BACK" {
                Write-MainLog "User selected Go back in submenu for $selectedOption."
                continue  # Return to main menu loop.
            }
            "MANIFEST" {
                Process-Manifest -companyName $selectedOption -manifestUrl $selectedSubmenuItem.ActionContent
            }
            "SCRIPT" {
                Process-Script -scriptUrl $selectedSubmenuItem.ActionContent
            }
            "DO" {
                Process-DO -command $selectedSubmenuItem.ActionContent
            }
            default {
                Write-Host "No action defined for this submenu item. Returning to main menu." -ForegroundColor Yellow
                continue
            }
        }
    }
    else {
        # If no submenu.txt is available, fall back to standard manifest processing.
        $companySetup = Setup-Company -companyName $selectedOption
        # Prompt user for confirmation to deploy as per original behavior.
        $deployConfirm = Read-Host "No submenu available. Deploy onboarding script for $selectedOption? (y/n)"
        if ($deployConfirm.ToLower() -ne "y") {
            Write-Host "Deployment cancelled. Returning to main menu."
            continue
        }
        # Launch deployment using the downloaded deploy.ps1.
        try {
            Write-Host "Launching $selectedOption onboarding script..." -ForegroundColor Cyan
            Write-Host "Using script file: $($companySetup.DeployPS1)" -ForegroundColor Cyan
            Write-MainLog "Launching deploy script for $selectedOption."
            & $companySetup.DeployPS1 -ConfigPath (Join-Path (Join-Path $UsbRoot "configs") $companySetup.FolderName) -CompanyFolderName $companySetup.FolderName
        }
        catch {
            Write-Host "Error launching company script: $_" -ForegroundColor Red
            Write-MainLog "Error launching company script for $selectedOption: $_"
            Write-Host "Press any key to exit..."
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            exit
        }
    }
    Write-MainLog "Main script finished."
    # After processing a submenu action, return to the main menu.
    Write-Host "Press any key to return to the main menu..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

