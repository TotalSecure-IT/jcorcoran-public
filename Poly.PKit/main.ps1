<#
*~~~~~~~~~~~~~~~~~*
|Poly.PKit v1.0.1a|
*~~~~~~~~~~~~~~~~~*
#>

Clear-Host

# Set working directory to the parent of launcher.bat
$workingDir = Split-Path -Parent $PSScriptRoot
Set-Location $workingDir

#--------------------------------------------#
# Logger Module Acquisition & Import Section #
#--------------------------------------------#

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

#--------------------------------------------------#
# ConfigLoader Module Acquisition & Import Section #
#--------------------------------------------------#

# Define the ConfigLoader module file path inside the init\modules folder
$configLoaderModulePath = Join-Path $modulesFolder "ConfigLoader.psm1"
# URL for the ConfigLoader module on GitHub
$configLoaderModuleURL = "https://raw.githubusercontent.com/TotalSecure-IT/jcorcoran-public/refs/heads/main/Poly.PKit/modules/ConfigLoader.psm1"

#------------------------------------------------#
# Determine Mode and Acquire Modules Accordingly #
#------------------------------------------------#

$mode = $null
if ($args -contains '--online-mode') {
    $mode = "ONLINE"
    Write-Host "Mode:" -NoNewline
    Write-Host " ONLINE" -ForegroundColor Green

    # In online mode, download (or overwrite) the logger module from GitHub.
    try {
        Write-Host "Downloading logger module from GitHub..."
        Invoke-WebRequest -Uri $loggerModuleURL -OutFile $loggerModulePath -UseBasicParsing
        Write-Host "Logger module downloaded to $loggerModulePath."
    }
    catch {
        Write-Host "Failed to download logger module from GitHub. Exiting." -ForegroundColor Red
        exit 1
    }
    
    # In online mode, download (or overwrite) the ConfigLoader module from GitHub.
    try {
        Write-Host "Downloading ConfigLoader module from GitHub..."
        Invoke-WebRequest -Uri $configLoaderModuleURL -OutFile $configLoaderModulePath -UseBasicParsing
        Write-Host "ConfigLoader module downloaded to $configLoaderModulePath."
    }
    catch {
        Write-Host "Failed to download ConfigLoader module from GitHub. Exiting." -ForegroundColor Red
        exit 1
    }
}
elseif ($args -contains '--cached-mode') {
    $mode = "CACHED"
    Write-Host "Mode:" -NoNewline
    Write-Host " CACHED" -ForegroundColor Red

    # In cached mode, check if the logger module exists.
    if (-not (Test-Path -Path $loggerModulePath)) {
        Write-Host "Logger module not found in init\modules." -ForegroundColor Yellow
        Write-Host "Logging is disabled in cached mode. Please run the script in online mode at least once or manually obtain the logger module from GitHub."
        Read-Host "Press Enter to exit..."
        exit 1
    }
    
    # In cached mode, check if the ConfigLoader module exists.
    if (-not (Test-Path -Path $configLoaderModulePath)) {
        Write-Host "ConfigLoader module not found in init\modules." -ForegroundColor Yellow
        Write-Host "Configuration loading is disabled in cached mode. Please run the script in online mode at least once to obtain the module."
        Read-Host "Press Enter to exit..."
        exit 1
    }
}
else {
    Write-Host "No mode specified."
    $mode = "NONE"
}

# Import modules if they exist
if (Test-Path -Path $loggerModulePath) {
    Import-Module $loggerModulePath -Force
}
else {
    Write-Host "Logger module not available. Continuing without logging functionality." -ForegroundColor Yellow
}

if (Test-Path -Path $configLoaderModulePath) {
    Import-Module $configLoaderModulePath -Force
}
else {
    Write-Host "ConfigLoader module not available. Exiting." -ForegroundColor Yellow
    Read-Host "Press Enter to exit..."
    exit 1
}

#-----------------------------#
# Logging Initialization Code #
#-----------------------------#

# Get hostname
$hostName = $env:COMPUTERNAME

# Initialize logging if logger module was imported
if (Get-Module -Name logger) {
    # Call Initialize-Logger from the logger module. This creates the logs folder,
    # a subfolder for the hostname, and a timestamped primary log file.
    $logInfo = Initialize-Logger -workingDir $workingDir -hostName $hostName
    $hostLogFolder = $logInfo.HostLogFolder
    $primaryLogFilePath = $logInfo.PrimaryLogFilePath

    # Log that the primary log file has been created
    Write-Log -message "Primary log file created: $(Split-Path $primaryLogFilePath -Leaf)" -logFilePath $primaryLogFilePath

    # Log system details and network information
    Write-SystemLog -hostName $hostName -hostLogFolder $hostLogFolder -primaryLogFilePath $primaryLogFilePath
}
else {
    Write-Host "Logger module not loaded. Skipping logging initialization." -ForegroundColor Yellow
    $primaryLogFilePath = $null
    $hostLogFolder = $null
}

#--------------------------------------------------#
# Configuration File Verification via ConfigLoader #
#--------------------------------------------------#

# Use the Get-Config function from ConfigLoader module to load the configuration.
$config = Get-Config -workingDir $workingDir

# Retrieve security-sensitive variables from the configuration.
# (In the future, simply add more keys to main.ini and reference them here.)
$owner = $config.owner
$repo  = $config.repo
$token = $config.token 

Write-Host "Configuration loaded:" -ForegroundColor White
Write-Host "  owner: " -NoNewline
Write-Host "$owner" -ForegroundColor Green
Write-Host "  repo : " -NoNewline
Write-Host "$repo" -ForegroundColor Green
Write-Host "  token: " -NoNewline
Write-Host "$token" -ForegroundColor Green

#-------------------------------------#
# Mode-Specific Operations Begin Here #
#-------------------------------------#

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