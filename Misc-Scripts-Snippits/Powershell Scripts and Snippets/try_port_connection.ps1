$HostName = "localhost"
$Port = 8080

$Socket = New-Object System.Net.Sockets.TcpClient

# Attempt to connect to the port
try {
    $Socket.Connect($HostName, $Port)
    Write-Host "Connection successful"
} catch {
    Write-Host "Connection failed: $($_.Exception.Message)"
} finally {
    # Close the socket
    $Socket.Close()
}