$printerAddress = "IP_10.1.0.82"
$printer = Get-WmiObject -Class Win32_Printer | Where-Object { $_.PortName -eq $printerAddress }

if ($printer) {
    Invoke-WmiMethod -Path $printer.__PATH -Name PrintTestPage
} else {
    Write-Host "Printer with address $printerAddress not found."
}
