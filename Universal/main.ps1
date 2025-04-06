param(
    [string]$UsbRoot
)

# Remove extraneous quotes from the passed USB root path.
$UsbRoot = $UsbRoot.Trim('"')

# Create a folder for logs in UsbRoot.
$logsPath = Join-Path $UsbRoot "logs"
if (-not (Test-Path $logsPath)) {
    New-Item -Path $logsPath -ItemType Directory -Force | Out-Null
}

# Define the main log file path in the logs folder.
$mainLogFile = Join-Path $logsPath ("{0}-main-log.log" -f (Get-Date -Format "yyyyMMdd_HHmmss"))

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
$MenuStartRow = 12
$SubmenuStartRow = 13  # Submenu will start at the same row as the main menu

# New adjustable margin (in characters) for MOTD (and banner, if desired)
$ExtraMargin = 10

# Global GitHub raw URLs for reading content directly.
$GlobalMainMenuUrl   = "https://raw.githubusercontent.com/TotalSecure-IT/jcorcoran-public/refs/heads/main/Universal/mainmenu.txt"
$GlobalMainBannerUrl = "https://raw.githubusercontent.com/TotalSecure-IT/jcorcoran-public/refs/heads/main/Universal/mainbanner.txt"
$GlobalMotdUrl       = "https://raw.githubusercontent.com/TotalSecure-IT/jcorcoran-public/refs/heads/main/Universal/motd.txt"

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
# Create Required Folder Structure in UsbRoot
# ----------------------------
# (Folders: Company_Banners, Company_Scripts, Installers will be created in UsbRoot)
$RequiredFolders = @("Company_Banners", "Company_Scripts", "Installers")
foreach ($folder in $RequiredFolders) {
    $folderPath = Join-Path $UsbRoot $folder
    if (-not (Test-Path $folderPath)) {
        New-Item -Path $folderPath -ItemType Directory -Force | Out-Null
        Write-MainLog "Created folder: $folderPath."
    }
}

# Set the working directory to UsbRoot.
Set-Location $UsbRoot
Write-MainLog "Set working directory to $UsbRoot."

# ----------------------------
# Functions to Read Global Components Directly from GitHub
# ----------------------------
function Get-ContentFromUrl {
    param(
       [string]$url
    )
    try {
        $response = Invoke-WebRequest -Uri $url -UseBasicParsing -ErrorAction Stop
        return $response.Content
    }
    catch {
        Write-MainLog "Error retrieving content from $url -- $_"
        return ""
    }
}

function Get-MainMenuContent {
    return Get-ContentFromUrl -url $GlobalMainMenuUrl
}

function Get-MainBannerContent {
    $content = Get-ContentFromUrl -url $GlobalMainBannerUrl
    if ([string]::IsNullOrWhiteSpace($content)) { return "== Universal Onboarding Script ==" } else { return $content }
}

function Get-MotdContent {
    $content = Get-ContentFromUrl -url $GlobalMotdUrl
    if ([string]::IsNullOrWhiteSpace($content)) { return "Welcome. Please select an option below:" } else { return $content }
}

# ----------------------------
# Function: Show-MainMenu (reads directly from GitHub)
# ----------------------------
function Show-MainMenu {
    $menuContent = Get-MainMenuContent
    $menuItems = $menuContent -split "\r?\n" | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }
    Clear-Host

    # Render Banner: Center each line.
    $bannerContent = Get-MainBannerContent
    $bannerLines = $bannerContent -split "\r?\n"
    foreach ($line in $bannerLines) {
        $trimLine = $line.TrimEnd()
        $leftMarginBanner = [math]::Floor(([console]::WindowWidth - $trimLine.Length) / 2)
        $spaces = " " * $leftMarginBanner
        Write-Host "$spaces$trimLine" -ForegroundColor $BannerColor
    }

    # Render MOTD as a block with extra margins.
    $motdContent = Get-MotdContent
    $motdLines = $motdContent -split "\r?\n"
    $availableWidth = [console]::WindowWidth - (2 * $ExtraMargin)
    foreach ($line in $motdLines) {
        $trimLine = $line.TrimEnd()
        $lineLength = $trimLine.Length
        $leftPad = $ExtraMargin + [math]::Floor(($availableWidth - $lineLength) / 2)
        $padSpaces = " " * $leftPad
        Write-Host "$padSpaces$trimLine" -ForegroundColor $MenuDefaultForeground
    }

    # Render main menu items centered.
    $selectedIndex = 0
    $exitMenu = $false
    while (-not $exitMenu) {
        for ($i = 0; $i -lt $menuItems.Count; $i++) {
            $width = [console]::WindowWidth
            $text = $menuItems[$i]
            $padding = [math]::Floor(($width - $text.Length) / 2)
            $line = (" " * $padding) + $text
            $line = $line.PadRight($width)
            [console]::SetCursorPosition(0, $MenuStartRow + $i)
            if ($i -eq $selectedIndex) {
                Write-Host $line -ForegroundColor $MenuHighlightForeground -BackgroundColor $MenuHighlightBackground
            } else {
                Write-Host $line -ForegroundColor $MenuDefaultForeground -BackgroundColor "Black"
            }
        }
        $key = [console]::ReadKey($true)
        switch ($key.Key) {
            'UpArrow' {
                if ($selectedIndex -eq 0) { $selectedIndex = $menuItems.Count - 1 } else { $selectedIndex-- }
            }
            'DownArrow' {
                if ($selectedIndex -eq ($menuItems.Count - 1)) { $selectedIndex = 0 } else { $selectedIndex++ }
            }
            'Enter' { $exitMenu = $true }
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
        $lines = $submenuContent -split "\r?\n" | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }
        $submenuItems = @()
        foreach ($line in $lines) {
            if ($line -match "^(.*?)\s*\|\s*(.+)$") {
                $title = $matches[1].Trim()
                $actionPart = $matches[2].Trim()
                if ($actionPart -match "^(MANIFEST|SCRIPT|DO)\s*=\s*\((.+)\)$") {
                    $actionType = $matches[1].Trim()
                    $actionContent = $matches[2].Trim()
                    $submenuItems += [PSCustomObject]@{
                        Title         = $title
                        ActionType    = $actionType
                        ActionContent = $actionContent
                    }
                }
                else {
                    $submenuItems += [PSCustomObject]@{
                        Title         = $title
                        ActionType    = ""
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
# Function: Show-Submenu
# ----------------------------
function Show-Submenu {
    param(
        [string]$companyName,
        [array]$submenuItems,
        [int]$SubmenuStartRow
    )
    # Check for manifest and insert reserved item.
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
            Title         = "Deploy Onboarding Script"
            ActionType    = "MANIFEST"
            ActionContent = $manifestUrl
        }
        $submenuItems = ,$deployItem + ($submenuItems | Sort-Object Title)
    }
    else {
        $submenuItems = $submenuItems | Sort-Object Title
    }
    $goBackItem = [PSCustomObject]@{
        Title         = "Go back"
        ActionType    = "BACK"
        ActionContent = ""
    }
    $submenuItems += $goBackItem

    $maxLength = ($submenuItems | ForEach-Object { $_.Title.Length } | Measure-Object -Maximum).Maximum
    if (-not $maxLength) { $maxLength = 20 }
    $prefixLength = 3
    $blockWidth = $maxLength + $prefixLength
    $consoleWidth = [console]::WindowWidth
    $leftMargin = [math]::Floor(($consoleWidth - $blockWidth) / 2)
    $marginSpaces = " " * $leftMargin

    # Clear the entire screen and add a blank top line.
    Clear-Host
    Write-Host ""  # Blank line at the top

    # Re-display mainbanner and MOTD.
    $bannerContent = Get-MainBannerContent
    $bannerLines = $bannerContent -split "\r?\n"
    foreach ($line in $bannerLines) {
        $trimLine = $line.TrimEnd()
        $leftMarginBanner = [math]::Floor(([console]::WindowWidth - $trimLine.Length) / 2)
        $spaces = " " * $leftMarginBanner
        Write-Host "$spaces$trimLine" -ForegroundColor $BannerColor
    }
    $motdContent = Get-MotdContent
    $motdLines = $motdContent -split "\r?\n"
    $availableWidth = [console]::WindowWidth - (2 * $ExtraMargin)
    foreach ($line in $motdLines) {
        $trimLine = $line.TrimEnd()
        $lineLength = $trimLine.Length
        $leftPad = $ExtraMargin + [math]::Floor(($availableWidth - $lineLength) / 2)
        $padSpaces = " " * $leftPad
        Write-Host "$padSpaces$trimLine" -ForegroundColor $MenuDefaultForeground
    }

    # Render the submenu starting at $SubmenuStartRow.
    $startClear = $SubmenuStartRow
    $endClear = [console]::WindowHeight - 1
    for ($r = $startClear; $r -le $endClear; $r++) {
        [console]::SetCursorPosition(0, $r)
        Write-Host (" " * $consoleWidth)
    }

    # Print header above submenu (only company name text highlighted).
    $headerPrefix = "╓"
    $headerText = $companyName
    [console]::SetCursorPosition(0, $startClear)
    Write-Host "$marginSpaces$headerPrefix" -NoNewline
    Write-Host $headerText -ForegroundColor $MenuHighlightForeground -BackgroundColor $MenuHighlightBackground

    $selectedIndex = 0
    $exitSubmenu = $false
    while (-not $exitSubmenu) {
        for ($i = 0; $i -lt $submenuItems.Count; $i++) {
            $row = $startClear + 1 + $i
            [console]::SetCursorPosition(0, $row)
            if ($i -eq ($submenuItems.Count - 1)) {
                $prefix = "╚═ "
            }
            else {
                $prefix = "╠═ "
            }
            $itemText = $submenuItems[$i].Title
            $paddedText = $itemText.PadRight($maxLength)
            $linePrefix = $marginSpaces + $prefix
            $fullLine = $linePrefix + $paddedText
            if ($i -eq $selectedIndex) {
                Write-Host $linePrefix -NoNewline
                Write-Host $paddedText -ForegroundColor $MenuHighlightForeground -BackgroundColor $MenuHighlightBackground
            }
            else {
                Write-Host $fullLine -ForegroundColor $MenuDefaultForeground -BackgroundColor "Black"
            }
        }
        $key = [console]::ReadKey($true)
        switch ($key.Key) {
            'UpArrow' {
                if ($selectedIndex -eq 0) { $selectedIndex = $submenuItems.Count - 1 } else { $selectedIndex-- }
            }
            'DownArrow' {
                if ($selectedIndex -eq ($submenuItems.Count - 1)) { $selectedIndex = 0 } else { $selectedIndex++ }
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
    try {
        $manifestContent = (Invoke-WebRequest -Uri $manifestUrl -UseBasicParsing -ErrorAction Stop).Content
        Write-MainLog "Downloaded manifest for $companyName from $manifestUrl"
    }
    catch {
        Write-Host "Error downloading manifest: $_" -ForegroundColor Red
        return
    }
    # Parse manifest: expecting each line as: filename = "url"
    $lines = $manifestContent -split "\r?\n" | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }
    if ($lines.Count -eq 0) {
        Write-Host "Manifest file is empty." -ForegroundColor Red
        return
    }
    $companyFolderName = $companyName -replace '\s+', '-'
    $bannerDir = Join-Path $UsbRoot "Company_Banners\$companyFolderName"
    $scriptsDir = Join-Path $UsbRoot "Company_Scripts\$companyFolderName"
    if (-not (Test-Path $bannerDir)) { New-Item -Path $bannerDir -ItemType Directory -Force | Out-Null; Write-MainLog "Created company banner directory: $bannerDir" }
    if (-not (Test-Path $scriptsDir)) { New-Item -Path $scriptsDir -ItemType Directory -Force | Out-Null; Write-MainLog "Created company scripts directory: $scriptsDir" }
    
    $downloadedFiles = @()
    foreach ($line in $lines) {
        if ($line -match "^(.*?)\s*=\s*\"(.*?)\("$") {
            $filename = $matches[1].Trim()
            $fileUrl = $matches[2].Trim()
            if ($filename -ieq "banner.txt") {
                $dest = Join-Path $bannerDir $filename
            }
            else {
                $dest = Join-Path $scriptsDir $filename
            }
            try {
                Invoke-WebRequest -Uri $fileUrl -OutFile $dest -UseBasicParsing -ErrorAction Stop
                Write-Host "Downloaded $filename to $dest" -ForegroundColor Green
                Write-MainLog "Downloaded $filename to $dest"
                $downloadedFiles += $dest
            }
            catch {
                Write-Host "Error downloading $filename from $fileUrl $_" -ForegroundColor Red
                Write-MainLog "Error downloading $filename from $fileUrl $_"
            }
        }
        else {
            Write-Host "Invalid manifest line format: $line" -ForegroundColor Yellow
            Write-MainLog "Invalid manifest line format: $line"
        }
    }
    
    # Determine if any .bat or .ps1 file was downloaded (prefer .bat if available)
    $batFile = $downloadedFiles | Where-Object { $_ -match "\.bat$" }
    $ps1File = $downloadedFiles | Where-Object { $_ -match "\.ps1$" }
    if ($batFile) {
        $prompt = Read-Host "Execute .bat file ($batFile)? (y/n)"
        if ($prompt.ToLower() -eq "y") {
            Write-Host "Executing $batFile..."
            & $batFile
        }
        else {
            Write-Host "Execution of $batFile cancelled."
        }
    }
    elseif ($ps1File) {
        $prompt = Read-Host "Execute .ps1 file ($ps1File)? (y/n)"
        if ($prompt.ToLower() -eq "y") {
            Write-Host "Executing $ps1File..."
            & $ps1File
        }
        else {
            Write-Host "Execution of $ps1File cancelled."
        }
    }
    else {
        Write-Host "No executable script (.bat or .ps1) found in manifest."
    }
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
# Fallback: Setup-Company (standard manifest processing)
# ----------------------------
function Setup-Company {
    param(
        [string]$companyName
    )
    $companyFolderName = $companyName -replace '\s+', '-'
    $companyBannerDir = Join-Path "$UsbRoot\Company_Banners" $companyFolderName
    $companyScriptsDir = Join-Path "$UsbRoot\Company_Scripts" $companyFolderName
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
    Write-Host "Proceeding with standard manifest processing for $companyName." -ForegroundColor Cyan
    return @{ 
        BannerDir   = $companyBannerDir; 
        ScriptsDir  = $companyScriptsDir; 
        DeployPS1   = Join-Path $companyScriptsDir "deploy.ps1"; 
        FolderName  = $companyFolderName 
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

    $selectedOption = Show-MainMenu
    if ($selectedOption -eq "Quit") {
        Write-Host "Exiting script. Goodbye!" -ForegroundColor Cyan
        Write-MainLog "User selected Quit. Exiting script."
        exit
    }

    $submenuItems = Get-Submenu -companyName $selectedOption
    if ($submenuItems) {
        $selectedSubmenuItem = Show-Submenu -companyName $selectedOption -submenuItems $submenuItems -SubmenuStartRow $SubmenuStartRow
        switch ($selectedSubmenuItem.ActionType.ToUpper()) {
            "BACK" {
                Write-MainLog "User selected Go back in submenu for $selectedOption."
                continue
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
        $companySetup = Setup-Company -companyName $selectedOption
        $deployConfirm = Read-Host "No submenu available. Deploy onboarding script for $selectedOption? (y/n)"
        if ($deployConfirm.ToLower() -ne "y") {
            Write-Host "Deployment cancelled. Returning to main menu."
            continue
        }
        try {
            Write-Host "Launching $selectedOption onboarding script..." -ForegroundColor Cyan
            Write-Host "Using script file: $($companySetup.DeployPS1)" -ForegroundColor Cyan
            Write-MainLog "Launching deploy script for $selectedOption."
            & $companySetup.DeployPS1 -ConfigPath (Join-Path (Join-Path $UsbRoot "configs") $companySetup.FolderName) -CompanyFolderName $companySetup.FolderName
        }
        catch {
            Write-Host "Error launching company script: $_" -ForegroundColor Red
            Write-MainLog "Error launching company script for $selectedOption-- $_"
            Write-Host "Press any key to exit..."
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            exit
        }
    }
    Write-MainLog "Main script finished."
    Write-Host "Press any key to return to the main menu..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}
