# MenuConstructor.psm1
# ------------------------------------------------------------
# Adapts snippet logic from sample-script.txt for an interactive,
# scrollable menu that enumerates subfolders under workingDir\orgs,
# calls Get-Submenu for the selected folder, and processes submenu items.
# All adjustable variables for menu colors & positions are near the top.

# ------------------------------------------------------------
# Adjustable variables (menu colors, starting row/col, etc.)
# ------------------------------------------------------------

# Starting row & column for the menu display
$Global:MenuStartRow = 5
$Global:MenuStartColumn = 0

# Default text color for non-highlighted items
$Global:MenuDefaultForeground = "White"

# Highlighted item foreground/background
$Global:MenuHighlightForeground = "Black"
$Global:MenuHighlightBackground = "Yellow"

# We use these for the submenu as well
$Global:SubmenuDefaultForeground = "Gray"
$Global:SubmenuHighlightForeground = "Yellow"
$Global:SubmenuHighlightBackground = "Black"

# If your environment has "Write-Log" or "Write-MainLog" for logging,
# define whichever you prefer. We'll define a small helper:
function Write-MainLog {
    param([string]$message)
    # Adjust to your logging logic. For demonstration:
    Write-Host "[LOG] $message" -ForegroundColor Cyan
}

# ------------------------------------------------------------
# Function: Get-Submenu
# Retrieve & parse a remote submenu.txt from Poly.PKit/Orgs/<companyName>
# using the snippet logic. If you want to read from local, adapt accordingly.
# ------------------------------------------------------------
function Get-Submenu {
    param(
        [Parameter(Mandatory=$true)]
        [string]$companyName
    )
    # We'll fetch from the raw GitHub location for this org's submenu.txt
    $submenuUrl = "https://raw.githubusercontent.com/TotalSecure-IT/jcorcoran-public/refs/heads/main/Poly.PKit/Orgs/$companyName/submenu.txt"
    try {
        $submenuContent = Invoke-WebRequest -Uri $submenuUrl -UseBasicParsing -ErrorAction Stop |
                          Select-Object -ExpandProperty Content
        $lines = $submenuContent -split "\r?\n" | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }

        $submenuItems = @()
        foreach ($line in $lines) {
            if ($line -match "^(.*?)\s*\|\s*(.+)$") {
                $title = $matches[1].Trim()
                $actionPart = $matches[2].Trim()
                if ($actionPart -match "^(?i)\s*(MANIFEST|SCRIPT|DO)\s*=\s*\((.*)\)$") {
                    $actionType    = $matches[1].Trim()
                    $actionContent = $matches[2].Trim()
                    $submenuItems += [PSCustomObject]@{
                        Title         = $title
                        ActionType    = $actionType
                        ActionContent = $actionContent
                    }
                }
                else {
                    # If format not recognized, still store title
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

# ------------------------------------------------------------
# Function: Show-Submenu
# Displays the submenu items in a scrollable list, returning the
# selected item’s object (Title, ActionType, ActionContent)
# or $null if none selected.
# ------------------------------------------------------------
function Show-Submenu {
    param(
        [Parameter(Mandatory=$true)][string]$companyName,
        [Parameter(Mandatory=$true)][array]$submenuItems,
        [Parameter(Mandatory=$true)][int]$startRow
    )

    $selectedIndex = 0
    $exitSubmenu   = $false

    # We'll figure out the maximum item length for consistent lines
    $maxLength = ($submenuItems | ForEach-Object { $_.Title.Length } | Measure-Object -Maximum).Maximum
    if (-not $maxLength) { $maxLength = 10 }

    # Print a simple header
    [Console]::SetCursorPosition(0, $startRow)
    Write-Host "╓ " -NoNewline
    Write-Host $companyName -ForegroundColor $Global:MenuHighlightForeground -BackgroundColor $Global:MenuHighlightBackground

    while (-not $exitSubmenu) {
        for ($i = 0; $i -lt $submenuItems.Count; $i++) {
            # each row after $startRow+1
            $row = $startRow + 1 + $i
            [Console]::SetCursorPosition(0, $row)

            if ($i -eq ($submenuItems.Count - 1)) {
                $prefix = "╚═ "
            }
            else {
                $prefix = "╠═ "
            }

            $itemText   = $submenuItems[$i].Title
            $paddedText = $itemText.PadRight($maxLength)
            $linePrefix = $prefix

            if ($i -eq $selectedIndex) {
                Write-Host ($linePrefix) -NoNewline
                Write-Host ($paddedText) -ForegroundColor $Global:SubmenuHighlightForeground -BackgroundColor $Global:SubmenuHighlightBackground
            }
            else {
                Write-Host ($linePrefix + $paddedText) -ForegroundColor $Global:SubmenuDefaultForeground -BackgroundColor "Black"
            }
        }

        $key = [Console]::ReadKey($true)
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

# ------------------------------------------------------------
# The three snippet-based action processors: MANIFEST, SCRIPT, DO
# ------------------------------------------------------------

function Invoke-Manifest {
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
    # Parse manifest lines: each line: filename = "url"
    $lines = $manifestContent -split "\r?\n" | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }
    if ($lines.Count -eq 0) {
        Write-Host "Manifest file is empty." -ForegroundColor Red
        return
    }
    # Place downloaded files in some local folder(s). Adjust to your needs:
    $tempRoot    = (Join-Path $env:TEMP "MenuConstructor-Files")
    $companyDir  = (Join-Path $tempRoot $companyName)
    if (-not (Test-Path $companyDir)) {
        New-Item -Path $companyDir -ItemType Directory | Out-Null
        Write-MainLog "Created $companyDir for $companyName's files"
    }
    $downloadedFiles = @()
    foreach ($line in $lines) {
        if ($line -match '^(.*?)\s*=\s*"(.*?)"$') {
            $filename  = $matches[1].Trim()
            $fileUrl   = $matches[2].Trim()
            $dest      = Join-Path $companyDir $filename
            try {
                Invoke-WebRequest -Uri $fileUrl -OutFile $dest -UseBasicParsing -ErrorAction Stop
                Write-Host "Downloaded $filename to $dest" -ForegroundColor Green
                Write-MainLog "Downloaded $filename to $dest"
                $downloadedFiles += $dest
            }
            catch {
                Write-Host "Error downloading $filename from $fileUrl -- $_" -ForegroundColor Red
                Write-MainLog "Error downloading $filename from $fileUrl -- $_"
            }
        }
        else {
            Write-Host "Invalid manifest line format: $line" -ForegroundColor Yellow
            Write-MainLog "Invalid manifest line format: $line"
        }
    }
    # Optional: check if we have a .bat or .ps1 downloaded
    $batFile = $downloadedFiles | Where-Object { $_.EndsWith(".bat") }
    $ps1File = $downloadedFiles | Where-Object { $_.EndsWith(".ps1") }
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
        Write-Host "No .bat or .ps1 script found in this manifest."
    }
}

function Invoke-Script {
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

function Invoke-DO {
    param(
        [string]$command
    )
    Write-Host "Executing command: $command" -ForegroundColor Cyan
    Invoke-Expression $command
}

# ------------------------------------------------------------
# Show-MainMenuLoop:
#  1) Reads subfolders from workingDir\orgs => sorted
#  2) Renders them in an interactive menu (arrow keys)
#  3) Once user hits Enter, we call Get-Submenu => Show-Submenu => process action
#  4) If user chooses "Quit," we exit.
# ------------------------------------------------------------
function Show-MainMenuLoop {
    param(
        [Parameter(Mandatory=$true)][string]$workingDir
    )
    $orgsRoot = Join-Path $workingDir "orgs"
    if (-not (Test-Path $orgsRoot)) {
        Write-Host "No orgs folder found at $orgsRoot. Exiting menu."
        return
    }
    while ($true) {
        # 1) gather subfolder names, sorted
        $folders = Get-ChildItem -Path $orgsRoot -Directory | Select-Object -ExpandProperty Name | Sort-Object
        if (-not $folders) {
            Write-Host "No folders found in $orgsRoot."
            return
        }
        # We'll add a "Quit" item
        $menuItems = $folders + "Quit"
        # 2) render them in a scrollable menu
        $selectedIndex = 0
        $exitMenu      = $false
        while (-not $exitMenu) {
            for ($i=0; $i -lt $menuItems.Count; $i++) {
                [Console]::SetCursorPosition($Global:MenuStartColumn, $Global:MenuStartRow + $i)
                $itemText = $menuItems[$i]
                if ($i -eq $selectedIndex) {
                    Write-Host ("-> " + $itemText + "  ") -ForegroundColor $Global:MenuHighlightForeground -BackgroundColor $Global:MenuHighlightBackground
                }
                else {
                    Write-Host ("   " + $itemText + "  ") -ForegroundColor $Global:MenuDefaultForeground -BackgroundColor "Black"
                }
            }
            $key = [Console]::ReadKey($true)
            switch ($key.Key) {
                'UpArrow'   { if ($selectedIndex -gt 0) { $selectedIndex-- } else { $selectedIndex = $menuItems.Count - 1 } }
                'DownArrow' { if ($selectedIndex -lt ($menuItems.Count-1)) { $selectedIndex++ } else { $selectedIndex = 0 } }
                'Enter'     { $exitMenu = $true }
            }
        }
        Clear-Host
        $chosen = $menuItems[$selectedIndex]
        if ($chosen -eq "Quit") {
            Write-Host "Exiting menu. Goodbye!" -ForegroundColor Cyan
            break
        }
        # 3) user selected a real folder => get submenu => show => process
        $submenuItems = Get-Submenu -companyName $chosen
        if (-not $submenuItems) {
            Write-Host "No submenu found or error retrieving it for $chosen." -ForegroundColor Yellow
            Write-Host "Returning to main menu."
            continue
        }
        $selectedSubmenuItem = Show-Submenu -companyName $chosen -submenuItems $submenuItems -startRow 2
        if (-not $selectedSubmenuItem) {
            Write-Host "No submenu item selected? Returning to main menu." -ForegroundColor Yellow
            continue
        }
        # process the item
        switch ($selectedSubmenuItem.ActionType.ToUpper()) {
            "MANIFEST" {
                Invoke-Manifest -companyName $chosen -manifestUrl $selectedSubmenuItem.ActionContent
            }
            "SCRIPT" {
                Invoke-Script -scriptUrl $selectedSubmenuItem.ActionContent
            }
            "DO" {
                Invoke-DO -command $selectedSubmenuItem.ActionContent
            }
            default {
                Write-Host "No action defined for this submenu item. Returning to main menu." -ForegroundColor Yellow
                continue
            }
        }
        Write-Host "Press any key to return to the main menu..."
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        Clear-Host
    }
}

Export-ModuleMember -Function `
    Get-Submenu, Show-Submenu, Invoke-Manifest, Invoke-Script, Invoke-DO, Show-MainMenuLoop
