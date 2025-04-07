# Specify the target desktop path
# Option 1: Desktop for a specific user
$UserDesktopPath = "C:\Users\mopat\Desktop"

# Option 2: Public desktop (visible to all users)
$PublicDesktopPath = "C:\Users\Public\Desktop"

# Select the desired option for shortcut placement
$DesktopPath = $PublicDesktopPath  # Change to $UserDesktopPath if needed

# Validate that the target desktop path exists
if (-not (Test-Path -Path $DesktopPath)) {
    Write-Error "The specified desktop path '$DesktopPath' does not exist. Please verify the path."
    return
}

# Name of the shortcut
$ShortcutName = "Outlook 365.lnk"

# Full path to the shortcut
$ShortcutPath = Join-Path -Path $DesktopPath -ChildPath $ShortcutName

# Path to the Outlook 365 executable
$OutlookPath = "C:\Program Files\Microsoft Office\root\Office16\OUTLOOK.EXE"

# Validate that the Outlook executable exists
if (-Not (Test-Path -Path $OutlookPath)) {
    Write-Error "Outlook executable not found at $OutlookPath. Please verify the installation path."
    return
}

# Create a WScript.Shell COM object
$Shell = New-Object -ComObject WScript.Shell

# Create the shortcut
try {
    $Shortcut = $Shell.CreateShortcut($ShortcutPath)
    $Shortcut.TargetPath = $OutlookPath
    $Shortcut.IconLocation = $OutlookPath
    $Shortcut.Description = "Launch Outlook 365"
    $Shortcut.Save()
    Write-Host "Desktop shortcut for Outlook 365 created successfully at $ShortcutPath."
} catch {
    Write-Error "Failed to create the shortcut: $_"
}
