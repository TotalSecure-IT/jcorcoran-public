param(
    [string]$ConfigPath
)

# ====================
# INITIAL SETUP & LOGGING
# ====================

# Create a new log filename with a timestamp
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$logFile = Join-Path $PSScriptRoot "deployment_log_$timestamp.txt"

# Global variable for the winget download info
$global:WingetDownloadInfo = @{}
if (-not $appStatus) { $appStatus = @{} }
if (-not $tableStartLine) { $tableStartLine = 8 }

# Global error log array
$global:ErrorLog = @()

# (Do not disable the progress bar; let Invoke-WebRequest show it)
#$ProgressPreference = 'SilentlyContinue'

# Custom logging function
function Write-Log {
    param(
        [Parameter(Mandatory)]
        [string]$Message
    )
    $timeStampLine = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $logFile -Value "$timeStampLine - $Message"
}

# Record the script start time
$global:ScriptStart = Get-Date
Write-Log "Script started."

$global:RebootRequired = @()

if ($process.ExitCode -eq 3010) {
    $global:RebootRequired += $app.Name
}

# Function to read our INI file into a hashtable
function Convert-IniToHashtable {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )
    $ini = @{}
    $section = ""
    foreach ($line in Get-Content $Path) {
        $line = $line.Trim()
        if ($line -match '^\[(.+)\]$') {
            $section = $matches[1]
            $ini[$section] = @{}
        }
        elseif ($line -match '^(.*?)=(.*)$') {
            $key = $matches[1].Trim()
            $value = $matches[2].Trim()
            if ($section) {
                $ini[$section][$key] = $value
            }
            else {
                $ini[$key] = $value
            }
        }
    }
    return $ini
}

# Load our config file from the dynamic location if provided, else from $PSScriptRoot.
if ($ConfigPath) {
    $configFile = Join-Path $ConfigPath "config.ini"
} else {
    $configFile = Join-Path $PSScriptRoot "config.ini"
}

if (-not (Test-Path $configFile)) {
    Write-Log "Config file not found at $configFile. Exiting."
    exit 1
}
$config = Convert-IniToHashtable -Path $configFile

# Set some basic vars from the config
$vpnName       = $config.General.vpnName
$serverAddress = $config.General.serverAddress

# Get credentials and other settings from the config
$psk                = $config.Credentials.vpnPsk
$vpnUsername        = $config.Credentials.vpnUsername
$vpnPassword        = $config.Credentials.vpnPassword
$domainJoinUser     = $config.Credentials.domainJoinUser
$domainJoinPassword = $config.Credentials.domainJoinPassword
$localAdminUser     = $config.Credentials.localAdminUser
$localAdminPassword = $config.Credentials.localAdminPassword

# ====================
# BUILD APPS LIST FROM CONFIG.INI
# ====================
$appCount = [int]$config.Apps.Count
$appsToInstall = @()
for ($i = 1; $i -le $appCount; $i++) {
    $nameKey = "App${i}Name"
    $sourceKey = "App${i}Source"
    $argsKey = "App${i}Args"
    $checkPathKey = "App${i}CheckPath"
    $app = @{
        Name      = $config.Apps.$nameKey
        Source    = $config.Apps.$sourceKey
        Args      = $config.Apps.$argsKey
        CheckPath = $config.Apps.$checkPathKey
    }
    $appsToInstall += $app
}

# ====================
# FUNCTIONS FOR ANSI & OUTPUT (GLOBAL SCOPE)
# ====================
function global:Get-AnsiForeground {
    param(
        [Parameter(Mandatory)]
        [int]$Index
    )
    return "$([char]27)[38;5;${Index}m"
}

function global:Get-AnsiBackground {
    param(
        [Parameter(Mandatory)]
        [int]$Index
    )
    return "$([char]27)[48;5;${Index}m"
}

function global:Write-ClearedLine {
    param(
        [string]$Text,
        [int]$Width = 80,
        $ForegroundColor = $null
    )
    $clearLine = "$([char]27)[2K"
    $padded = $Text.PadRight($Width)
    if ($ForegroundColor) {
        if ($ForegroundColor -match "^#([0-9A-Fa-f]{6})$") {
            $hex = $ForegroundColor.Substring(1)
            $r = [Convert]::ToInt32($hex.Substring(0,2),16)
            $g = [Convert]::ToInt32($hex.Substring(2,2),16)
            $b = [Convert]::ToInt32($hex.Substring(4,2),16)
            $ansiColor = "$([char]27)[38;2;${r};${g};${b}m"
            $reset = "$([char]27)[0m"
            Write-Host -NoNewLine "$clearLine$ansiColor$padded$reset"
        }
        elseif ([int]::TryParse($ForegroundColor, [ref]$null)) {
            $num = [int]$ForegroundColor
            $ansiColor = Get-AnsiForeground $num
            $reset = "$([char]27)[0m"
            Write-Host -NoNewLine "$clearLine$ansiColor$padded$reset"
        }
        else {
            Write-Host -NoNewLine "$clearLine$padded" -ForegroundColor $ForegroundColor
        }
    }
    else {
         Write-Host -NoNewLine "$clearLine$padded"
    }
    Write-Host
}

function global:Set-CursorPosition {
    param(
        [int]$Row,
        [int]$Column = 1
    )
    $esc = [char]27
    $ansiCode = "$esc[{0};{1}H" -f $Row, $Column
    Write-Host -NoNewLine $ansiCode
}

function global:Render-Banner {
    Set-CursorPosition -Row 1 -Column 1
    try {
        $bannerFile = Join-Path $PSScriptRoot "banner.txt"
        if (Test-Path $bannerFile) {
            $bannerLines = Get-Content $bannerFile -Encoding UTF8
            $bannerColors = @("DarkBlue", "Blue", "DarkCyan", "DarkGreen", "Green", "Cyan", "Gray", "DarkGray", "Green", "DarkGreen")
            for ($i = 0; $i -lt $bannerLines.Count; $i++) {
                $color = if ($i -lt $bannerColors.Count) { $bannerColors[$i] } else { "52" }
                Write-ClearedLine -Text $bannerLines[$i] -Width 80 -ForegroundColor $color
            }
        }
        else {
            throw "No banner file."
        }
    }
    catch {
        Write-ClearedLine -Text "BANNER ISSUES" -Width 80 -ForegroundColor "Green"
    }
}

# Render-WingetInfo displays only the current winget download info (banner + current APP/URL)
function global:Render-WingetInfo {
    param(
        [int]$startLine = 8,
        [int]$width = 80
    )
    Render-Banner
    Set-CursorPosition -Row $startLine -Column 1
    foreach ($key in $global:WingetDownloadInfo.Keys) {
        $entry = $global:WingetDownloadInfo[$key]
        Write-Host "APP:" -ForegroundColor White -NoNewLine
        Write-Host " $($entry.App)" -ForegroundColor Blue
        Write-Host "URL:" -ForegroundColor White -NoNewLine
        Write-Host " $($entry.URL)" -ForegroundColor Green
    }
}

# Render-AppStatus displays the installation statuses.
function global:Render-AppStatus {
    param(
        [hashtable]$StatusTable,
        [array]$StatusKeys,
        [int]$startLine = 8,
        [int]$width = 80
    )
    Render-Banner
    Set-CursorPosition -Row $startLine -Column 1
    foreach ($key in $StatusKeys) {
        $status = $StatusTable[$key]
        $color = switch ($status) {
            "Success"    { "Green" }
            "Skipped"    { "Magenta" }
            "Failed"     { "Red" }
            "Installing" { "Cyan" }
            "Pending"    { "Yellow" }
            Default      { "Blue" }
        }
        Write-ClearedLine -Text ("{0,-25} {1,-15}" -f $key, $status) -Width $width -ForegroundColor $color
    }
}

# ====================
# LOAD ADDITIONAL APPS FROM WingetApps SECTION IN config.ini
# ====================
$wingetApps = @()
if ($config.WingetApps) {
    Write-Log "Loading winget apps from config.ini WingetApps section."
    foreach ($key in $config.WingetApps.Keys) {
        if ($key -match "Version" -or $key -match "Args") { continue }
        $appKey = $key
        $packageName = $config.WingetApps[$appKey].Trim()
        if ([string]::IsNullOrEmpty($packageName)) {
            Write-Log "Empty package name for key $appKey in WingetApps. Skipping."
            continue
        }
        $versionKey = "$appKey" + "Version"
        $argsKey    = "$appKey" + "Args"
        $version = ""
        $appArgs = ""
        if ($config.WingetApps.ContainsKey($versionKey)) {
            $version = $config.WingetApps[$versionKey].Trim()
        }
        if ($config.WingetApps.ContainsKey($argsKey)) {
            $appArgs = $config.WingetApps[$argsKey].Trim()
        }
        if ($version) {
            Write-Log "Retrieving details for $packageName via 'winget show' with version $version."
            $wingetOutput = winget show $packageName --version $version 2>&1
        }
        else {
            Write-Log "Retrieving details for $packageName via 'winget show'."
            $wingetOutput = winget show $packageName 2>&1
        }
        if (-not $wingetOutput) {
            Write-Log "No output returned from winget for $packageName."
            continue
        }
        $displayName = $packageName -replace '[^a-zA-Z]', ' '
        $displayName = $displayName -replace '(?i)\bbit\b',''
        $displayName = $displayName.Trim() -replace '\s+', ' '
        $installerUrl = $null
        $inInstallerSection = $false
        foreach ($line in $wingetOutput) {
            if ($line -match "^Installer:") {
                $inInstallerSection = $true
                continue
            }
            if ($inInstallerSection -and $line -match "Installer\s+Url:\s*(?<url>\S+)") {
                $installerUrl = $matches['url']
                break
            }
        }
        if (-not $installerUrl) {
            Write-Log "No installer URL found for $packageName in winget output."
            $global:ErrorLog += "No installer URL found for $packageName via winget show."
            continue
        }
        $destinationFolder = "C:\Watson-Electric\Installers"
        if (-not (Test-Path $destinationFolder)) {
            New-Item -ItemType Directory -Path $destinationFolder | Out-Null
            Write-Log "Created directory $destinationFolder."
        }
        $fileName = Split-Path $installerUrl -Leaf
        $destinationPath = Join-Path $destinationFolder $fileName

        # Clear previous winget info so only current app shows.
        $global:WingetDownloadInfo.Clear()
        $global:WingetDownloadInfo[$displayName] = @{
            App    = $displayName;
            URL    = $installerUrl;
            Status = ""
        }
        # Render only the winget info for the current app.
	Clear-Host
        Render-WingetInfo -startLine $tableStartLine -width 80

        Write-Log "Downloading installer for $displayName from $installerUrl to $destinationPath."
        try {
            Invoke-WebRequest -Uri $installerUrl -OutFile $destinationPath -UseBasicParsing -ErrorAction Stop
        } catch {
            Write-Log "Failed to download installer for $displayname $_"
            $global:ErrorLog += "Download error for $displayname $($_.Exception.Message)"
            continue
        }
        # Re-render the updated winget info (if needed, or simply clear it)
        $global:WingetDownloadInfo.Clear()
        Clear-Host
        Render-WingetInfo -startLine $tableStartLine -width 80

        $wingetApps += [PSCustomObject]@{
            Name      = $displayName
            Source    = $destinationPath
            Args      = $appArgs
            CheckPath = ""
        }
    }
} else {
    Write-Log "No WingetApps section found in config.ini."
}

# Once winget downloads are complete, clear winget info and render installation statuses.
$global:WingetDownloadInfo.Clear()
Render-AppStatus -StatusTable $appStatus -StatusKeys $appStatus.Keys -startLine $tableStartLine -width 80

foreach ($app in $wingetApps) {
    $appStatus[$app.Name] = "Pending"
}
$appsToInstall = $appsToInstall + $wingetApps

# ====================
# ENVIRONMENT CHECKS
# ====================
$inPS7 = $PSVersionTable.PSVersion.Major -ge 7
if (-not $inPS7) {
    if ((Get-ExecutionPolicy -Scope Process) -ne "Bypass") {
        Write-Host "Not running with Bypass exec policy. Relaunching..."
        Write-Log "Relaunching with Bypass execution policy."
        Start-Process -FilePath "powershell.exe" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
        exit
    }
    if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)) {
        Write-Warning "Need admin rights. Relaunching..."
        Write-Log "Relaunching as administrator."
        Start-Process -FilePath "powershell" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
        exit
    }
    $pwshPath = "C:\Program Files\PowerShell\7\pwsh.exe"
    if (Test-Path $pwshPath) {
        Write-Host "Found PS7. Switching over..."
        Write-Log "Switching to PS7."
        Start-Process -FilePath $pwshPath -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" 
        exit
    }
    else {
        Write-Host "PS7 is required. Detected version: $($PSVersionTable.PSVersion)" -ForegroundColor Yellow
        Write-Log "PS7 not found; current version: $($PSVersionTable.PSVersion)."
        if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
            Write-Error "Winget not found. Please update PS manually."
            Read-Host "Press Enter to exit..."
            exit 1
        }
        Write-Host "Updating winget..." -ForegroundColor Cyan
        Write-Log "Updating winget..."
        winget upgrade winget --silent --nowarn --verbose --force --disable-interactivity --accept-source-agreements
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Winget update installed successfully." -ForegroundColor Green
            Write-Log "Winget update installed successfully"
        }
        else {
            Write-Error "No winget updates available."
            Write-Log "No winget updates available."
        }
        Write-Host "Trying to install PS7 via winget..." -ForegroundColor Cyan
        Write-Log "Attempting to install PS7 via winget."
        winget install --id Microsoft.PowerShell --source winget --silent --accept-package-agreements --accept-source-agreements --force --verbose --nowarn --disable-interactivity
        if ($LASTEXITCODE -eq 0) {
            Write-Host "PS7 installation started. Please restart this script in PS7." -ForegroundColor Green
            Write-Log "PS7 installation initiated successfully."
        }
        else {
            Write-Error "PS7 install failed. Update Winget."
            Write-Log "PS7 install failed. Update Winget."
        }
        exit 1
    }
}

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$skipVPN = $false
try {
    $localIPObj = Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -ne "127.0.0.1" } | Select-Object -First 1
    if ($localIPObj -and $localIPObj.IPAddress -match "^192\.168\.(\d{1,3})\.\d+$") {
         $octet = [int]$Matches[1]
         if ($octet -ge 5 -and $octet -le 5) {
             Write-Log "Local IP $($localIPObj.IPAddress) in range; skipping VPN setup."
             $skipVPN = $true
         }
    }
}
catch {
    Write-Log "Could not get local IP. Proceeding with VPN tasks."
}

$tableStartLine = if ($config.General.TableStartLine) { [int]$config.General.TableStartLine } else { 8 }

# ====================
# TASK FUNCTIONS SECTION
# ====================
function Repair-VpnServices {
    Write-Log "Restarting VPN services..."
    $services = @("RasMan", "IKEEXT")
    foreach ($svc in $services) {
        try {
            Write-Log "Restarting $svc..."
            Restart-Service -Name $svc -Force -ErrorAction Stop
            Write-Log "$svc restarted."
        }
        catch {
            Write-Log "Could not restart $svc - $($_.Exception.Message)"
            $global:ErrorLog += "VPN service restart error ($svc): $($_.Exception.Message)"
        }
    }
}

function Setup-VpnConnection {
    param(
        [Parameter(Mandatory)]
        [string]$name,
        [Parameter(Mandatory)]
        [string]$address,
        [Parameter(Mandatory)]
        [string]$psk
    )
    if ($skipVPN) {
        Write-Log "Skipping VPN setup."
        return "Skipped"
    }
    Write-Log "Setting up VPN $name for server $address"
    $existingVpn = Get-VpnConnection -Name $name -ErrorAction SilentlyContinue
    if ($existingVpn) {
        Write-Log "VPN $name exists. Skipping."
        return "Skipped"
    }
    Write-Log "Adding VPN $name"
    Add-VpnConnection -Name $name `
                      -ServerAddress $address `
                      -TunnelType L2tp `
                      -AuthenticationMethod MSChapv2 `
                      -L2tpPsk $psk `
                      -Force `
                      -RememberCredential
    Write-Log "VPN $name added."
    Write-Log "Setting IPsec for VPN $name"
    Set-VpnConnectionIPsecConfiguration -ConnectionName $name `
        -AuthenticationTransformConstants SHA1 `
        -CipherTransformConstants DES3 `
        -EncryptionMethod DES3 `
        -IntegrityCheckMethod SHA1 `
        -DHGroup Group2 `
        -PfsGroup None `
        -Force
    Write-Log "VPN $name configured."
    return "Success"
}

function Join-Domain {
    $domain = "watson.watsonelectric.us"
    Write-Log "Checking domain membership..."
    $currentDomain = (Get-WmiObject Win32_ComputerSystem).Domain
    if ($currentDomain -and $currentDomain -ieq $domain) {
        Write-Log "Already in $domain. Skipping."
        return "Skipped"
    }
    Write-Log "Joining $domain..."
    try {
        $pass = $domainJoinPassword | ConvertTo-SecureString -AsPlainText -Force  
        $user = "$domain\$domainJoinUser"
        $credential = New-Object System.Management.Automation.PSCredential($user, $pass)
        Add-Computer -DomainName $domain -Credential $credential -ErrorAction Stop
        Write-Log "Joined $domain."
        return "Success"
    } catch {
        Write-Log "Domain join error: $($_.Exception.Message)"
        Write-Host "Domain join error: $($_.Exception.Message)" -ForegroundColor Red
        $global:ErrorLog += "Domain join error: $($_.Exception.Message)"
        return "Failed"
    }
}

function Configure-hibernation {
    Write-Log "Disabling hibernation..."
    try {
        POWERCFG /X -monitor-timeout-ac 0
        POWERCFG /X -monitor-timeout-dc 0
        POWERCFG /X -disk-timeout-ac 0
        POWERCFG /X -disk-timeout-dc 0
        POWERCFG /X -standby-timeout-ac 0
        POWERCFG /X -standby-timeout-dc 0
        POWERCFG /X -hibernate-timeout-ac 0
        POWERCFG /X -hibernate-timeout-dc 0
        POWERCFG /H OFF
        Write-Log "Hibernation off."
        return "Success"
    } catch {
        Write-Log "Hibernation error: $($_.Exception.Message)"
        Write-Host "Hibernation error: $($_.Exception.Message)" -ForegroundColor Red
        $global:ErrorLog += "Hibernation error: $($_.Exception.Message)"
        return "Failed"
    }
}

function Teams-Personal {
    Write-Log "Checking Teams installation..."
    $teams = Get-AppxPackage -Name MicrosoftTeams -AllUsers -ErrorAction SilentlyContinue
    if (-not $teams) {
        Write-Log "Teams not found. Skipping."
        return "Skipped"
    }
    try {
        Get-AppxPackage -Name MicrosoftTeams -AllUsers | Remove-AppxPackage -AllUsers -ErrorAction Stop
        Write-Log "Teams removed."
        return "Success"
    } catch {
        Write-Log "Teams removal error: $($_.Exception.Message)"
        Write-Host "Teams removal error: $($_.Exception.Message)" -ForegroundColor Red
        $global:ErrorLog += "Teams removal error: $($_.Exception.Message)"
        return "Failed"
    }
}

function Create-WATSONADMIN {
    Write-Log "Checking local admin user '$localAdminUser'..."
    try {
        $user = Get-LocalUser -Name $localAdminUser -ErrorAction SilentlyContinue
        if ($user) {
            Write-Log "User '$localAdminUser' exists. Skipping."
            return "Skipped"
        }
    } catch {
    }
    Write-Log "Creating local admin user '$localAdminUser'..."
    try {
        net user $localAdminUser $localAdminPassword /add /expires:never
        net localgroup administrators $localAdminUser /add
        Write-Log "User '$localAdminUser' created."
        return "Success"
    } catch {
        Write-Log "Local admin error: $($_.Exception.Message)"
        Write-Host "Local admin error: $($_.Exception.Message)" -ForegroundColor Red
        $global:ErrorLog += "Local admin error: $($_.Exception.Message)"
        return "Failed"
    }
}

# ====================
# INSTALL APPS SECTION
# ====================
$appStatus = @{}
foreach ($app in $appsToInstall) {
    $appStatus[$app.Name] = "Pending"
}

Clear-Host
Write-Host "Installing apps..." -ForegroundColor Cyan
Render-AppStatus -StatusTable $appStatus -StatusKeys $appStatus.Keys -startLine $tableStartLine

$tableHeight = 2 + $appsToInstall.Count
$detailedLineRow = $tableStartLine + $tableHeight + 1

foreach ($app in $appsToInstall) {
    if ($app.Name -eq "Acronis Backup Client") {
        if (Test-Path "C:\Program Files\Common Files\Acronis\ActiveProtection\active_protection_service.exe") {
            Write-Log "Acronis Backup Client is already installed. Skipping."
            $appStatus[$app.Name] = "Skipped"
            Render-AppStatus -StatusTable $appStatus -StatusKeys $appStatus.Keys -startLine $tableStartLine
            continue
        }
        $appStatus[$app.Name] = "Transforming MSI"
        Render-AppStatus -StatusTable $appStatus -StatusKeys $appStatus.Keys -startLine $tableStartLine
        Write-Log "Installing Acronis Backup Client using custom msiexec command..."
        $msiProcess = Start-Process -FilePath "msiexec.exe" `
            -ArgumentList '/i C:\Watson-Electric\Installers\Acronis\BackupClient64.msi TRANSFORMS=C:\Watson-Electric\Installers\Acronis\BackupClient64.msi.mst /l*v C:\Watson-Electric\Files\Acronis_log.txt /qn /norestart' `
            -Wait -PassThru -ErrorAction Stop
        if ($msiProcess.ExitCode -eq 0) {
            $appStatus[$app.Name] = "Success"
            Write-Log "Acronis Backup Client installed successfully."
        }
        else {
            $appStatus[$app.Name] = "Failed"
            Write-Log "Acronis Backup Client failed with exit code $($msiProcess.ExitCode)."
            $global:ErrorLog += "Acronis Backup Client error: Exit code $($msiProcess.ExitCode)"
        }
        Render-AppStatus -StatusTable $appStatus -StatusKeys $appStatus.Keys -startLine $tableStartLine
        continue
    }
    if ($app.Name -eq "Sophos") {
        if ((Test-Path "C:\Program Files\Sophos\Endpoint Defense\SEDService.exe") -or (Get-Service -Name "Sophos Endpoint Defense Service" -ErrorAction SilentlyContinue)) {
            Write-Log "$($app.Name) already installed. Skipping."
            $appStatus[$app.Name] = "Skipped"
            Render-AppStatus -StatusTable $appStatus -StatusKeys $appStatus.Keys -startLine $tableStartLine
            continue
        }
    }
    else {
        if (Test-Path $app.CheckPath) {
            Write-Log "$($app.Name) already installed. Skipping."
            $appStatus[$app.Name] = "Skipped"
            Render-AppStatus -StatusTable $appStatus -StatusKeys $appStatus.Keys -startLine $tableStartLine
            continue
        }
    }
    $appStatus[$app.Name] = "Installing"
    Render-AppStatus -StatusTable $appStatus -StatusKeys $appStatus.Keys -startLine $tableStartLine
    Set-CursorPosition -Row $detailedLineRow -Column 1
    Write-ClearedLine -Text ("Installing {0} from {1}" -f $app.Name, $app.Source) -Width 80 -ForegroundColor Cyan
    try {
        if (-not (Test-Path $app.Source)) {
            throw "Source not found: $($app.Source)"
        }
        Write-Log "Installing $($app.Name)..."
        $process = Start-Process -FilePath $app.Source -ArgumentList $app.Args -Wait -PassThru -ErrorAction Stop
        Start-Sleep -Seconds 5
        if ($process.ExitCode -eq 0 -or $process.ExitCode -eq 3010 -or (Test-Path $app.CheckPath)) {
            $statusNote = if ($process.ExitCode -eq 3010) { " (Reboot required)" } else { "" }
            $appStatus[$app.Name] = "Success"
            Write-Log "$($app.Name) installed successfully$statusNote"
        } else {
            $appStatus[$app.Name] = "Failed"
            Write-Log "$($app.Name) failed with exit code $($process.ExitCode)."
        }        
    }
    catch {
        $appStatus[$app.Name] = "Failed"
        Set-CursorPosition -Row $detailedLineRow -Column 1
        Write-ClearedLine -Text ("Error installing $($app.Name): $_") -Width 80 -ForegroundColor Red
        Write-Log "Error installing $($app.Name): $_"
        $global:ErrorLog += "App install error ($($app.Name)): $($_.Exception.Message)"
    }
    Render-AppStatus -StatusTable $appStatus -StatusKeys $appStatus.Keys -startLine $tableStartLine
}

Start-Sleep -Seconds 3

# ====================
# ADDITIONAL TASKS SECTION
# ====================
$CustomTaskStatus = @{
    "VPN Connect"            = "Attempting to connect"
    "Join Domain"            = "Attempting to join"
    "VPN Connection Setup"   = "Building adapter"
    "Disable Hibernation"    = "Disabling"
    "VPN Split Tunneling"    = "Disabling Default Gateway"
    "Remove MS Teams Personal" = "Uninstalling"
    "Create WATSON-ADMIN User"  = "Creating User"
}

$additionalTasks = @(
    @{ Name = "VPN Connection Setup"; Action = { Setup-VpnConnection -name $vpnName -address $serverAddress -psk $psk } },
    @{ Name = "VPN Split Tunneling"; Action = { 
            if ($skipVPN) { 
                Write-Log "Skipping VPN split tunneling." 
                return "Skipped" 
            } else { 
                Set-VpnConnection -Name $vpnName -SplitTunneling $true -Force; 
                return "Success" 
            } 
        } 
    },
    @{ Name = "VPN Connect"; Action = { 
            if ($skipVPN) { 
                Write-Log "Skipping VPN connect." 
                return "Skipped" 
            }
            $vpn = Get-VpnConnection -Name $vpnName
            if ($vpn.ConnectionStatus -eq "Connected") {
                Write-Log "VPN already connected. Skipping."
                return "Skipped"
            }
            Write-Log "Trying to connect VPN..."
            $maxAttempts = 5
            $attempt = 0
            $success = $false
            while ($attempt -lt $maxAttempts -and -not $success) {
                $attempt++
                Write-Log "VPN attempt $attempt"
                try {
                    $rasdialOutput = rasdial $vpnName $vpnUsername $vpnPassword 2>&1
                    Start-Sleep -Seconds 5
                    $vpn = Get-VpnConnection -Name $vpnName
                    if ($vpn.ConnectionStatus -eq "Connected") {
                        $success = $true
                    }
                    else {
                        if ($rasdialOutput -match "Remote server did not respond") {
                            Write-Log "Server did not respond, trying again..."
                        } else {
                            throw "VPN failed: $rasdialOutput"
                        }
                    }
                } catch {
                    if ($_ -match "Remote server did not respond") {
                        Write-Log "Server did not respond, trying again..."
                    } else {
                        throw $_
                    }
                }
            }
            if (-not $success) {
                throw "VPN did not connect after $maxAttempts tries."
            }
            return "Success"
        } 
    },
    @{ Name = "Join Domain"; Action = { Join-Domain } },
    @{ Name = "Disable Hibernation"; Action = { Configure-hibernation } },
    @{ Name = "Remove MS Teams Personal"; Action = { Teams-Personal } },
    @{ Name = "Create WATSON-ADMIN User"; Action = { Create-WATSONADMIN } }
)

if ($skipVPN) {
    Write-Log "Removing VPN tasks because local IP tells us so."
    $additionalTasks = $additionalTasks | Where-Object { $_.Name -notmatch "VPN" }
}

$taskStatus = @{}
foreach ($task in $additionalTasks) {
    $taskStatus[$task.Name] = "Pending"
}

Clear-Host
Write-Host "Running extra tasks..." -ForegroundColor Cyan
Render-AppStatus -StatusTable $taskStatus -StatusKeys $taskStatus.Keys -startLine $tableStartLine

$tableHeight = 2 + $additionalTasks.Count
$detailedLineRow = $tableStartLine + $tableHeight + 1

foreach ($task in $additionalTasks) {
    if ($CustomTaskStatus.ContainsKey($task.Name)) {
        $taskStatus[$task.Name] = $CustomTaskStatus[$task.Name]
        Render-AppStatus -StatusTable $taskStatus -StatusKeys $taskStatus.Keys -startLine $tableStartLine
    }
    $taskStatus[$task.Name] = "Installing"
    Render-AppStatus -StatusTable $taskStatus -StatusKeys $taskStatus.Keys -startLine $tableStartLine
    Set-CursorPosition -Row $detailedLineRow -Column 1
    Write-ClearedLine -Text ("Executing: {0}" -f $task.Name) -Width 80 -ForegroundColor Cyan
    try {
        Write-Log "Running task $($task.Name)..."
        $result = $task.Action.Invoke() | Out-Null
        if ($result) {
            $taskStatus[$task.Name] = $result
        }
        else {
            $taskStatus[$task.Name] = "Success"
        }
        Write-Log "Task '$($task.Name)' finished as $($taskStatus[$task.Name])."
    }
    catch {
        $taskStatus[$task.Name] = "Failed"
        Set-CursorPosition -Row $detailedLineRow -Column 1
        Write-ClearedLine -Text ("Error in {0}: {1}" -f $task.Name, $_) -Width 80 -ForegroundColor Red
        Write-Log "Task '$($task.Name)' error: $_"
        $global:ErrorLog += "Task error ($($task.Name)): $($_.Exception.Message)"
    }
    Render-AppStatus -StatusTable $taskStatus -StatusKeys $taskStatus.Keys -startLine $tableStartLine
}

Set-CursorPosition -Row ($detailedLineRow + 2) -Column 1

# ====================
# SUMMARY & LOGGING
# ====================
$global:ScriptEnd = Get-Date
$duration = New-TimeSpan -Start $global:ScriptStart -End $global:ScriptEnd

$hostname = $env:COMPUTERNAME
$privateIP = $localIPObj.IPAddress
try {
    $publicIP = (Invoke-RestMethod "https://api.ipify.org").Trim()
} catch {
    $publicIP = "Unavailable"
    $global:ErrorLog += "Public IP error: $($_.Exception.Message)"
}

$appSummary = ($appsToInstall | ForEach-Object { "`t$($_.Name): $($appStatus[$_.Name])" }) -join "`n"
$taskSummary = ($additionalTasks | ForEach-Object { "`t$($_.Name): $($taskStatus[$_.Name])" }) -join "`n"

$errorsEncountered = if ($global:ErrorLog.Count -gt 0) {
    $global:ErrorLog -join "`n"
} else {
    "None"
}

if ($global:RebootRequired.Count -gt 0) {
    Write-Log "`n⚠️  Reboot is required for the following apps: $($global:RebootRequired -join ', ')"
}

$summary = @"
********************
*Deployment Summary*
********************

Total Duration: $($duration.ToString())

Hostname: $hostname
Private IP: $privateIP
Public IP: $publicIP

App Installations:
$appSummary

Additional Tasks:
$taskSummary

Errors Encountered:
$errorsEncountered
"@

Write-Log $summary
Write-Host "Deployment complete. Summary written to log file: $logFile"
Read-Host "Press Enter to exit..."

# End logging
