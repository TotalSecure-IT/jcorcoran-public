<#
.SYNOPSIS
    Logger.psm1 - for error level logging
.DESCRIPTION
    Updated logger module for Poly.PKit
#>

#region Module Configuration
# Use strict mode to catch common scripting errors
Set-StrictMode -Version Latest

# Define global log levels as a hash table for easy lookup
$script:LogLevels = @{
    DEBUG   = 0
    INFO    = 1
    WARNING = 2
    ERROR   = 3
    CRITICAL = 4
    SUCCESS = 5
}

# Global settings - can be modified by Initialize-Logger
$script:LogSettings = @{
    DefaultLogPath = $null
    MinimumLevel = "INFO"
    ConsoleOutput = $true
    FileOutput = $true
    EventLogOutput = $false
    EventLogSource = "Poly.PKit"
    EventLogName = "Application"
    LogRetention = 30  # Days to keep logs
    MaxLogSizeMB = 10  # Maximum log file size in MB
    IsInitialized = $false
    HostLogFolder = $null
}
#endregion

#region Core Functions
# Initialize the logger with specific settings
function Initialize-Logger {
    [CmdletBinding()]
    param (
        [Parameter()]
        [string]$LogFilePath,
        
        [Parameter()]
        [ValidateSet('DEBUG', 'INFO', 'WARNING', 'ERROR', 'CRITICAL', 'SUCCESS')]
        [string]$MinimumLevel = 'INFO',
        
        [Parameter()]
        [bool]$ConsoleOutput = $true,
        
        [Parameter()]
        [bool]$FileOutput = $true,
        
        [Parameter()]
        [bool]$EventLogOutput = $false,
        
        [Parameter()]
        [string]$EventLogSource = "Poly.PKit",
        
        [Parameter()]
        [string]$EventLogName = "Application",
        
        [Parameter()]
        [int]$LogRetention = 30,
        
        [Parameter()]
        [int]$MaxLogSizeMB = 10,
        
        [Parameter()]
        [string]$HostLogFolder
    )
    
    # Update global settings
    $script:LogSettings.DefaultLogPath = $LogFilePath
    $script:LogSettings.MinimumLevel = $MinimumLevel
    $script:LogSettings.ConsoleOutput = $ConsoleOutput
    $script:LogSettings.FileOutput = $FileOutput
    $script:LogSettings.EventLogOutput = $EventLogOutput
    $script:LogSettings.EventLogSource = $EventLogSource
    $script:LogSettings.EventLogName = $EventLogName
    $script:LogSettings.LogRetention = $LogRetention
    $script:LogSettings.MaxLogSizeMB = $MaxLogSizeMB
    
    if ($HostLogFolder) {
        $script:LogSettings.HostLogFolder = $HostLogFolder
        
        # Create log folder if it doesn't exist
        if (-not (Test-Path -Path $HostLogFolder)) {
            New-Item -ItemType Directory -Path $HostLogFolder -Force | Out-Null
            Write-Log -Message "Created host log folder: $HostLogFolder" -Level SUCCESS
        }
    }
    
    # Setup event log source if needed and running as admin
    if ($EventLogOutput) {
        try {
            $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
            
            if ($isAdmin) {
                if (-not [System.Diagnostics.EventLog]::SourceExists($EventLogSource)) {
                    [System.Diagnostics.EventLog]::CreateEventSource($EventLogSource, $EventLogName)
                    Write-Log -Message "Created Event Log source: $EventLogSource" -Level INFO
                }
            }
            else {
                $script:LogSettings.EventLogOutput = $false
                Write-Log -Message "Not running as administrator. Event Log writing disabled." -Level WARNING
            }
        }
        catch {
            $script:LogSettings.EventLogOutput = $false
            Write-Log -Message "Failed to setup event log source: $($_.Exception.Message)" -Level WARNING
        }
    }
    
    # Clean up old logs if retention policy is set
    if ($LogRetention -gt 0 -and $HostLogFolder) {
        try {
            Get-ChildItem -Path $HostLogFolder -Filter "*.log" | 
                Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-$LogRetention) } | 
                ForEach-Object {
                    Remove-Item -Path $_.FullName -Force
                    Write-Log -Message "Removed old log file: $($_.Name)" -Level DEBUG
                }
        }
        catch {
            Write-Log -Message "Failed to clean old log files: $($_.Exception.Message)" -Level WARNING
        }
    }
    
    $script:LogSettings.IsInitialized = $true
    Write-Log -Message "Logger initialized with minimum level: $MinimumLevel" -Level INFO
}

# Main logging function - maintains compatibility with existing Write-Log
function Write-Log {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [string]$Message,
        
        [Parameter()]
        [string]$LogFilePath,
        
        [Parameter()]
        [ValidateSet('DEBUG', 'INFO', 'WARNING', 'ERROR', 'CRITICAL', 'SUCCESS')]
        [string]$Level = "INFO",
        
        [Parameter()]
        [switch]$NoConsole
    )
    
    if (-not $Message) { return }
    
    # Use provided log path or fall back to default
    $actualLogPath = if ($LogFilePath) { $LogFilePath } else { $script:LogSettings.DefaultLogPath }
    
    # Check if message should be logged based on minimum level
    $messageLevel = $script:LogLevels[$Level]
    $minimumLevel = $script:LogLevels[$script:LogSettings.MinimumLevel]
    
    if ($messageLevel -lt $minimumLevel) { return }
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    
    # Write to console if enabled and not suppressed
    if ($script:LogSettings.ConsoleOutput -and -not $NoConsole) {
        $color = switch ($Level) {
            "DEBUG"    { "Gray" }
            "INFO"     { "Cyan" }
            "WARNING"  { "Yellow" }
            "ERROR"    { "Red" }
            "CRITICAL" { "Magenta" }
            "SUCCESS"  { "Green" }
            default    { "White" }
        }
        
        Write-Host $logEntry -ForegroundColor $color
    }
    
    # Write to file if enabled and path is available
    if ($script:LogSettings.FileOutput -and $actualLogPath) {
        try {
            # Create directory if it doesn't exist
            $logDir = Split-Path -Parent $actualLogPath
            if (-not (Test-Path -Path $logDir -PathType Container)) {
                New-Item -Path $logDir -ItemType Directory -Force | Out-Null
            }
            
            # Check file size and rotate if needed
            if (Test-Path -Path $actualLogPath) {
                $logFile = Get-Item -Path $actualLogPath
                if (($logFile.Length / 1MB) -gt $script:LogSettings.MaxLogSizeMB) {
                    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
                    $newName = "$($logFile.BaseName)_$timestamp$($logFile.Extension)"
                    $newPath = Join-Path -Path $logDir -ChildPath $newName
                    Move-Item -Path $actualLogPath -Destination $newPath -Force
                }
            }
            
            # Write log entry
            Add-Content -Path $actualLogPath -Value $logEntry -ErrorAction Stop
        }
        catch {
            # If writing to file fails, try to write to console
            if ($script:LogSettings.ConsoleOutput) {
                Write-Host "Failed to write to log file: $($_.Exception.Message)" -ForegroundColor Red
            }
        }
    }
    
    # Write to event log if enabled
    if ($script:LogSettings.EventLogOutput) {
        try {
            $eventLogLevel = switch ($Level) {
                "DEBUG"    { "Information" }
                "INFO"     { "Information" }
                "SUCCESS"  { "Information" }
                "WARNING"  { "Warning" }
                "ERROR"    { "Error" }
                "CRITICAL" { "Error" }
                default    { "Information" }
            }
            
            $eventId = switch ($Level) {
                "DEBUG"    { 1000 }
                "INFO"     { 1001 }
                "SUCCESS"  { 1002 }
                "WARNING"  { 2000 }
                "ERROR"    { 3000 }
                "CRITICAL" { 3001 }
                default    { 1000 }
            }
            
            Write-EventLog -LogName $script:LogSettings.EventLogName -Source $script:LogSettings.EventLogSource `
                           -EntryType $eventLogLevel -EventId $eventId -Message $Message
        }
        catch {
            # If writing to event log fails, write to console
            if ($script:LogSettings.ConsoleOutput) {
                Write-Host "Failed to write to event log: $($_.Exception.Message)" -ForegroundColor Red
            }
        }
    }
}

# Close and finalize logger
function Close-Logger {
    [CmdletBinding()]
    param()
    
    if ($script:LogSettings.FileOutput -and $script:LogSettings.DefaultLogPath) {
        try {
            Write-Log -Message "Logging session ended" -Level INFO
        }
        catch {
            # Silent failure on close
        }
    }
    
    $script:LogSettings.IsInitialized = $false
}
#endregion

#region Level-Specific Logging Functions
# Functions for the different log levels
function Write-LogDebug {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [string]$Message,
        
        [Parameter()]
        [string]$LogFilePath
    )
    
    Write-Log -Message $Message -Level "DEBUG" -LogFilePath $LogFilePath
}

function Write-LogInfo {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [string]$Message,
        
        [Parameter()]
        [string]$LogFilePath
    )
    
    Write-Log -Message $Message -Level "INFO" -LogFilePath $LogFilePath
}

function Write-LogWarning {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [string]$Message,
        
        [Parameter()]
        [string]$LogFilePath
    )
    
    Write-Log -Message $Message -Level "WARNING" -LogFilePath $LogFilePath
}

function Write-LogError {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [string]$Message,
        
        [Parameter()]
        [string]$LogFilePath
    )
    
    Write-Log -Message $Message -Level "ERROR" -LogFilePath $LogFilePath
}

function Write-LogCritical {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [string]$Message,
        
        [Parameter()]
        [string]$LogFilePath
    )
    
    Write-Log -Message $Message -Level "CRITICAL" -LogFilePath $LogFilePath
}

function Write-LogSuccess {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [string]$Message,
        
        [Parameter()]
        [string]$LogFilePath
    )
    
    Write-Log -Message $Message -Level "SUCCESS" -LogFilePath $LogFilePath
}
#endregion

#region Detailed Logging
# Log exceptions with full details
function Write-LogException {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [System.Exception]$Exception,
        
        [Parameter()]
        [ValidateSet('WARNING', 'ERROR', 'CRITICAL')]
        [string]$Level = 'ERROR',
        
        [Parameter()]
        [string]$LogFilePath,
        
        [Parameter()]
        [string]$Context = ""
    )
    
    $contextInfo = if ($Context) { "[$Context] " } else { "" }
    $exceptionMessage = "${contextInfo}Exception: $($Exception.GetType().FullName): $($Exception.Message)"
    
    # Include stack trace if available
    $myStackTrace = if ($Exception.StackTrace) { 
        "`nStackTrace: $($Exception.StackTrace)" 
    } else { 
        "`nStackTrace: Not available" 
    }
    
    # Include inner exception if present
    $innerException = if ($Exception.InnerException) { 
        "`nInner Exception: $($Exception.InnerException.GetType().FullName): $($Exception.InnerException.Message)" 
    } else { 
        "" 
    }
    
    Write-Log -Message "$exceptionMessage$myStackTrace$innerException" -Level $Level -LogFilePath $LogFilePath
}

# System information logging
function Write-SystemLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$hostName,
        
        [Parameter(Mandatory = $true)]
        [string]$hostLogFolder,
        
        [Parameter()]
        [string]$primaryLogFilePath
    )
    
    try {
        # System information to log
        $osInfo = Get-CimInstance Win32_OperatingSystem
        $computerSystem = Get-CimInstance Win32_ComputerSystem
        $bios = Get-CimInstance Win32_BIOS
        $processor = Get-CimInstance Win32_Processor | Select-Object -First 1
        $drives = Get-CimInstance Win32_LogicalDisk | Where-Object { $_.DriveType -eq 3 }
        
        # Create a system info log file
        $systemLogPath = Join-Path -Path $hostLogFolder -ChildPath "system_info.log"
        
        # Log basic system information
        $systemInfo = @"
====== System Information Log ======
Timestamp: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
Computer Name: $hostName
OS: $($osInfo.Caption) (Version: $($osInfo.Version))
Manufacturer: $($computerSystem.Manufacturer)
Model: $($computerSystem.Model)
BIOS: $($bios.Manufacturer) (Version: $($bios.SMBIOSBIOSVersion))
Processor: $($processor.Name)
Memory: $([math]::Round($computerSystem.TotalPhysicalMemory / 1GB, 2)) GB
"@
        
        # Add drive information
        $systemInfo += "`n`n==== Disk Information ====`n"
        foreach ($drive in $drives) {
            $freeSpaceGB = [math]::Round($drive.FreeSpace / 1GB, 2)
            $totalSpaceGB = [math]::Round($drive.Size / 1GB, 2)
            $percentFree = [math]::Round(($drive.FreeSpace / $drive.Size) * 100, 2)
            
            $systemInfo += "Drive $($drive.DeviceID): $freeSpaceGB GB free of $totalSpaceGB GB ($percentFree% free)`n"
        }
        
        # Add network information
        $systemInfo += "`n==== Network Information ====`n"
        $networkAdapters = Get-CimInstance Win32_NetworkAdapterConfiguration | Where-Object { $null -ne $_.IPAddress }
        foreach ($adapter in $networkAdapters) {
            $systemInfo += "Adapter: $($adapter.Description)`n"
            $systemInfo += "  IP Address(es): $($adapter.IPAddress -join ', ')`n"
            $systemInfo += "  Gateway: $($adapter.DefaultIPGateway -join ', ')`n"
            $systemInfo += "  DNS Servers: $($adapter.DNSServerSearchOrder -join ', ')`n`n"
        }
        
        # Write the system information to the log file
        $systemInfo | Out-File -FilePath $systemLogPath -Force
        
        # Log a summary to the main log file
        Write-Log -Message "System information logged to: $systemLogPath" -Level INFO -LogFilePath $primaryLogFilePath
        Write-Log -Message "OS: $($osInfo.Caption), Memory: $([math]::Round($computerSystem.TotalPhysicalMemory / 1GB, 2)) GB" -Level INFO -LogFilePath $primaryLogFilePath
    }
    catch {
        Write-Log -Message "Failed to log system information: $($_.Exception.Message)" -Level ERROR -LogFilePath $primaryLogFilePath
    }
}

# Export public functions
Export-ModuleMember -Function Initialize-Logger, Write-Log, Write-LogDebug, Write-LogInfo, Write-LogWarning, 
                             Write-LogError, Write-LogCritical, Write-LogSuccess, Write-LogException, 
                             Write-SystemLog, Close-Logger