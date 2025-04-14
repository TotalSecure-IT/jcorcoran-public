<#
 .SYNOPSIS
   Poly.PKit v2.0.0b
 .DESCRIPTION
   Main script for Poly.PKit.
#>

#Requires -RunAsAdministrator
#Requires -Version 7.0

#region Header Message
Clear-Host
Write-Host " "
Write-Host "Poly.PKit " -NoNewline -ForegroundColor White; Write-Host "v2.0.0b" -ForegroundColor Green
Write-Host " "
Write-Host "  Poly-Powershell Toolkit" -ForegroundColor DarkGreen
Write-Host " "
Write-Host "  This is super great because you can put" -ForegroundColor DarkGray
Write-Host "  all of your stuff into this and then" -ForegroundColor DarkGray
Write-Host "  you can put this into your pocket." -NoNewline -ForegroundColor DarkGray; Write-Host "--Wiggs, 1983" -ForegroundColor Magenta
Write-Host " "
Write-Host "  ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~" -ForegroundColor DarkRed
Write-Host " "
Write-Host "Initializing..." -ForegroundColor Cyan
Write-Host " "
#endregion

#------------------------------------------------------------------

#region Github Variables
# - G I T H U B  V A R I A B L E S -
$organization = "TASTY-MEAT"
$repo = "Poly.PKit"
$baseGitHubURL = "https://raw.githubusercontent.com/$organization/$repo/refs/heads/main/Poly.PKit"
$modulesManifestURL = "$baseGitHubURL/modules/Modules.csv"

# - G I T H U B  C O N F I G U R A T I O N -
$GithubConfig = Get-Config -workingDir $global:workingDir
$owner = $GithubConfig.owner
$repo  = $GithubConfig.repo
$token = $GithubConfig.token

Write-Host "Configuration loaded:"
Write-Host "  owner: " -NoNewline; Write-Host "$owner" -ForegroundColor Green
Write-Host "  repo : " -NoNewline; Write-Host "$repo" -ForegroundColor Green
Write-Host "  token: " -NoNewline; Write-Host "$token" -ForegroundColor Green
#endregion

#------------------------------------------------------------------

#region Script Directories
# - W H E R E  A R E  W E -
$MyScriptRoot = if ($MyInvocation.MyCommand.Path) {
    Split-Path $MyInvocation.MyCommand.Path -Parent
} else {
    (Get-Location).Path
}

# - A  P L A C E  T O  C A L L  H O M E -
$global:workingDir = Split-Path $MyScriptRoot -Parent

# - F O R  M E  A N D  M Y  F A M I L Y -
$global:workingDir = Join-Path $global:workingDir "Poly.PKit"
$FOLDER_NAME_MODULES = "modules"
$FOLDER_NAME_CONFIGS = "configs"
$FOLDER_NAME_ORGS = "orgs"
$FOLDER_NAME_LOGS = "logs"
$FOLDER_NAME_TEMP = "temp"
$FOLDER_NAME_SCRIPTS = "scripts"

# - A L L  O F  O U R  B E L O N G I N G S -
$modulesFolder = Join-Path $global:workingDir $FOLDER_NAME_MODULES
$configsPath = Join-Path $global:workingDir $FOLDER_NAME_CONFIGS
$orgsPath = Join-Path $global:workingDir $FOLDER_NAME_ORGS
$logsFolder = Join-Path $global:workingDir $FOLDER_NAME_LOGS
$tempFolder = Join-Path $global:workingDir $FOLDER_NAME_TEMP
$scriptsFolder = Join-Path $global:workingDir $FOLDER_NAME_SCRIPTS

# - T H E  T I M E S  W E  H A D -
function Write-Log {
    param (
        [string]$Message,
        [string]$LogFilePath,
        [string]$Level = "INFO",
        [switch]$NoConsole
    )
    
    if (-not $Message) { return }
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    
    # Write log entries to file
    if ($LogFilePath) {
        try {
            $logEntry | Out-File -FilePath $LogFilePath -Append -ErrorAction Stop
        }
        catch {
            Write-Warning "Unable to write to log file: $_"
        }
    }
    
    # Level markers
    if (-not $NoConsole) {
        $color = switch ($Level) {
            "ERROR"   { "Red" }
            "WARNING" { "Yellow" }
            "SUCCESS" { "Green" }
            default   { "Cyan" }
        }
        Write-Host $logEntry -ForegroundColor $color
    }
}

# - H O M E  I S  W H A T  Y O U  M A K E  I T -
function Invoke-ExistingDirs {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Path,
        [string]$Name,
        [switch]$CreateIfMissing = $null,
        [string]$LogFilePath,
        [switch]$Recursive
    )

    if (-not (Test-Path -Path $Path)) {
        if ($CreateIfMissing) {
            try {
                $params = @{
                    ItemType = "Directory"
                    Path = $Path
                    Force = $true
                    ErrorAction = "Stop"
                }
                
                if ($Recursive) {
                    $params.Add("Force", $true)
                }
                
                New-Item @params | Out-Null
                
                Write-Log `
                    -Message "Created folder '$Name' at '$Path'" `
                    -Level SUCCESS -LogFilePath $LogFilePath
                return $true
            }
            catch {
                Write-Log `
                    -Message "Failed to create folder '$Name' at '$Path': $_" `
                    -Level ERROR -LogFilePath $LogFilePath
                return $false
            }
        } else {
            Write-Log `
                -Message "Folder '$Name' does not exist at '$Path'" `
                -Level WARNING -LogFilePath $LogFilePath
            return $false
        }
    } else {
        Write-Log `
            -Message "Folder '$Name' already exists at '$Path'" `
            -Level SUCCESS -LogFilePath $LogFilePath
        return $true
    }
}    


# - R E M I N I S C E N C E -
$primaryLogFilePath = Join-Path $logsFolder "script_log_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

# - T H I S  I S  L I F E -
$dirsCreated = 0
$dirsCreated += [int](Invoke-ExistingDirs -Path $modulesFolder -Name $FOLDER_NAME_MODULES -LogFilePath $primaryLogFilePath)
$dirsCreated += [int](Invoke-ExistingDirs -Path $configsPath -Name $FOLDER_NAME_CONFIGS -LogFilePath $primaryLogFilePath)
$dirsCreated += [int](Invoke-ExistingDirs -Path $orgsPath -Name $FOLDER_NAME_ORGS -LogFilePath $primaryLogFilePath)
$dirsCreated += [int](Invoke-ExistingDirs -Path $logsFolder -Name $FOLDER_NAME_LOGS -LogFilePath $primaryLogFilePath)
$dirsCreated += [int](Invoke-ExistingDirs -Path $tempFolder -Name $FOLDER_NAME_TEMP -LogFilePath $primaryLogFilePath)
$dirsCreated += [int](Invoke-ExistingDirs -Path $scriptsFolder -Name $FOLDER_NAME_SCRIPTS -LogFilePath $primaryLogFilePath)

# - D E A T H -
Write-Log `
    -Message "Directory initialization complete. Created $dirsCreated new directories." `
    -Level SUCCESS -LogFilePath $primaryLogFilePath
#endregion

#------------------------------------------------------------------

#region Import Modules
# - I M P O R T  M O D U L E S -
try {
    Write-Log `
        -Message "Downloading modules manifest from GitHub..." `
        -Level INFO -LogFilePath $primaryLogFilePath
    # Download the CSV file containing the modules manifest
    $csvFilePath = Join-Path $modulesFolder "Modules.csv"
    Invoke-WebRequest -Uri $modulesManifestURL `
        -OutFile $csvFilePath -UseBasicParsing
} catch {
    Write-Log `
        -Message "Failed to download modules manifest. Exiting." `
        -Level ERROR -LogFilePath $primaryLogFilePath
    exit 1
}

# Parse Modules.csv to download and import modules
Write-Log `
    -Message "Parsing and importing modules from CSV file..." `
    -Level INFO -LogFilePath $primaryLogFilePath
try {
    $moduleList = Import-Csv -Path $csvFilePath
    foreach ($module in $moduleList) {
        # Parses 'ModuleFile' and 'ModuleURL' from the CSV
        if (-not $module.ModuleFile) {
            Write-Log `
                -Message "ModuleFile is empty. Skipping..." `
                -Level WARNING -LogFilePath $primaryLogFilePath
            continue
        }
        $moduleFileTrimmed = $module.ModuleFile.Trim()
        $moduleURL = "https://raw.githubusercontent.com/TotalSecure-IT/jcorcoran-public/refs/heads/main/Poly.PKit/modules/$moduleFileTrimmed"
        $localModulePath = Join-Path $modulesFolder $moduleFileTrimmed
        
        try {
            # Download the module
            Invoke-WebRequest -Uri $moduleURL `
                -OutFile $localModulePath -UseBasicParsing
            Write-Log `
                -Message "Downloaded module: $moduleFileTrimmed" `
                -Level SUCCESS -LogFilePath $primaryLogFilePath

            # Import the module
            Import-Module -Name $localModulePath -Force
            Write-Log `
                -Message "Imported module: $moduleFileTrimmed" `
                -Level SUCCESS -LogFilePath $primaryLogFilePath
        } catch {
            Write-Log -Message "Failed to process module: $moduleFileTrimmed" `
                -Level ERROR -LogFilePath $primaryLogFilePath
        }
    }
} catch {
    Write-Log -Message "Failed to parse modules CSV file. Exiting." `
        -Level ERROR -LogFilePath $primaryLogFilePath
    exit 1
}
#endregion

#------------------------------------------------------------------

#region Logs
# - L O G G I N G  C O N S T R U C T O R -
# Ensure logs are placed under: workingDir\logs\$companyName\$hostname
$hostName = $env:COMPUTERNAME
$companyName = $null 
$hostLogFolder = Join-Path -Path $global:workingDir -ChildPath "logs\$companyName\$hostName"

# Create the log folder if it doesn't exist
if (-not (Test-Path -Path $hostLogFolder)) {
    New-Item -ItemType Directory -Path $hostLogFolder -Force | Out-Null
    Write-Log `
        -Message "Created log folder: $hostLogFolder" `
        -Level SUCCESS -LogFilePath $primaryLogFilePath
} else {
    Write-Log `
        -Message "Log folder already exists: $hostLogFolder" `
        -Level INFO -LogFilePath $primaryLogFilePath
}

# Initialize logging
if (Get-Module -Name logger) {
    $primaryLogFilePath = Join-Path -Path $hostLogFolder -ChildPath "primary.log"
    if (-not (Test-Path -Path $primaryLogFilePath)) {
        New-Item -ItemType File -Path $primaryLogFilePath -Force | Out-Null
        Write-Log `
            -Message "Created primary log file: $primaryLogFilePath" `
            -Level SUCCESS -LogFilePath $primaryLogFilePath
    } else {
        Write-Log `
            -Message "Primary log file already exists: $primaryLogFilePath" `
            -Level INFO -LogFilePath $primaryLogFilePath
    }
    # Log initialization message
    Write-Log `
        -Message "Primary log file initialized: $(Split-Path $primaryLogFilePath -Leaf)" `
        -Level INFO -LogFilePath $primaryLogFilePath
    Write-SystemLog `
        -hostName $hostName `
        -hostLogFolder $hostLogFolder `
        -primaryLogFilePath $primaryLogFilePath
} else {
    Write-Log `
        -Message "Logger module not loaded. Skipping logging initialization." `
        -Level WARNING`
        -LogFilePath $primaryLogFilePath
    $primaryLogFilePath = Join-Path -Path $hostLogFolder -ChildPath "primary.log"
    Write-Log `
        -Message "Logger module not loaded. Logging will be limited to: $primaryLogFilePath" `
        -Level WARNING `
        -LogFilePath $primaryLogFilePath
}
#endregion

#------------------------------------------------------------------

#region OrgFolders hashtable
# - O R G A N I Z A T I O N  F O L D E R S -
$UpdateOrgFoldersParams = @{
    workingDir          = $global:workingDir
    owner               = $organization
    repo                = $repo
    token               = $token
    orgsFolderSha       = "8b8cde2fe87d2155653ddbdaa7530e01b84047bf"
    primaryLogFilePath  = $primaryLogFilePath
}

Update-OrgFolders @UpdateOrgFoldersParams
#end region

#------------------------------------------------------------------

#region Main Menu

# - M A I N  M E N U -
Start-Sleep -Seconds 1
Clear-Host

# Call the main menu loop:
Show-MainMenuLoop -workingDir $global:workingDir
#endregion