function Initialize-Logger {
    param(
        [Parameter(Mandatory=$true)]
        [string]$workingDir,

        [Parameter(Mandatory=$true)]
        [string]$hostName
    )

    # Set logs directory and create a new subfolder for this hostname if it does not exist
    $logsRoot = Join-Path $workingDir "logs"
    $hostLogFolder = Join-Path $logsRoot $hostName
    if (-not (Test-Path -Path $hostLogFolder)) {
        New-Item -ItemType Directory -Path $hostLogFolder | Out-Null
    }

    # Create a timestamp for the primary log filename using date and 12hr time format
    $dateStamp = Get-Date -Format "yyyy-MM-dd"
    $timeStamp = Get-Date -Format "hh-mm-sstt"  # e.g., 08-30-45PM
    $primaryLogFileName = "Poly.PKit_${dateStamp}@${timeStamp}.log"
    $primaryLogFilePath = Join-Path $hostLogFolder $primaryLogFileName

    # Create the primary log file with an initial header entry
    "Starting Poly.PKit log - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" | Out-File -FilePath $primaryLogFilePath

    # Return a custom object containing the log folder and primary log file path
    return [PSCustomObject]@{
        HostLogFolder      = $hostLogFolder
        PrimaryLogFilePath = $primaryLogFilePath
    }
}

function Write-Log {
    param(
        [Parameter(Mandatory=$true)]
        [string]$message,

        [Parameter(Mandatory=$true)]
        [string]$logFilePath
    )
    $logTimestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
    $logEntry = "[$logTimestamp] $message"
    Add-Content -Path $logFilePath -Value $logEntry
}

function Write-SystemLog {
    param(
        [Parameter(Mandatory=$true)]
        [string]$hostName,

        [Parameter(Mandatory=$true)]
        [string]$hostLogFolder,

        [Parameter(Mandatory=$true)]
        [string]$primaryLogFilePath
    )

    $systemLogFilePath = Join-Path $hostLogFolder "$hostName.log"
    if (-not (Test-Path -Path $systemLogFilePath)) {
        "System Details for $hostName - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" | Out-File -FilePath $systemLogFilePath
        "--------------------------------------------------------" | Out-File -Append -FilePath $systemLogFilePath

        $systemDetails = Get-ComputerInfo | Out-String
        $systemDetails | Out-File -Append -FilePath $systemLogFilePath

        "--------------------------------------------------------" | Out-File -Append -FilePath $systemLogFilePath
        "Network Information:" | Out-File -Append -FilePath $systemLogFilePath
        "--------------------------------------------------------" | Out-File -Append -FilePath $systemLogFilePath

        $networkInfo = ipconfig /all | Out-String
        $networkInfo | Out-File -Append -FilePath $systemLogFilePath

        Write-Log -message "System details and network information logged to $systemLogFilePath" -logFilePath $primaryLogFilePath
    }
    else {
        Write-Log -message "System log file already exists at $systemLogFilePath. Skipping system details logging." -logFilePath $primaryLogFilePath
    }
}

Export-ModuleMember -Function Initialize-Logger, Write-Log, Write-SystemLog
