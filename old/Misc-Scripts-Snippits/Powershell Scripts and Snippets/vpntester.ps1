$vpnName       = ""
$serverAddress = ""
$psk           = ""
$vpnUsername   = ""
$vpnPassword   = ""

Add-VpnConnection -Name $vpnName `
                  -ServerAddress $serverAddress `
                  -TunnelType L2tp `
                  -AuthenticationMethod PAP, MSChapv2 `
                  -L2tpPsk $psk `
                  -Force `
                  -RememberCredential

Set-VpnConnectionIPsecConfiguration -ConnectionName $vpnName `
    -AuthenticationTransformConstants SHA1 `
    -CipherTransformConstants DES3 `
    -EncryptionMethod DES3 `
    -IntegrityCheckMethod SHA1 `
    -DHGroup Group2 `
    -PfsGroup None `
    -Force

# First, grab all VPN adapters
$vpnAdapters = Get-VpnConnection

if (!$vpnAdapters) {
    Write-Host "No VPN connections found! Exiting." -ForegroundColor Red
    exit
}

# Loop through each VPN adapter and disable the 'Use default gateway' setting
foreach ($vpn in $vpnAdapters) {
    Write-Host "Disabling default gateway for VPN: $($vpn.Name)" -ForegroundColor Cyan

    try {
        Set-VpnConnection -Name $vpn.Name -SplitTunneling $true -Force
        Write-Host "Default gateway disabled successfully for: $($vpn.Name)" -ForegroundColor Green
    }
    catch {
        Write-Host "Error disabling default gateway for: $($vpn.Name) - $_" -ForegroundColor Red
    }
}

Write-Host "All done!" -ForegroundColor Yellow

$vpn = Get-VpnConnection -Name $vpnName;
if($vpn.ConnectionStatus -eq "Disconnected"){
	rasdial $vpnName $vpnUsername $vpnPassword;
}