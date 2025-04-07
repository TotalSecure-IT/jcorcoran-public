## join domain
$domain = "hamptonlaw.local"
$pass = "68Slappy4u" | ConvertTo-SecureString -asPlainText -Force
$user = "$domain\isupport" 
$credential = New-Object System.Management.Automation.PSCredential($user,$pass)
Add-Computer -DomainName $domain -Credential $credential