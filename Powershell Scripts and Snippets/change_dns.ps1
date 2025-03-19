# Set the DNS servers
$DNSServers = "8.8.8.8","8.8.4.4"

# Get the network adapter configuration
$NetAdapter = Get-NetAdapter | Where-Object {$_.Status -eq "Up"}

# Set the DNS server addresses for the IPv4 and IPv6 protocols
Set-DnsClientServerAddress -InterfaceIndex $NetAdapter.InterfaceIndex -ServerAddresses $DNSServers
Set-DnsClientServerAddress -InterfaceIndex $NetAdapter.InterfaceIndex -ServerAddresses $DNSServers -AddressFamily IPv6