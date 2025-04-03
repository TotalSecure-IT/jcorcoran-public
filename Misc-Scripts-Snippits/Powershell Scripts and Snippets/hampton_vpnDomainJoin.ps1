## Create VPN
Add-VpnConnection -Name "Hampton VPN" -ServerAddress "hays-firewall-pzrptjwwqj.dynamic-m.com" -Tunneltype "L2tp" -EncryptionLevel "Optional" -AuthenticationMethod PAP -L2tpPsk "H@mptonVPN" -Force -RememberCredential

## Connect VPN
$vpnName = "Hampton VPN";
$username = "justin@wccit.com";
password = "B6$+85Gd)7Oet+hS";
$vpn = Get-VpnConnection -Name $vpnName;
if($vpn.ConnectionStatus -eq "Disconnected"){
	rasdial $vpnName $username $password;
}
## join domain
$domain = "hamptonlaw.local"
$pass = "B6$+85Gd)7Oet+hS" | ConvertTo-SecureString -asPlainText -Force
$user = "$domain\isupport" 
$credential = New-Object System.Management.Automation.PSCredential($user,$pass)
Add-Computer -DomainName $domain -Credential $credential