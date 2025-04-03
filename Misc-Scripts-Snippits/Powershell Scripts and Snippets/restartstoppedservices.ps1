function Repair-ProblematicServices {
    param(
        [switch]$ForceRestart = $false
    )
    $AutoStartServices = Get-Service | Where-Object { $_.StartType -eq 'Automatic' }
    foreach ($service in $AutoStartServices) {
        $serviceName = $service.Name
        if ($service.Status -eq 'Stopped' -or $service.Status -eq 'Paused') {
            try {
                Write-Host "Attempting to restart $serviceName..."
                Restart-Service -Name $serviceName -Force -ErrorAction Stop
                Write-Host "$serviceName restarted successfully!"
            } catch {
                Write-Host "Failed to restart $serviceName $($_.Exception.Message)"
            }
        }
        elseif ($ForceRestart) {
            try {
                Write-Host "Forcing restart of $serviceName even though it's running..."
                Restart-Service -Name $serviceName -Force -ErrorAction Stop
                Write-Host "$serviceName restarted successfully!"
            } catch {
                Write-Host "Failed to force restart $serviceName $($_.Exception.Message)"
            }
        }
        else {
            Write-Host "Service $serviceName is running and does not need restarting."
        }
    }
}

Repair-ProblematicServices
