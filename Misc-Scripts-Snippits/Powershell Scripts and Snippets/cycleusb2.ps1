# Disable all USB controllers
Get-PnpDevice -Class USB | Disable-PnpDevice -Confirm:$false

# Wait for 5 seconds
Start-Sleep -Seconds 5

# Enable all USB controllers
Get-PnpDevice -Class USB | Enable-PnpDevice -Confirm:$false