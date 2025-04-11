<#
.SYNOPSIS
    Logger functions for Poly.PKit.
.DESCRIPTION
    Provides functions to initialize logging, write log entries, write system logs, and write JSON debug logs.
.EXAMPLE
    Initialize-Logger -workingDir "C:\MyWorkingDir" -hostName "MYHOST"
#>

function Initialize-Logger {
    <#
    .SYNOPSIS
        Initializes logging folders and files.
    .EXAMPLE
        $logInfo = Initialize-Logger -workingDir "C:\MyWorkingDir" -hostName "MYHOST"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$workingDir,
        [Parameter(Mandatory=$true)][string]$hostName
    )
    $logsRoot = Join-Path $workingDir "logs"
    if (-not (Test-Path $logsRoot)) {
        New-Item -ItemType Directory -Path $logsRoot | Out-Null
    }
    $hostLogFolder = Join-Path $logsRoot $hostName
    if (-not (Test-Path $hostLogFolder)) {
        New-Item -ItemType Directory -Path $hostLogFolder | Out-Null
    }
    $jsonLogFolder = Join-Path $hostLogFolder "json"
    if (-not (Test-Path $jsonLogFolder)) {
        New-Item -ItemType Directory -Path $jsonLogFolder | Out-Null
    }
    $dateStamp = Get-Date -Format "yyyy-MM-dd"
    $timeStamp = Get-Date -Format "hh-mm-sstt"
    $primaryLogFileName = "Poly.PKit_${dateStamp}@${timeStamp}.log"
    $primaryLogFilePath = Join-Path $hostLogFolder $primaryLogFileName
    "Starting Poly.PKit log - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" | Out-File -FilePath $primaryLogFilePath
    $jsonLogFileName = "json-debug_${dateStamp}@${timeStamp}.log"
    $jsonLogFilePath = Join-Path $jsonLogFolder $jsonLogFileName
    "JSON Debug Log - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" | Out-File -FilePath $jsonLogFilePath
    $script:JsonLogFilePath = $jsonLogFilePath
    return [PSCustomObject]@{
        HostLogFolder      = $hostLogFolder
        PrimaryLogFilePath = $primaryLogFilePath
        JsonLogFilePath    = $jsonLogFilePath
    }
}

function Write-Log {
    <#
    .SYNOPSIS
        Writes a log entry with a timestamp.
    .EXAMPLE
        Write-Log -message "This is a log entry." -logFilePath "C:\MyLog.log"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$message,
        [Parameter(Mandatory=$true)][string]$logFilePath
    )
    $logTimestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
    $logEntry = "[$logTimestamp] $message"
    Add-Content -Path $logFilePath -Value $logEntry
}

function Write-SystemLog {
    <#
    .SYNOPSIS
        Logs system details.
    .EXAMPLE
        Write-SystemLog -hostName "MYHOST" -hostLogFolder "C:\MyWorkingDir\logs\MYHOST" -primaryLogFilePath "C:\MyLog.log"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$hostName,
        [Parameter(Mandatory=$true)][string]$hostLogFolder,
        [Parameter(Mandatory=$true)][string]$primaryLogFilePath
    )
    $systemLogFilePath = Join-Path $hostLogFolder "$hostName.log"
    if (-not (Test-Path $systemLogFilePath)) {
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
    } else {
        Write-Log -message "System log file already exists at $systemLogFilePath. Skipping system details logging." -logFilePath $primaryLogFilePath
    }
}

function Write-JsonDebug {
    <#
    .SYNOPSIS
        Writes a JSON debug log entry.
    .EXAMPLE
        Write-JsonDebug -message "Debug info" -jsonLogFilePath "C:\MyJsonLog.log"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$message,
        [Parameter(Mandatory=$true)][string]$jsonLogFilePath
    )
    if ([string]::IsNullOrWhiteSpace($jsonLogFilePath)) {
        throw "The jsonLogFilePath parameter cannot be empty."
    }
    $logTimestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
    $logEntry = "[$logTimestamp] $message"
    Add-Content -Path $jsonLogFilePath -Value $logEntry
}

Export-ModuleMember -Function Initialize-Logger, Write-Log, Write-SystemLog, Write-JsonDebug
