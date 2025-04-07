Clear-Host

# Set working directory to the parent of the script's folder
$workingDir = Split-Path -Parent $PSScriptRoot
Set-Location $workingDir

$hostName = $env:COMPUTERNAME

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

# Create the primary log file with header
"Starting Poly.PKit log - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" | Out-File -FilePath $primaryLogFilePath

# Logging function for use throughout the script and future modules
function Write-Log {
    param (
        [string]$message
    )
    $logTimestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
    $logEntry = "[$logTimestamp] $message"
    Add-Content -Path $primaryLogFilePath -Value $logEntry
}

Write-Log "Primary log file created: $primaryLogFileName"

# Create system log file ($hostName.log) in the hostname folder, but only if it does not already exist.
$systemLogFilePath = Join-Path $hostLogFolder "$hostName.log"
if (-not (Test-Path -Path $systemLogFilePath)) {
    "System Details for $hostName - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" | Out-File -FilePath $systemLogFilePath
    "--------------------------------------------------------" | Out-File -Append -FilePath $systemLogFilePath
    
    # Append advanced system details
    $systemDetails = Get-ComputerInfo | Out-String
    $systemDetails | Out-File -Append -FilePath $systemLogFilePath

    # Append network information
    "--------------------------------------------------------" | Out-File -Append -FilePath $systemLogFilePath
    "Network Information:" | Out-File -Append -FilePath $systemLogFilePath
    "--------------------------------------------------------" | Out-File -Append -FilePath $systemLogFilePath
    $networkInfo = ipconfig /all | Out-String
    $networkInfo | Out-File -Append -FilePath $systemLogFilePath

    Write-Log "System details and network information logged to $systemLogFilePath"
}
else {
    Write-Log "System log file already exists at $systemLogFilePath. Skipping system details logging."
}

# Check for mode flags passed as arguments
if ($args -contains '--online-mode') {
    Write-Host "Mode:" -NoNewline
    Write-Host " ONLINE" -ForegroundColor Green
    Write-Log "Running in ONLINE mode."

    # In ONLINE mode, verbosely check/create the folder structure.
    # "configs" should already exist since it contains secret offline files.
    $configsPath = Join-Path $workingDir "configs"
    if (-Not (Test-Path -Path $configsPath)) {
         Write-Host "Warning: 'configs' folder not found. It should exist prior to script launch." -ForegroundColor Yellow
         Write-Log "Warning: 'configs' folder not found."
    }
    else {
         Write-Host "'configs' folder exists."
         Write-Log "'configs' folder exists."
    }

    # Create "Orgs" and "modules" folders if they do not exist.
    $folders = @("Orgs", "modules")
    foreach ($folder in $folders) {
        $folderPath = Join-Path $workingDir -ChildPath $folder
        if (-Not (Test-Path -Path $folderPath)) {
            Write-Host "Creating folder '$folder'..."
            Write-Log "Creating folder '$folder'."
            New-Item -ItemType Directory -Path $folderPath | Out-Null
        }
        else {
            Write-Host "Folder '$folder' already exists."
            Write-Log "Folder '$folder' already exists."
        }
    }
}
elseif ($args -contains '--cached-mode') {
    Write-Host "Mode:" -NoNewline
    Write-Host " CACHED" -ForegroundColor Red
    Write-Log "Running in CACHED mode. Folder creation skipped."
}
else {
    Write-Host "No mode specified."
    Write-Log "No mode specified. Default behavior invoked."
}
