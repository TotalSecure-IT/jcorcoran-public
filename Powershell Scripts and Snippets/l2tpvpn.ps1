$vpnName       = "SonicwallVPN"
$serverAddress = "24.225.22.246"
$psk           = "7E12A76071CB83C5"
$vpnUsername   = "it"
$vpnPassword   = "password."

Add-VpnConnection -Name $vpnName `
                  -ServerAddress $serverAddress `
                  -TunnelType L2tp `
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

$vpn = Get-VpnConnection -Name $vpnName;
if($vpn.ConnectionStatus -eq "Disconnected"){
	rasdial $vpnName $vpnUsername $vpnPassword;
}