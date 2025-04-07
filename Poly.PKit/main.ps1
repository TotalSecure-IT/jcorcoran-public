# Clear the screen immediately upon launch
Clear-Host

# Set working directory to the parent of the script's folder (assumes main.ps1 is in the "init" folder)
$workingDir = Split-Path -Parent $PSScriptRoot
Set-Location $workingDir

# Determine the init folder (where main.ps1 resides) and the modules folder inside it
$initDir = $PSScriptRoot
$modulesFolder = Join-Path $initDir "modules"
if (-not (Test-Path -Path $modulesFolder)) {
    New-Item -ItemType Directory -Path $modulesFolder | Out-Null
}

# Define the logger module file path inside the init\modules folder
$loggerModulePath = Join-Path $modulesFolder "logger.psm1"
# URL for the logger module on GitHub
$loggerModuleURL = "https://raw.githubusercontent.com/TotalSecure-IT/jcorcoran-public/refs/heads/main/Poly.PKit/modules/logger.psm1"

# Determine the mode and handle logger module acquisition accordingly
$mode = $null
if ($args -contains '--online-mode') {
    $mode = "ONLINE"
    Write-Host "Mode:" -NoNewline
    Write-Host " ONLINE" -ForegroundColor Green
    # In online mode, download (or overwrite) the logger module from GitHub
    try {
        Write-Host "Downloading logger module from GitHub..."
        Invoke-WebRequest -Uri $loggerModuleURL -OutFile $loggerModulePath -UseBasicParsing
        Write-Host "Logger module downloaded to $loggerModulePath."
    }
    catch {
        Write-Host "Failed to download logger module from GitHub. Exiting." -ForegroundColor Red
        exit 1
    }
}
elseif ($args -contains '--cached-mode') {
    $mode = "CACHED"
    Write-Host "Mode:" -NoNewline
    Write-Host " CACHED" -ForegroundColor Red
    # In cached mode, check if the logger module exists in the modules folder.
    if (-not (Test-Path -Path $loggerModulePath)) {
        Write-Host "Logger module not found in init\modules." -ForegroundColor Yellow
        Write-Host "Logging is disabled in cached mode. Please run the script in online mode at least once or manually obtain the logger module from GitHub."
        # Optionally, you can pause or exit here.
        # exit 1
    }
}
else {
    Write-Host "No mode specified."
    $mode = "NONE"
}

# If logger module exists, import it (if in online mode it was just downloaded; if in cached mode it exists)
if (Test-Path -Path $loggerModulePath) {
    Import-Module $loggerModulePath -Force
}
else {
    Write-Host "Logger module not available. Continuing without logging functionality." -ForegroundColor Yellow
}

# Get hostname
$hostName = $env:COMPUTERNAME

# Initialize logging if logger module was imported
if (Get-Module -Name logger) {
    # Call Initialize-Logger from the logger module. This function creates the logs folder,
    # a subfolder for the hostname, and a timestamped primary log file.
    $logInfo = Initialize-Logger -workingDir $workingDir -hostName $hostName
    $hostLogFolder = $logInfo.HostLogFolder
    $primaryLogFilePath = $logInfo.PrimaryLogFilePath

    # Log that the primary log file has been created
    Write-Log -message "Primary log file created: $(Split-Path $primaryLogFilePath -Leaf)" -logFilePath $primaryLogFilePath

    # Call Write-SystemLog to log system details and network information
    Write-SystemLog -hostName $hostName -hostLogFolder $hostLogFolder -primaryLogFilePath $primaryLogFilePath
}
else {
    # If the logger module is not available, set dummy variables for later code (or handle as desired)
    Write-Host "Logger module not loaded. Skipping logging initialization." -ForegroundColor Yellow
    $primaryLogFilePath = $null
    $hostLogFolder = $null
}

# Continue with mode-specific operations
if ($mode -eq "ONLINE") {
    if ($primaryLogFilePath) { Write-Log -message "Running in ONLINE mode." -logFilePath $primaryLogFilePath }
    # In ONLINE mode, verbosely check/create the folder structure.
    # "configs" should already exist since it contains secret offline files.
    $configsPath = Join-Path $workingDir "configs"
    if (-Not (Test-Path -Path $configsPath)) {
         Write-Host "Warning: 'configs' folder not found. It should exist prior to script launch." -ForegroundColor Yellow
         if ($primaryLogFilePath) { Write-Log -message "Warning: 'configs' folder not found." -logFilePath $primaryLogFilePath }
    }
    else {
         Write-Host "'configs' folder exists."
         if ($primaryLogFilePath) { Write-Log -message "'configs' folder exists." -logFilePath $primaryLogFilePath }
    }

    # Create "Orgs" folder if it does not exist.
    $orgsPath = Join-Path $workingDir "Orgs"
    if (-Not (Test-Path -Path $orgsPath)) {
        Write-Host "Creating folder 'Orgs'..."
        if ($primaryLogFilePath) { Write-Log -message "Creating folder 'Orgs'." -logFilePath $primaryLogFilePath }
        New-Item -ItemType Directory -Path $orgsPath | Out-Null
    }
    else {
        Write-Host "Folder 'Orgs' already exists."
        if ($primaryLogFilePath) { Write-Log -message "Folder 'Orgs' already exists." -logFilePath $primaryLogFilePath }
    }

    # Create "modules" folder in the working directory if it does not exist.
    # (Note: The modules folder for logger is inside init folder, so these are separate.)
    $workingModulesPath = Join-Path $workingDir "modules"
    if (-Not (Test-Path -Path $workingModulesPath)) {
        Write-Host "Creating folder 'modules' in working directory..."
        if ($primaryLogFilePath) { Write-Log -message "Creating folder 'modules' in working directory." -logFilePath $primaryLogFilePath }
        New-Item -ItemType Directory -Path $workingModulesPath | Out-Null
    }
    else {
        Write-Host "Folder 'modules' in working directory already exists."
        if ($primaryLogFilePath) { Write-Log -message "Folder 'modules' in working directory already exists." -logFilePath $primaryLogFilePath }
    }
}
elseif ($mode -eq "CACHED") {
    if ($primaryLogFilePath) { Write-Log -message "Running in CACHED mode. Folder creation skipped." -logFilePath $primaryLogFilePath }
}
