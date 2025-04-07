# Function to check disk space
function Get-DiskSpace {
    param (
        [string]$DriveLetter
    )

    $disk = Get-PSDrive -Name $DriveLetter
    if ($disk) {
        [PSCustomObject]@{
            Drive        = $disk.Name
            UsedSpaceGB  = [math]::Round($disk.Used / 1GB, 2)
            FreeSpaceGB  = [math]::Round($disk.Free / 1GB, 2)
            TotalSpaceGB = [math]::Round(($disk.Used + $disk.Free) / 1GB, 2)
            UsagePercent = [math]::Round(($disk.Used / ($disk.Used + $disk.Free)) * 100, 2)
        }
    } else {
        "Drive not found"
    }
}

# Function to check disk errors from event logs
function Get-DiskErrors {
    param (
        [string]$DriveLetter
    )

    # Search the System event log for disk-related errors
    $eventLogs = Get-WinEvent -LogName System | Where-Object { 
        $_.Message -like "*$DriveLetter*" -and ($_.Id -eq 7 -or $_.Id -eq 55)
    }

    if ($eventLogs) {
        $eventLogs | Select-Object -Property TimeCreated, Id, Message
    } else {
        "No disk errors found"
    }
}

# Function to check S.M.A.R.T. status
function Get-SmartStatus {
    param (
        [string]$DriveLetter
    )

    $smartStatus = "No S.M.A.R.T. data available or drive not supported."
    $physicalDisks = Get-PhysicalDisk

    foreach ($disk in $physicalDisks) {
        if ($disk.DeviceID -eq $DriveLetter) {
            $smartStatus = $disk | Select-Object -Property DeviceID, OperationalStatus, HealthStatus
            break
        }
    }

    return $smartStatus
}

# Main script
$drives = @("C", "D") # Modify drive letters as needed

foreach ($drive in $drives) {
    Write-Output "Checking drive: $($drive):"

    # Get disk space
    $diskSpace = Get-DiskSpace -DriveLetter $drive
    if ($diskSpace -is [PSCustomObject]) {
        Write-Output "Disk Space Usage:"
        Write-Output "  Used Space   : $($diskSpace.UsedSpaceGB) GB"
        Write-Output "  Free Space   : $($diskSpace.FreeSpaceGB) GB"
        Write-Output "  Total Space  : $($diskSpace.TotalSpaceGB) GB"
        Write-Output "  Usage Percent: $($diskSpace.UsagePercent)%"
    } else {
        Write-Output $diskSpace
    }

    # Get disk errors
    Write-Output "Disk Errors:"
    $diskErrors = Get-DiskErrors -DriveLetter "$drive`:"
    if ($diskErrors -is [string]) {
        Write-Output $diskErrors
    } else {
        $diskErrors | Format-Table -AutoSize
    }

    # Get S.M.A.R.T. status
    Write-Output "S.M.A.R.T. Status:"
    $smartStatus = Get-SmartStatus -DriveLetter "$drive`:"
    if ($smartStatus -is [string]) {
        Write-Output $smartStatus
    } else {
        $smartStatus | Format-Table -AutoSize
    }

    Write-Output "`n"
}
