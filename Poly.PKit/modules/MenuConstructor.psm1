<#
.SYNOPSIS
    Provides a fully customizable interactive menu and submenu system.
.DESCRIPTION
    This module displays a scrolling menu in which a fixed selection marker remains in a set
    position as the list scrolls. The menu settings – including starting row/column, visible rows,
    selection bar text, colors (for selected and unselected items), top and bottom margins, and
    (informational) font size and line spacing – are customizable via a settings hashtable.
    Wrap-around scrolling is supported.
.EXAMPLE
    $menuSettings = @{
         StartRow             = 5
         StartColumn          = 0
         VisibleRows          = 10
         FixedMarkerRow       = 5    # Zero-based index within the visible window (default: Floor(VisibleRows/2))
         SelectionBarText     = ">>"
         SelectedForeground   = "Black"
         SelectedBackground   = "Yellow"
         UnselectedForeground = "White"
         UnselectedBackground = "Black"
         TopMargin            = 1
         BottomMargin         = 1
         FontSize             = 16   # Informational – host-specific adjustments may be required.
         LineSpacing          = 0    # Additional empty lines between items.
    }
    $selectedIndex = Show-MainMenu -MenuItems @("Item1","Item2","Item3","Quit") -Settings $menuSettings
#>

#region Default Menu Settings (script-scope)
$script:DefaultMenuSettings = @{
    StartRow             = 5
    StartColumn          = 0
    VisibleRows          = 10
    FixedMarkerRow       = 5    # If not provided, default to Floor(VisibleRows/2)
    SelectionBarText     = ">>"
    SelectedForeground   = "Black"
    SelectedBackground   = "Yellow"
    UnselectedForeground = "White"
    UnselectedBackground = "Black"
    TopMargin            = 1
    BottomMargin         = 1
    FontSize             = 16
    LineSpacing          = 0
}
#endregion

#region Menu Functions

function Show-MainMenu {
    <#
    .SYNOPSIS
         Displays a scrollable menu with a fixed selection bar.
    .DESCRIPTION
         Given an array of menu item strings and a settings hashtable, this function displays a scrolling
         menu. The selection marker remains fixed at a specified position (FixedMarkerRow) within the visible window.
         The entire list scrolls as the user presses the UpArrow and DownArrow keys, and wrap-around is supported.
         Returns the index (0-based) of the selected item.
    .PARAMETER MenuItems
         Array of strings for the menu.
    .PARAMETER Settings
         Hashtable for menu appearance and behavior. If omitted, default settings are used.
    .EXAMPLE
         $index = Show-MainMenu -MenuItems @("A","B","C","Quit") -Settings $menuSettings
    #>
    param(
        [Parameter(Mandatory = $true)][string[]]$MenuItems,
        [hashtable]$Settings = $script:DefaultMenuSettings
    )

    # Merge provided settings with defaults.
    $s = $script:DefaultMenuSettings.Clone()
    foreach ($k in $Settings.Keys) {
        $s[$k] = $Settings[$k]
    }
    $visibleRows = [int]$s.VisibleRows
    $totalItems = $MenuItems.Count
    if ($totalItems -eq 0) { return -1 }

    # Use the provided FixedMarkerRow or default to center.
    if (-not $s.FixedMarkerRow) {
        $fixedMarkerRow = [math]::Floor($visibleRows / 2)
    }
    else {
        $fixedMarkerRow = [int]$s.FixedMarkerRow
    }

    # The current window offset determines which items are visible.
    # The selected item is always the one at position offset + FixedMarkerRow (mod total items).
    $offset = 0

    while ($true) {
        Clear-Host
        # Print top margin lines.
        for ($i = 0; $i -lt $s.TopMargin; $i++) { Write-Host "" }
        # Print the visible window.
        for ($i = 0; $i -lt $visibleRows; $i++) {
            $currentIndex = ($offset + $i) % $totalItems
            $itemText = $MenuItems[$currentIndex]
            if ($i -eq $fixedMarkerRow) {
                $lineText = "$($s.SelectionBarText) $itemText"
                Write-Host $lineText -ForegroundColor $s.SelectedForeground -BackgroundColor $s.SelectedBackground
            }
            else {
                $lineText = "   $itemText"
                Write-Host $lineText -ForegroundColor $s.UnselectedForeground -BackgroundColor $s.UnselectedBackground
            }
        }
        # Print bottom margin lines.
        for ($i = 0; $i -lt $s.BottomMargin; $i++) { Write-Host "" }
        # Wait for key.
        $key = [Console]::ReadKey($true)
        switch ($key.Key) {
            'UpArrow' {
                $offset = ($offset - 1) % $totalItems
                if ($offset -lt 0) { $offset += $totalItems }
            }
            'DownArrow' {
                $offset = ($offset + 1) % $totalItems
            }
            'Enter' {
                # Return the item at fixedMarkerRow.
                return ($offset + $fixedMarkerRow) % $totalItems
            }
        }
    }
}

function Get-Submenu {
    <#
    .SYNOPSIS
         Retrieves submenu items from a remote submenu.txt file for the given company.
    .DESCRIPTION
         Fetches the raw submenu file from GitHub for the specified company folder.
         Parses each non-empty line in the format "Title | ActionType=(ActionContent)" and returns an array of PSCustomObjects.
    .PARAMETER companyName
         The name of the company (which corresponds to the folder name on GitHub).
    .EXAMPLE
         $submenu = Get-Submenu -companyName "AcmeCorp"
    #>
    param(
        [Parameter(Mandatory = $true)][string]$companyName
    )
    $submenuUrl = "https://raw.githubusercontent.com/TotalSecure-IT/jcorcoran-public/refs/heads/main/Poly.PKit/Orgs/$companyName/submenu.txt"
    try {
        $submenuContent = (Invoke-WebRequest -Uri $submenuUrl -UseBasicParsing -ErrorAction Stop).Content
        $lines = $submenuContent -split "\r?\n" | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }
        $submenuItems = @()
        foreach ($line in $lines) {
            if ($line -match "^(.*?)\s*\|\s*(.+)$") {
                $title = $matches[1].Trim()
                $actionPart = $matches[2].Trim()
                if ($actionPart -match "^(?i)(MANIFEST|SCRIPT|DO)\s*=\s*\((.*)\)$") {
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
        Write-Host "No submenu.txt found for $companyName. Error: $_" -ForegroundColor Yellow
        return $null
    }
}

function Show-Submenu {
    <#
    .SYNOPSIS
         Displays a submenu for a company, allowing selection via arrow keys.
    .DESCRIPTION
         Similar to the main menu, but simpler: prints the submenu items in a vertical list.
    .PARAMETER companyName
         The company for which the submenu is to be retrieved.
    .PARAMETER submenuItems
         An array of PSCustomObjects as returned by Get-Submenu.
    .PARAMETER startRow
         The row on the console at which to begin displaying the submenu.
    .EXAMPLE
         $selectedItem = Show-Submenu -companyName "AcmeCorp" -submenuItems $submenu -startRow 2
    #>
    param(
        [Parameter(Mandatory = $true)][string]$companyName,
        [Parameter(Mandatory = $true)][array]$submenuItems,
        [Parameter(Mandatory = $true)][int]$startRow
    )

    $selectedIndex = 0
    $exitSubmenu = $false
    # Determine maximum text length for padding.
    $maxLength = ($submenuItems | ForEach-Object { $_.Title.Length } | Measure-Object -Maximum).Maximum
    if (-not $maxLength) { $maxLength = 10 }
    do {
        # Clear only the submenu region
        for ($i = 0; $i -lt $submenuItems.Count; $i++) {
            [Console]::SetCursorPosition(0, $startRow + $i)
            $line = $submenuItems[$i].Title.PadRight($maxLength)
            if ($i -eq $selectedIndex) {
                Write-Host ">> $line" -ForegroundColor Yellow -BackgroundColor Blue
            }
            else {
                Write-Host "   $line" -ForegroundColor White -BackgroundColor Black
            }
        }
        $key = [Console]::ReadKey($true)
        switch ($key.Key) {
            'UpArrow'   { $selectedIndex = if ($selectedIndex -eq 0) { $submenuItems.Count - 1 } else { $selectedIndex - 1 } }
            'DownArrow' { $selectedIndex = if ($selectedIndex -eq ($submenuItems.Count - 1)) { 0 } else { $selectedIndex + 1 } }
            'Enter'     { $exitSubmenu = $true }
        }
    } while (-not $exitSubmenu)
    return $submenuItems[$selectedIndex]
}

function Invoke-Manifest {
    <#
    .SYNOPSIS
         Processes a manifest file from the given URL.
    .EXAMPLE
         Invoke-Manifest -companyName "AcmeCorp" -manifestUrl "https://example.com/manifest.txt"
    #>
    param(
        [Parameter()][string]$companyName,
        [Parameter()][string]$manifestUrl
    )
    Write-Host "Processing manifest for $companyName from $manifestUrl" -ForegroundColor Cyan
    try {
        $manifestContent = (Invoke-WebRequest -Uri $manifestUrl -UseBasicParsing -ErrorAction Stop).Content
        Write-Host "Manifest downloaded for $companyName" -ForegroundColor Green
        # Use manifestContent explicitly (e.g. output its length to verbose)
        Write-Verbose "Manifest content length: $($manifestContent.Length) characters"
    }
    catch {
        Write-Host "Error downloading manifest: $_" -ForegroundColor Red
        return
    }
    # Parse manifest lines: each line should be in the format: filename = "url"
    $lines = $manifestContent -split "\r?\n" | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }
    if ($lines.Count -eq 0) {
        Write-Host "Manifest file is empty." -ForegroundColor Red
        return
    }
    # Example usage: Download each file listed in the manifest.
    $tempRoot    = (Join-Path $env:TEMP "MenuConstructor-Files")
    $companyDir  = (Join-Path $tempRoot $companyName)
    if (-not (Test-Path $companyDir)) {
        New-Item -Path $companyDir -ItemType Directory | Out-Null
        Write-Verbose "Created directory $companyDir for $companyName's files"
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
                $downloadedFiles += $dest
            }
            catch {
                Write-Host "Error downloading $filename from $fileUrl -- $_" -ForegroundColor Red
            }
        }
        else {
            Write-Host "Invalid manifest line format: $line" -ForegroundColor Yellow
        }
    }
    # Optionally, check for scripts and prompt (if interactive)
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
    <#
    .SYNOPSIS
         Downloads and executes a remote script.
    .EXAMPLE
         Invoke-Script -scriptUrl "https://example.com/script.ps1"
    #>
    param(
        [Parameter()][string]$scriptUrl
    )
    Write-Host "Downloading script from $scriptUrl..." -ForegroundColor Cyan
    $tempScript = Join-Path $env:TEMP "tempScript.ps1"
    try {
        Invoke-WebRequest -Uri $scriptUrl -OutFile $tempScript -UseBasicParsing -ErrorAction Stop
        Write-Host "Executing downloaded script..." -ForegroundColor Cyan
        & $tempScript
        Remove-Item $tempScript -Force
    }
    catch {
        Write-Host "Error processing script: $_" -ForegroundColor Red
    }
}

function Invoke-DO {
    <#
    .SYNOPSIS
         Executes the provided command string.
    .EXAMPLE
         Invoke-DO -command "Get-Process"
    #>
    param(
        [Parameter()][string]$command
    )
    Write-Host "Executing command: $command" -ForegroundColor Cyan
    Invoke-Expression $command
}

function Show-MainMenuLoop {
    <#
    .SYNOPSIS
         Displays the primary menu and processes selection.
    .EXAMPLE
         Show-MainMenuLoop -workingDir "C:\MyWorkingDir"
    #>
    param(
        [Parameter(Mandatory = $true)][string]$workingDir
    )
    $orgsRoot = Join-Path $workingDir "orgs"
    if (-not (Test-Path $orgsRoot)) {
        Write-Host "No orgs folder found at $orgsRoot. Exiting menu." -ForegroundColor Yellow
        return
    }
    while ($true) {
        $folders = Get-ChildItem -Path $orgsRoot -Directory | Select-Object -ExpandProperty Name | Sort-Object
        if (-not $folders) {
            Write-Host "No folders found in $orgsRoot."
            return
        }
        $menuItems = $folders + "Quit"
        # Set up menu settings for the primary menu.
        $settings = @{
            StartRow             = 2
            StartColumn          = 0
            VisibleRows          = 10
            FixedMarkerRow       = 5  # 0-based; if VisibleRows=10, index 5 is the sixth row.
            SelectionBarText     = ">>"
            SelectedForeground   = "White"
            SelectedBackground   = "Red"
            UnselectedForeground = "Yellow"
            UnselectedBackground = "Black"
            TopMargin            = 1
            BottomMargin         = 1
            FontSize             = 20
            LineSpacing          = 0
        }
        $selectedIndex = Show-MainMenu -MenuItems $menuItems -Settings $settings
        if ($menuItems[$selectedIndex] -eq "Quit") {
            Write-Host "Exiting menu. Goodbye!" -ForegroundColor Cyan
            break
        }
        $chosen = $menuItems[$selectedIndex]
        $submenuItems = Get-Submenu -companyName $chosen
        if (-not $submenuItems) {
            Write-Host "No submenu found or error retrieving it for $chosen." -ForegroundColor Yellow
            Write-Host "Returning to main menu."
            continue
        }
        $selectedSubmenuItem = Show-Submenu -companyName $chosen -submenuItems $submenuItems -startRow 2
        if (-not $selectedSubmenuItem) {
            Write-Host "No submenu item selected. Returning to main menu." -ForegroundColor Yellow
            continue
        }
        switch ($selectedSubmenuItem.ActionType.ToUpper()) {
            "MANIFEST" { Invoke-Manifest -companyName $chosen -manifestUrl $selectedSubmenuItem.ActionContent }
            "SCRIPT"   { Invoke-Script -scriptUrl $selectedSubmenuItem.ActionContent }
            "DO"       { Invoke-DO -command $selectedSubmenuItem.ActionContent }
            default    { Write-Host "No action defined for this submenu item. Returning to main menu." -ForegroundColor Yellow; continue }
        }
        Write-Host "Press any key to return to the main menu..."
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        Clear-Host
    }
}

Export-ModuleMember -Function Get-Submenu, Show-Submenu, Invoke-Manifest, Invoke-Script, Invoke-DO, Show-MainMenuLoop
