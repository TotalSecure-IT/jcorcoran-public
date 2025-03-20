# Start logging stuff to a file
$logFile = Join-Path $PSScriptRoot "output_log.txt"
Start-Transcript -Path $logFile -Append

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

# Load our config file (make sure this file is safe and not public)
$configFile = Join-Path $PSScriptRoot "config.ini"
if (-not (Test-Path $configFile)) {
    Write-Error "Config file not found. Bye."
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

# Build the list of apps to install from the INI file
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

# Check if we're on PowerShell 7
$inPS7 = $PSVersionTable.PSVersion.Major -ge 7

if (-not $inPS7) {
    # Relaunch with proper execution policy if needed
    if ((Get-ExecutionPolicy -Scope Process) -ne "Bypass") {
        Write-Host "Not running with Bypass exec policy. Relaunching..."
        Start-Process -FilePath "powershell.exe" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
        exit
    }

    # If not admin, restart as admin
    if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)) {
        Write-Warning "Need admin rights. Relaunching..."
        Start-Process -FilePath "powershell" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
        exit
    }

    # Try to switch to PS7 if it exists
    $pwshPath = "C:\Program Files\PowerShell\7\pwsh.exe"
    if (Test-Path $pwshPath) {
        Write-Host "Found PS7. Switching over..."
        Start-Process -FilePath $pwshPath -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
        exit
    }
    else {
        Write-Host "PS7 is required. Detected version: $($PSVersionTable.PSVersion)" -ForegroundColor Yellow
        if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
            Write-Error "Winget not found. Please update PS manually."
            Read-Host "Press Enter to exit..."
            exit 1
        }
        Write-Host "Trying to install PS7 via winget..." -ForegroundColor Cyan
        winget install --id Microsoft.PowerShell --source winget --silent --accept-package-agreements --accept-source-agreements --force --verbose --nowarn --disable-interactivity
        if ($LASTEXITCODE -eq 0) {
            Write-Host "PS7 installation started. Please restart this script in PS7." -ForegroundColor Green
        }
        else {
            Write-Error "PS7 install failed. Do it manually."
        }
        exit 1
    }
}

# Set UTF8 so we don't get weird characters
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# Figure out local IP so we know if VPN stuff should run
$skipVPN = $false
try {
    $localIPObj = Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -ne "127.0.0.1" } | Select-Object -First 1
    if ($localIPObj -and $localIPObj.IPAddress -match "^192\.168\.(\d{1,3})\.\d+$") {
         $octet = [int]$Matches[1]
         if ($octet -ge 5 -and $octet -le 5) {
             Write-Verbose "Local IP in range, so skipping VPN stuff."
             $skipVPN = $true
         }
    }
}
catch {
    Write-Verbose "Could not get local IP. Just doing VPN stuff."
}

# --- Basic functions below ---

# Updated Write-ClearedLine function that supports hex codes.
function Write-ClearedLine {
    param(
        [string]$Text,
        [int]$Width = 80,
        $ForegroundColor = $null
    )
    $clearLine = "$([char]27)[2K"
    $padded = $Text.PadRight($Width)
    if ($ForegroundColor -and $ForegroundColor -match "^#([0-9A-Fa-f]{6})$") {
         # If color is hex, convert to RGB values.
         $hex = $ForegroundColor.Substring(1)
         $r = [Convert]::ToInt32($hex.Substring(0,2),16)
         $g = [Convert]::ToInt32($hex.Substring(2,2),16)
         $b = [Convert]::ToInt32($hex.Substring(4,2),16)
         $ansiColor = "$([char]27)[38;2;${r};${g};${b}m"
         $reset = "$([char]27)[0m"
         Write-Host -NoNewLine "$clearLine$ansiColor$padded$reset"
    }
    elseif ($ForegroundColor) {
         Write-Host -NoNewLine "$clearLine$padded" -ForegroundColor $ForegroundColor
    }
    else {
         Write-Host -NoNewLine "$clearLine$padded"
    }
    Write-Host
}

function Set-CursorPosition {
    param(
        [int]$Row,
        [int]$Column = 1
    )
    $esc = [char]27
    $ansiCode = "$esc[{0};{1}H" -f $Row, $Column
    Write-Host -NoNewLine $ansiCode
}

function Render-Banner {
    Set-CursorPosition -Row 1 -Column 1
    try {
        $bannerFile = Join-Path $PSScriptRoot "banner.txt"
        if (Test-Path $bannerFile) {
            $bannerLines = Get-Content $bannerFile -Encoding UTF8
            # You can now use color names or hex codes here:
            $bannerColors = @("#F5F5DC", "#DEB887", "#E9967A", "#CD5C5C", "#DC143C", "B22222 ", "Red", "DarRed", "#800000")
            for ($i = 0; $i -lt $bannerLines.Count; $i++) {
                $color = if ($i -lt $bannerColors.Count) { $bannerColors[$i] } else { "#8B0000" }
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

function Render-AppStatus {
    param(
        [hashtable]$StatusTable,
        [array]$Keys,
        [int]$startLine = 8,
        [int]$width = 80
    )
    Render-Banner
    Set-CursorPosition -Row $startLine -Column 1
    Write-ClearedLine -Text ("{0,-25} {1,-15}" -f "Item", "Status") -Width $width
    Write-ClearedLine -Text "------------------------------" -Width $width
    foreach ($key in $Keys) {
        $status = $StatusTable[$key]
        $color = switch ($status) {
            "Success"    { "Green" }
            "Skipped"    { "Magenta" }
            "Failed"     { "Red" }
            "Installing" { "Cyan" }
            "Pending"    { "Yellow" }
            Default      { "White" }
        }
        Write-ClearedLine -Text ("{0,-25} {1,-15}" -f $key, $status) -Width $width -ForegroundColor $color
    }
}

# Get table start line from config (default to 8 if not set)
$tableStartLine = if ($config.General.TableStartLine) { [int]$config.General.TableStartLine } else { 8 }

# --- Windows Updates Task ---
$updateTableStartLine = $tableStartLine
$updateStatus = @{ "Windows Updates" = "Pending" }
Clear-Host
Write-Host "Doing Windows Updates..." -ForegroundColor Cyan
Render-AppStatus -StatusTable $updateStatus -Keys $updateStatus.Keys -startLine $updateTableStartLine
$updateTableHeight = 2 + $updateStatus.Count
$detailedUpdateRow = $updateTableStartLine + $updateTableHeight + 1
try {
    $updateStatus["Windows Updates"] = "Installing"
    Render-AppStatus -StatusTable $updateStatus -Keys $updateStatus.Keys -startLine $updateTableStartLine

    Set-CursorPosition -Row $detailedUpdateRow -Column 1
    Write-ClearedLine -Text "Starting update scan..." -Width 80 -ForegroundColor Cyan
    Write-Verbose "Starting update scan..."
    UsoClient StartScan
    Start-Sleep -Seconds 10

    Set-CursorPosition -Row $detailedUpdateRow -Column 1
    Write-ClearedLine -Text "Starting update download..." -Width 80 -ForegroundColor Cyan
    Write-Verbose "Starting update download..."
    UsoClient StartDownload
    Start-Sleep -Seconds 10

    Set-CursorPosition -Row $detailedUpdateRow -Column 1
    Write-ClearedLine -Text "Starting update install..." -Width 80 -ForegroundColor Cyan
    Write-Verbose "Starting update install..."
    UsoClient StartInstall
    Start-Sleep -Seconds 10

    Set-CursorPosition -Row $detailedUpdateRow -Column 1
    Write-ClearedLine -Text "Disabling auto reboot..." -Width 80 -ForegroundColor Cyan
    Write-Verbose "Disabling auto reboot..."
    $auKeyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"
    if (-not (Test-Path $auKeyPath)) {
        New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" -Name "AU" -Force | Out-Null
    }
    Set-ItemProperty -Path $auKeyPath -Name NoAutoRebootWithLoggedOnUsers -Value 1 -Type DWord

    $updateStatus["Windows Updates"] = "Success"
    Render-AppStatus -StatusTable $updateStatus -Keys $updateStatus.Keys -startLine $updateTableStartLine
    Write-Host "Updates done." -ForegroundColor Green
} catch {
    $updateStatus["Windows Updates"] = "Failed"
    Render-AppStatus -StatusTable $updateStatus -Keys $updateStatus.Keys -startLine $updateTableStartLine
    Write-Host "Update error: $_" -ForegroundColor Red
}

# --- Task Functions Section ---

function Repair-VpnServices {
    Write-Verbose "Restarting VPN services..."
    $services = @("RasMan", "IKEEXT")
    foreach ($svc in $services) {
        try {
            Write-Verbose "Restarting $svc..."
            Restart-Service -Name $svc -Force -ErrorAction Stop
            Write-Verbose "$svc restarted."
        }
        catch {
            Write-Verbose "Could not restart $svc $($_.Exception.Message)"
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
        Write-Verbose "Skipping VPN setup."
        return "Skipped"
    }
    Write-Verbose "Setting up VPN $name for server $address"
    $existingVpn = Get-VpnConnection -Name $name -ErrorAction SilentlyContinue
    if ($existingVpn) {
        Write-Verbose "VPN $name exists. Skipping."
        return "Skipped"
    }
    Write-Verbose "Adding VPN $name"
    Add-VpnConnection -Name $name `
                      -ServerAddress $address `
                      -TunnelType L2tp `
                      -L2tpPsk $psk `
                      -Force `
                      -RememberCredential
    Write-Verbose "VPN $name added."
    Write-Verbose "Setting IPsec for VPN $name"
    Set-VpnConnectionIPsecConfiguration -ConnectionName $name `
        -AuthenticationTransformConstants SHA1 `
        -CipherTransformConstants DES3 `
        -EncryptionMethod DES3 `
        -IntegrityCheckMethod SHA1 `
        -DHGroup Group2 `
        -PfsGroup None `
        -Force
    Write-Verbose "VPN $name configured."
    return "Success"
}

function Join-Domain {
    $domain = "kaccrra.local"
    Write-Verbose "Checking domain membership..."
    $currentDomain = (Get-WmiObject Win32_ComputerSystem).Domain
    if ($currentDomain -and $currentDomain -ieq $domain) {
        Write-Verbose "Already in $domain. Skipping."
        return "Skipped"
    }
    Write-Verbose "Joining $domain..."
    try {
        $pass = $domainJoinPassword | ConvertTo-SecureString -AsPlainText -Force  
        $user = "$domain\$domainJoinUser"
        $credential = New-Object System.Management.Automation.PSCredential($user, $pass)
        Add-Computer -DomainName $domain -Credential $credential -ErrorAction Stop
        Write-Verbose "Joined $domain."
        return "Success"
    } catch {
        Write-Host "Domain join error: $($_.Exception.Message)" -ForegroundColor Red
        return "Failed"
    }
}

function Configure-hibernation {
    Write-Verbose "Disabling hibernation..."
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
        Write-Verbose "Hibernation off."
        return "Success"
    } catch {
        Write-Host "Hibernation error: $($_.Exception.Message)" -ForegroundColor Red
        return "Failed"
    }
}

function Teams-Personal {
    Write-Verbose "Checking Teams installation..."
    $teams = Get-AppxPackage -Name MicrosoftTeams -AllUsers -ErrorAction SilentlyContinue
    if (-not $teams) {
        Write-Verbose "Teams not found. Skipping."
        return "Skipped"
    }
    try {
        Get-AppxPackage -Name MicrosoftTeams -AllUsers | Remove-AppxPackage -AllUsers -ErrorAction Stop
        Write-Verbose "Teams removed."
        return "Success"
    } catch {
        Write-Host "Teams removal error: $($_.Exception.Message)" -ForegroundColor Red
        return "Failed"
    }
}

<# We are not setting host entries at this time

function Configure-Hostfile {
    Write-Verbose "Updating hosts file..."
    try {
        $file = "C:\Windows\System32\drivers\etc\hosts"
        $entriesToAdd = @(
            "10.1.1.245   ad.CCA.com",
            "10.1.1.245   DC"
        )
        $existingContent = Get-Content -Path $file -ErrorAction Stop
        $skippedCount = 0
        foreach ($entry in $entriesToAdd) {
            if ($existingContent -contains $entry) {
                Write-Verbose "Entry '$entry' exists. Skipping."
                $skippedCount++
            }
            else {
                Write-Verbose "Adding '$entry'"
                Add-Content -Path $file -Value $entry
            }
        }
        if ($skippedCount -eq $entriesToAdd.Count) {
            return "Skipped"
        }
        Write-Verbose "Hosts file updated."
        return "Success"
    }
    catch {
        Write-Host "Hosts file error: $($_.Exception.Message)" -ForegroundColor Red
        return "Failed"
    }
}
#>

function Create-CCAADMIN {
    Write-Verbose "Checking local admin user '$localAdminUser'..."
    try {
        $user = Get-LocalUser -Name $localAdminUser -ErrorAction SilentlyContinue
        if ($user) {
            Write-Verbose "User '$localAdminUser' exists. Skipping."
            return "Skipped"
        }
    } catch {
        # Fallback if needed.
    }
    Write-Verbose "Creating local admin user '$localAdminUser'..."
    try {
        net user $localAdminUser $localAdminPassword /add /expires:never
        net localgroup administrators $localAdminUser /add
        Write-Verbose "User '$localAdminUser' created."
        return "Success"
    } catch {
        Write-Host "Local admin error: $($_.Exception.Message)" -ForegroundColor Red
        return "Failed"
    }
}

<# We do not need to copy links at this time
function Copy-Links {
    Write-Verbose "Checking for desktop shortcuts..."
    $destination = "C:\users\public\desktop"
    if (Test-Path (Join-Path $destination "C:\Users\Public\Desktop\Ascentis.url")) {
        Write-Verbose "Shortcuts exist. Skipping."
        return "Skipped"
    }
    try {
        Copy-Item -Path "C:\CCA-Deployment\Files\Links\*" -Destination $destination -Force
        Write-Verbose "Shortcuts copied."
        return "Success"
    } catch {
        Write-Host "Copy shortcuts error: $($_.Exception.Message)" -ForegroundColor Red
        return "Failed"
    }
}
#>

# --- Install Apps Section ---
$appStatus = @{}
foreach ($app in $appsToInstall) {
    $appStatus[$app.Name] = "Pending"
}

Clear-Host
Write-Host "Installing apps..." -ForegroundColor Cyan
Render-AppStatus -StatusTable $appStatus -Keys $appStatus.Keys -startLine $tableStartLine

$tableHeight = 2 + $appsToInstall.Count
$detailedLineRow = $tableStartLine + $tableHeight + 1

foreach ($app in $appsToInstall) {
    if ($app.Name -eq "Sophos") {
        if ((Test-Path "C:\Program Files\Sophos\Endpoint Defense\SEDService.exe") -or (Get-Service -Name "Sophos Endpoint Defense Service" -ErrorAction SilentlyContinue)) {
            Write-Verbose "$($app.Name) already installed. Skipping."
            $appStatus[$app.Name] = "Skipped"
            Render-AppStatus -StatusTable $appStatus -Keys $appStatus.Keys -startLine $tableStartLine
            continue
        }
    }
    else {
        if (Test-Path $app.CheckPath) {
            Write-Verbose "$($app.Name) already installed. Skipping."
            $appStatus[$app.Name] = "Skipped"
            Render-AppStatus -StatusTable $appStatus -Keys $appStatus.Keys -startLine $tableStartLine
            continue
        }
    }
    $appStatus[$app.Name] = "Installing"
    Render-AppStatus -StatusTable $appStatus -Keys $appStatus.Keys -startLine $tableStartLine
    Set-CursorPosition -Row $detailedLineRow -Column 1
    Write-ClearedLine -Text ("Installing {0} from {1}" -f $app.Name, $app.Source) -Width 80 -ForegroundColor Cyan
    try {
        if (-not (Test-Path $app.Source)) {
            throw "Source not found: $($app.Source)"
        }
        Write-Verbose "Installing $($app.Name)..."
        $process = Start-Process -FilePath $app.Source -ArgumentList $app.Args -Wait -PassThru -ErrorAction Stop
        if ($process.ExitCode -eq 0) {
            $appStatus[$app.Name] = "Success"
            Write-Verbose "$($app.Name) installed."
        }
        else {
            $appStatus[$app.Name] = "Failed"
            Write-Verbose "$($app.Name) failed with exit code $($process.ExitCode)."
        }
    }
    catch {
        $appStatus[$app.Name] = "Failed"
        Set-CursorPosition -Row $detailedLineRow -Column 1
        Write-ClearedLine -Text ("Error installing $($app.Name): $_") -Width 80 -ForegroundColor Red
        Write-Verbose "Error installing $($app.Name): $_"
    }
    Render-AppStatus -StatusTable $appStatus -Keys $appStatus.Keys -startLine $tableStartLine
}

Start-Sleep -Seconds 3

# --- Additional Tasks Section ---
$additionalTasks = @(
    @{ Name = "VPN Connection Setup"; Action = { Setup-VpnConnection -name $vpnName -address $serverAddress -psk $psk } },
    @{ Name = "VPN Split Tunneling"; Action = { 
            if ($skipVPN) { 
                Write-Verbose "Skipping VPN split tunneling." 
                return "Skipped" 
            } else { 
                Set-VpnConnection -Name $vpnName -SplitTunneling $true -Force; 
                return "Success" 
            } 
        } 
    },
    @{ Name = "VPN Connect"; Action = { 
            if ($skipVPN) { 
                Write-Verbose "Skipping VPN connect." 
                return "Skipped" 
            }
            $vpn = Get-VpnConnection -Name $vpnName
            if ($vpn.ConnectionStatus -eq "Connected") {
                Write-Verbose "VPN already connected. Skipping."
                return "Skipped"
            }
            Write-Verbose "Trying to connect VPN..."
            $maxAttempts = 5
            $attempt = 0
            $success = $false
            while ($attempt -lt $maxAttempts -and -not $success) {
                $attempt++
                Write-Verbose "VPN attempt $attempt"
                try {
                    $rasdialOutput = rasdial $vpnName $vpnUsername $vpnPassword 2>&1
                    Start-Sleep -Seconds 5
                    $vpn = Get-VpnConnection -Name $vpnName
                    if ($vpn.ConnectionStatus -eq "Connected") {
                        $success = $true
                    }
                    else {
                        if ($rasdialOutput -match "Remote server did not respond") {
                            Write-Verbose "Server did not respond, trying again..."
                        } else {
                            throw "VPN failed: $rasdialOutput"
                        }
                    }
                } catch {
                    if ($_ -match "Remote server did not respond") {
                        Write-Verbose "Server did not respond, trying again..."
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
    #@{ Name = "Update Hosts File"; Action = { Configure-Hostfile } }, uncomment when needed
    @{ Name = "Create CCA-ADMIN User"; Action = { Create-CCAADMIN } } #if copy shortcuts is used, you must add a comma to the end of this line
    #@{ Name = "Copy Shortcuts"; Action = { Copy-Links } } uncomment when needed
)

if ($skipVPN) {
    Write-Verbose "Removing VPN tasks because local IP tells us so."
    $additionalTasks = $additionalTasks | Where-Object { $_.Name -notmatch "VPN" }
}

$taskStatus = @{}
foreach ($task in $additionalTasks) {
    $taskStatus[$task.Name] = "Pending"
}

Clear-Host
Write-Host "Running extra tasks..." -ForegroundColor Cyan
Render-AppStatus -StatusTable $taskStatus -Keys $taskStatus.Keys -startLine $tableStartLine

$tableHeight = 2 + $additionalTasks.Count
$detailedLineRow = $tableStartLine + $tableHeight + 1

foreach ($task in $additionalTasks) {
    $taskStatus[$task.Name] = "Installing"
    Render-AppStatus -StatusTable $taskStatus -Keys $taskStatus.Keys -startLine $tableStartLine
    Set-CursorPosition -Row $detailedLineRow -Column 1
    Write-ClearedLine -Text ("Executing: {0}" -f $task.Name) -Width 80 -ForegroundColor Cyan
    try {
        Write-Verbose "Running task $($task.Name)..."
        $result = $task.Action.Invoke() | Out-Null
        if ($result) {
            $taskStatus[$task.Name] = $result
        }
        else {
            $taskStatus[$task.Name] = "Success"
        }
        Write-Verbose "Task '$($task.Name)' finished as $($taskStatus[$task.Name])."
    }
    catch {
        $taskStatus[$task.Name] = "Failed"
        Set-CursorPosition -Row $detailedLineRow -Column 1
        Write-ClearedLine -Text ("Error in {0}: {1}" -f $task.Name, $_) -Width 80 -ForegroundColor Red
        Write-Verbose "Task '$($task.Name)' error: $_"
    }
    Render-AppStatus -StatusTable $taskStatus -Keys $taskStatus.Keys -startLine $tableStartLine
}

Set-CursorPosition -Row ($detailedLineRow + 2) -Column 1
Read-Host "Press Enter to exit..."

# End logging
Stop-Transcript
