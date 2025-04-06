param(
    [string]$ConfigPath,
    [Parameter(Mandatory = $true)]
    [string]$CompanyFolderName
)

# --- Set Debug Preference to show debugging messages ---
$DebugPreference = "Continue"

Write-Debug "Starting deploy.ps1 with CompanyFolderName: '$CompanyFolderName' and ConfigPath: '$ConfigPath'"

# --- Determine USB Root ---
if ([string]::IsNullOrWhiteSpace($ConfigPath)) {
    $usbroot = $PSScriptRoot
    Write-Debug "ConfigPath is empty. Using PSScriptRoot as USB root: '$usbroot'"
} else {
    $usbroot = Split-Path $ConfigPath -Parent
    Write-Debug "Using ConfigPath's parent as USB root: '$usbroot'"
}

# --- Define Log File Path ---
$timestamp = Get-Date -Format "yyyy-MM-dd_HHmm"
Write-Debug "Timestamp for log file: '$timestamp'"

$logsDir = Join-Path $usbroot "logs"
Write-Debug "Log directory (should already exist): '$logsDir'"

$logFile = Join-Path $logsDir "$CompanyFolderName.$timestamp.log"
Write-Debug "Log file will be: '$logFile'"

# --- Custom Logging Function ---
function Write-Log {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message
    )
    $timeStampLine = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Debug "Writing to log: $timeStampLine - $Message"
    Add-Content -Path $logFile -Value "$timeStampLine - $Message"
}

Write-Log "Deploy script started."

# --- Load Configuration ---
# Expected config file location: USBROOT\configs\<CompanyFolderName>\config.ini
$configFile = Join-Path (Join-Path (Join-Path $usbroot "configs") $CompanyFolderName) "config.ini"
Write-Debug "Calculated config file path: '$configFile'"

if (-not (Test-Path $configFile)) {
    Write-Log "Config file not found at $configFile. Exiting."
    exit 1
}

# --- INI to Hashtable Conversion ---
function Convert-IniToHashtable {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )
    Write-Debug "Converting INI file at path: '$Path'"
    $ini = @{}
    $section = ""
    foreach ($line in Get-Content $Path) {
        $line = $line.Trim()
        if ($line -match '^\[(.+)\]$') {
            $section = $matches[1]
            Write-Debug "Found section: '$section'"
            $ini[$section] = @{}
        }
        elseif ($line -match '^(.*?)=(.*)$') {
            $key = $matches[1].Trim()
            $value = $matches[2].Trim()
            Write-Debug "Found key: '$key' with value: '$value' in section: '$section'"
            if ($section) {
                $ini[$section][$key] = $value
            }
            else {
                $ini[$key] = $value
            }
        }
    }
    Write-Debug "Finished INI conversion."
    return $ini
}

$config = Convert-IniToHashtable -Path $configFile
Write-Log "Loaded config from $configFile."

# --- Extract Basic Config Values ---
$vpnName       = $config.General.vpnName
$serverAddress = $config.General.serverAddress
$psk           = $config.Credentials.vpnPsk
$vpnUsername   = $config.Credentials.vpnUsername
$vpnPassword   = $config.Credentials.vpnPassword
$domainJoinUser = $config.Credentials.domainJoinUser
$domainJoinPassword = $config.Credentials.domainJoinPassword
$localAdminUser = $config.Credentials.localAdminUser
$localAdminPassword = $config.Credentials.localAdminPassword

Write-Log "Configuration loaded. VPN: '$vpnName', Server: '$serverAddress'."

# --- (Placeholder for additional deploy processing) ---
Write-Log "Deploy script completed. (Insert further processing steps here as needed.)"

# End of deploy.ps1 template
