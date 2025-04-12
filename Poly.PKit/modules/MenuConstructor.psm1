<#
.SYNOPSIS
    Provides a fully customizable interactive menu and submenu system.
.DESCRIPTION
    The menu displays a list of items with a fixed selection marker (the marker remains in a fixed position) while the list scrolls.
    Customizable parameters include starting row/column, number of visible rows, colors for selected and unselected items,
    and margins. The menu wraps around at the ends.
.EXAMPLE
    $menuSettings = @{
         StartRow                = 5
         StartColumn             = 0
         VisibleRows             = 10
         SelectionBarText        = ">>"
         SelectedForeground      = "Black"
         SelectedBackground      = "Yellow"
         UnselectedForeground    = "White"
         UnselectedBackground    = "Black"
         TopMargin               = 1
         BottomMargin            = 1
         FontSize                = 16    # (This parameter is informational; adjusting font size may require host-specific methods)
         LineSpacing             = 0     # (Additional empty lines between items)
    }
    $selectedIndex = Show-MainMenu -MenuItems (Get-ChildItem "C:\MyWorkingDir\orgs" -Directory | Select-Object -ExpandProperty Name) -Settings $menuSettings
#>

#region Global Menu Settings (default values used if not overridden)
$script:DefaultMenuSettings = @{
    StartRow             = 5
    StartColumn          = 0
    VisibleRows          = 10
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

function Show-MainMenu {
    <#
    .SYNOPSIS
         Displays a scrollable menu with a fixed selection bar.
    .DESCRIPTION
         Returns the index (0-based) of the selected item.
    .PARAMETER MenuItems
         An array of strings representing the menu items.
    .PARAMETER Settings
         A hashtable of settings to customize the menu appearance (see default values).
    .EXAMPLE
         $index = Show-MainMenu -MenuItems $items -Settings $menuSettings
    #>
    param(
        [Parameter(Mandatory=$true)][string[]]$MenuItems,
        [hashtable]$Settings = $script:DefaultMenuSettings
    )

    # Merge provided settings with defaults
    $s = $script:DefaultMenuSettings.Clone()
    foreach ($key in $Settings.Keys) {
        $s[$key] = $Settings[$key]
    }

    $visibleRows = [int]$s.VisibleRows
    $totalItems = $MenuItems.Count
    if ($totalItems -le 0) { return -1 }
    
    # The selection bar (marker) will be fixed at the middle of the visible area.
    $fixedMarkerRow = $s.StartRow + [math]::Floor($visibleRows / 2)
    
    # The visible window is determined by an offset. Initially, set the offset such that the selected item is at the fixed position.
    $selectedIndex = 0
    $offset = 0

    do {
        # Adjust offset so that $selectedIndex appears at fixedMarkerRow.
        if ($selectedIndex -lt $offset) {
            $offset = $selectedIndex
        } elseif ($selectedIndex -ge ($offset + $visibleRows)) {
            $offset = $selectedIndex - $visibleRows + 1
        }
        # Clear screen (or at least the menu portion). For simplicity, we Clear-Host.
        Clear-Host

        # Optionally print top margin
        for ($i = 0; $i -lt $s.TopMargin; $i++) { Write-Host "" }

        # Print visible menu lines.
        for ($i = 0; $i -lt $visibleRows; $i++) {
            $index = ($offset + $i) % $totalItems
            $itemText = $MenuItems[$index]
            # Apply line spacing if requested.
            for ($line = 0; $line -le $s.LineSpacing; $line++) {
                if ($i + $line -eq $fixedMarkerRow) {
                    # This is the fixed marker row.
                    $linePrefix = $s.SelectionBarText + " "
                    $fg = $s.SelectedForeground
                    $bg = $s.SelectedBackground
                }
                else {
                    $linePrefix = "   "
                    $fg = $s.UnselectedForeground
                    $bg = $s.UnselectedBackground
                }
                # Set cursor position (simulate text alignment)
                [Console]::SetCursorPosition($s.StartColumn, $s.StartRow + $i + $line)
                # Write the line with colors.
                Write-Host ($linePrefix + $itemText.PadRight(30)) -ForegroundColor $fg -BackgroundColor $bg
                break  # Only print one line per item; LineSpacing can be implemented by additional blank lines if needed.
            }
        }

        # Optionally print bottom margin
        for ($i = 0; $i -lt $s.BottomMargin; $i++) { Write-Host "" }

        # Read key press.
        $key = [Console]::ReadKey($true)
        switch ($key.Key) {
            'UpArrow'   { 
                $selectedIndex = ($selectedIndex - 1) % $totalItems 
                if ($selectedIndex -lt 0) { $selectedIndex += $totalItems }
            }
            'DownArrow' {
                $selectedIndex = ($selectedIndex + 1) % $totalItems
            }
            'Enter'     { return $selectedIndex }
        }
    } while ($true)
}

function Show-MainMenuLoop {
    <#
    .SYNOPSIS
         Displays the primary menu and processes selection.
    .EXAMPLE
         Show-MainMenuLoop -workingDir "C:\Users\isupport\Desktop\test"
    #>
    param(
        [Parameter(Mandatory=$true)][string]$workingDir
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
        # Call our new scrolling menu function with customizable settings.
        $settings = @{
            StartRow             = 1
            StartColumn          = 0
            VisibleRows          = 5
            SelectionBarText     = ">>"
            SelectedForeground   = "White"
            SelectedBackground   = "Red"
            UnselectedForeground = "Yellow"
            UnselectedBackground = "Black"
            TopMargin            = 2
            BottomMargin         = 2
            FontSize             = 20
            LineSpacing          = 1
        }
        $selectedIndex = Show-MainMenu -MenuItems $menuItems -Settings $settings
        if ($selectedIndex -eq ($menuItems.Count - 1)) {
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
