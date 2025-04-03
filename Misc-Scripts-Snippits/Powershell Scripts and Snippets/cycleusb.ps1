Get-PnpDevice -FriendlyName "*USB*" | Disable-PnpDevice -confirm:$false
Get-PnpDevice -FriendlyName "*USB*" | Enable-PnpDevice -confirm:$false