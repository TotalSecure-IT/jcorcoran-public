New-PSDrive -Name HKU -PSProvider Registry -Root HKEY_USERS | Out-Null

$profiles = Get-CimInstance Win32_UserProfile | Where-Object {
    $_.SID -match '^S-1-5-21-' -and $_.LocalPath -like 'C:\Users\*'
}

foreach ($profile in $profiles) {
    $sid = $profile.SID
    $ntUserDat = Join-Path $profile.LocalPath "NTUSER.DAT"

    if ($profile.Loaded) {
        Write-Host "User SID $sid is logged in (hive loaded). Checking key directly in HKU:\$sid"
        $thirdPartyKey = "HKU:\$sid\Software\Corel\WordPerfect\21\Third Party"
        if (Test-Path $thirdPartyKey) {
            try {
                Get-ItemProperty -Path $thirdPartyKey -Name "DLL1" -ErrorAction Stop
                Remove-ItemProperty -Path $thirdPartyKey -Name "DLL1" -ErrorAction Stop
                Write-Host "Removed DLL1 for SID $sid (currently logged on)."
            }
            catch {
                Write-Host "Error or 'DLL1' not found for SID ${sid}: $($_.Exception.Message)"
            }
        }
        else {
            Write-Host "Path not found under HKU:\$sid for user $sid (logged on)."
        }
    }
    else {
        if (Test-Path $ntUserDat) {
            $regHivePath = "HKU\$sid"
            Write-Host "Loading hive for $sid from $ntUserDat"
            reg load $regHivePath $ntUserDat | Out-Null

            $thirdPartyKey = "$regHivePath\Software\Corel\WordPerfect\21\Third Party"
            if (Test-Path $thirdPartyKey) {
                try {
                    Get-ItemProperty -Path $thirdPartyKey -Name "DLL1" -ErrorAction Stop
                    Remove-ItemProperty -Path $thirdPartyKey -Name "DLL1" -ErrorAction Stop
                    Write-Host "Removed DLL1 for user SID $sid"
                }
                catch {
                    Write-Host "Error or 'DLL1' not found for SID ${sid}: $($_.Exception.Message)"
                }
            }
            else {
                Write-Host "Path not found for SID $sid"
            }

            Write-Host "Unloading hive for $sid"
            reg unload $regHivePath | Out-Null
        }
        else {
            Write-Host "No NTUSER.DAT at $ntUserDat for SID $sid. Skipping."
        }
    }
}
