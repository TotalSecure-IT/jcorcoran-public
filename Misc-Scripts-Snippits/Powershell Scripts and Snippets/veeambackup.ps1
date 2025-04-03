# --- Disable Hibernation ---
Write-Host "Disabling Hibernation..."
try {
    powercfg -h off
    Write-Host "Hibernation disabled."
} catch {
    Write-Host "Error disabling hibernation: $_"
}

# --- Disable Paging (Virtual Memory) on System Drive (C:) ---
Write-Host "Disabling Paging (Virtual Memory) on C:..."
try {
    $regKey = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"
    # The PagingFiles registry value is normally formatted as "C:\pagefile.sys 0 0".
    # Setting it to an empty string disables the page file.
    Set-ItemProperty -Path $regKey -Name "PagingFiles" -Value ""
    Write-Host "Paging file disabled. A system reboot may be required."
} catch {
    Write-Host "Error disabling paging file: $_"
}

# --- Suspend BitLocker on C: ---
Write-Host "Suspending BitLocker on C:..."
try {
    $bitLocker = Get-BitLockerVolume -MountPoint "C:"
    if ($bitLocker.ProtectionStatus -eq 'On') {
        Suspend-BitLocker -MountPoint "C:" -RebootCount 1
        Write-Host "BitLocker suspended successfully."
    } else {
        Write-Host "BitLocker is already suspended or not enabled on C:."
    }
} catch {
    Write-Host "BitLocker not enabled on C: or error encountered: $_"
}

# --- Disable System Restore on C: ---
Write-Host "Disabling System Restore on C:..."
try {
    Disable-ComputerRestore -Drive "C:\"
    Write-Host "System Restore disabled on C:."
} catch {
    Write-Host "Error disabling System Restore: $_"
}

# --- Clear Temporary Files ---
Write-Host "Clearing temporary files..."
try {
    $tempPath = [System.IO.Path]::GetTempPath()
    Remove-Item -Path "$tempPath*" -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "Temporary files cleared."
} catch {
    Write-Host "Error clearing temporary files: $_"
}

# --- Clean Windows Update Cache ---
Write-Host "Cleaning Windows Update Cache..."
try {
    Stop-Service -Name wuauserv -Force -ErrorAction SilentlyContinue
    Remove-Item -Path "C:\Windows\SoftwareDistribution\Download\*" -Recurse -Force -ErrorAction SilentlyContinue
    Start-Service -Name wuauserv -ErrorAction SilentlyContinue
    Write-Host "Windows Update cache cleaned."
} catch {
    Write-Host "Error cleaning Windows Update cache: $_"
}

# --- Run Disk Cleanup ---
Write-Host "Running Disk Cleanup (cleanmgr)..."
try {
    # Note: Ensure that you have run "cleanmgr /sageset:1" at least once to configure cleanup options.
    Write-Host "If you haven't configured Disk Cleanup options, run 'cleanmgr /sageset:1' manually first."
    Start-Process cleanmgr.exe -ArgumentList "/sagerun:1" -Wait
    Write-Host "Disk Cleanup completed."
} catch {
    Write-Host "Error running Disk Cleanup: $_"
}

Write-Host "All critical pre-backup actions have been completed. Please review the output for any errors."
Write-Host "Note: A reboot may be required for some changes to take effect."
