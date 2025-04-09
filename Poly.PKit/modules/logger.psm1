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
    
    # Create a subfolder for JSON debug logs.
    $jsonLogFolder = Join-Path $hostLogFolder "json"
    if (-not (Test-Path -Path $jsonLogFolder)) {
        New-Item -ItemType Directory -Path $jsonLogFolder | Out-Null
    }

    # Create a timestamp for the primary and JSON debug log filenames using date and 12hr time format
    $dateStamp = Get-Date -Format "yyyy-MM-dd"
    $timeStamp = Get-Date -Format "hh-mm-sstt"  # e.g., 08-30-45PM
    
    $primaryLogFileName = "Poly.PKit_${dateStamp}@${timeStamp}.log"
    $primaryLogFilePath = Join-Path $hostLogFolder $primaryLogFileName

    $jsonLogFileName = "json-debug_${dateStamp}@${timeStamp}.log"
    $jsonLogFilePath = Join-Path $jsonLogFolder $jsonLogFileName

    # Create the primary log file with an initial header entry
    "Starting Poly.PKit log - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" | Out-File -FilePath $primaryLogFilePath

    # Create the JSON debug log file header
    "JSON Debug Log - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" | Out-File -FilePath $jsonLogFilePath

    # Return a custom object containing the log folder and log file paths
    return [PSCustomObject]@{
        HostLogFolder      = $hostLogFolder
        PrimaryLogFilePath = $primaryLogFilePath
        JsonLogFilePath    = $jsonLogFilePath
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

function Write-JsonDebug {
    param(
        [Parameter(Mandatory=$true)]
        [string]$message,

        [Parameter(Mandatory=$true)]
        [string]$jsonLogFilePath
    )
    $logTimestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
    $logEntry = "[$logTimestamp] $message"
    Add-Content -Path $jsonLogFilePath -Value $logEntry
}

Export-ModuleMember -Function Initialize-Logger, Write-Log, Write-SystemLog, Write-JsonDebug
