# Remove the VPN connection if it already exists (for all users)
if (Get-VpnConnection -Name "Designplast VPN" -ErrorAction SilentlyContinue) {
    Remove-VpnConnection -Name "Designplast VPN" -Force -AllUserConnection
}

# Create the VPN connection for all users.
Add-VpnConnection -Name "Designplast VPN" `
                  -ServerAddress "24.225.20.45" `
                  -TunnelType L2TP `
                  -L2tpPsk '7L^74}$zHn-tX7d<' `
                  -AuthenticationMethod PAP, MSChapv2 `
                  -EncryptionLevel Required `
                  -Force `
                  -AllUserConnection

# Pause to ensure Windows writes the connection to the phonebook.
Start-Sleep -Seconds 3

# Path to the all-user VPN phonebook file.
$pbkPath = "C:\ProgramData\Microsoft\Network\Connections\Pbk\rasphone.pbk"

if (Test-Path $pbkPath) {
    $lines = Get-Content $pbkPath
    $newLines = @()
    $inSection = $false
    $dnsFound = $false
    $ipPrioritizeFound = $false

    foreach ($line in $lines) {
        # Check if this line is a section header
        if ($line -match '^\[.*\]') {
            # If we were in our VPN section and keys were missing, add them before starting a new section.
            if ($inSection -and ((-not $dnsFound) -or (-not $ipPrioritizeFound))) {
                if (-not $dnsFound) {
                    $newLines += "IpDnsAddress=192.168.2.234"
                }
                if (-not $ipPrioritizeFound) {
                    $newLines += "IpPrioritizeRemote=0"
                }
            }
            # Check if this is our VPN connection section (case-insensitive)
            if ($line -imatch '^\[Designplast VPN\]') {
                $inSection = $true
                $dnsFound = $false
                $ipPrioritizeFound = $false
            }
            else {
                $inSection = $false
            }
            $newLines += $line
        }
        else {
            if ($inSection) {
                if ($line -match "^\s*IpDnsAddress=") {
                    # Update the existing IpDnsAddress value
                    $line = "IpDnsAddress=192.168.2.234"
                    $dnsFound = $true
                }
                elseif ($line -match "^\s*IpPrioritizeRemote=") {
                    # Update to disable "Use default gateway on remote network"
                    $line = "IpPrioritizeRemote=0"
                    $ipPrioritizeFound = $true
                }
            }
            $newLines += $line
        }
    }
    # If file ended while still inside our VPN section, append missing keys.
    if ($inSection -and ((-not $dnsFound) -or (-not $ipPrioritizeFound))) {
        if (-not $dnsFound) {
            $newLines += "IpDnsAddress=192.168.2.234"
        }
        if (-not $ipPrioritizeFound) {
            $newLines += "IpPrioritizeRemote=0"
        }
    }
    # Write the updated content back to the PBK file.
    $newLines | Set-Content $pbkPath -Force
    Write-Output "Updated rasphone.pbk with IpDnsAddress and IpPrioritizeRemote settings."
}
else {
    Write-Output "PBK file not found at $pbkPath."
}

Write-Output "If the VPN is connected, please disconnect and reconnect to apply changes."
