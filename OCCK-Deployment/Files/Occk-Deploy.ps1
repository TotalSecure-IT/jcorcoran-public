# --- Begin Transcript for Verbose Logging ---
$logFile = Join-Path $PSScriptRoot "LOG.log"
Start-Transcript -Path $logFile -Append

# Determine if running in PowerShell 7
$inPS7 = $PSVersionTable.PSVersion.Major -ge 7

if (-not $inPS7) {
    # --- Relaunch with ExecutionPolicy Bypass if needed ---
    if ((Get-ExecutionPolicy -Scope Process) -ne "Bypass") {
        Write-Host "Current process execution policy is not Bypass. Relaunching with ExecutionPolicy Bypass..." -Verbose
        Start-Process -FilePath "powershell.exe" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
        exit
    }

    # --- Relaunch as Admin if not already ---
    if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)) {
        Write-Warning "This script must be run as an administrator. Relaunching..." -Verbose
        Start-Process -FilePath "powershell" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
        exit
    }

    # --- Check for PowerShell 7+ ---
    $pwshPath = "C:\Program Files\PowerShell\7\pwsh.exe"
    if (Test-Path $pwshPath) {
        Write-Host "PowerShell 7 detected at $pwshPath. Relaunching using PowerShell 7..." -Verbose
        Start-Process -FilePath $pwshPath -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" 
        exit
    }
    else {
        Write-Host "PowerShell 7 or later is required. Detected version: $($PSVersionTable.PSVersion)" -ForegroundColor Yellow
        if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
            Write-Error "Winget is not available. Please install winget or update PowerShell manually."
            Read-Host "Press Enter to exit..."
            exit 1
        }
        Write-Host "Attempting to install PowerShell 7 silently via winget..." -ForegroundColor Cyan
        winget install --id Microsoft.PowerShell --source winget --silent --accept-package-agreements --accept-source-agreements --force --verbose --nowarn --disable-interactivity
        if ($LASTEXITCODE -eq 0) {
            Write-Host "PowerShell 7 installation initiated successfully. Please restart this script in the new PowerShell 7 session." -ForegroundColor Green
        }
        else {
            Write-Error "Failed to install PowerShell 7 using winget. Please install it manually."
        }
        exit 1
    }
}

# Set UTF8 encoding for proper character handling
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

##############################################
# NEW: Determine Local IP and Set $skipVPN   #
##############################################
$skipVPN = $false
try {
    # Get the first non-loopback IPv4 address
    $localIPObj = Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -ne "127.0.0.1" } | Select-Object -First 1
    if ($localIPObj -and $localIPObj.IPAddress -match "^10\.1\.(\d{1,3})\.\d+$") {
         $octet = [int]$Matches[1]
         if ($octet -ge 0 -and $octet -le 20) {
             Write-Verbose "Local IP $($localIPObj.IPAddress) is within 10.1.0.0-10.1.20.0. Skipping VPN functions."
             $skipVPN = $true
         }
    }
}
catch {
    Write-Verbose "Could not determine local IP address. Proceeding with VPN functions."
}

# --- Helper: Render Banner ---
function Render-Banner {
    # Render banner at top always.
    Set-CursorPosition -Row 1 -Column 1
    try {
        $bannerFile = Join-Path $PSScriptRoot "banner.txt"
        if (Test-Path $bannerFile) {
            $bannerLines = Get-Content $bannerFile -Encoding UTF8
            $bannerColors = @("DarkBlue", "Blue", "DarkCyan", "DarkGreen", "Green", "Cyan")
            for ($i = 0; $i -lt $bannerLines.Count; $i++) {
                $color = if ($i -lt $bannerColors.Count) { $bannerColors[$i] } else { "Green" }
                Write-ClearedLine -Text $bannerLines[$i] -Width 80 -ForegroundColor $color
            }
        }
        else {
            throw "Banner file not found."
        }
    }
    catch {
        Write-ClearedLine -Text "HAMMERCLOUD" -Width 80 -ForegroundColor Green
    }
}

# --- Helper: ANSI Cursor Position ---
function Set-CursorPosition {
    param(
        [int]$Row,
        [int]$Column = 1
    )
    $esc = [char]27
    $ansiCode = "$esc[{0};{1}H" -f $Row, $Column
    Write-Host -NoNewLine $ansiCode
}

# --- Helper: Write Cleared Line ---
function Write-ClearedLine {
    param(
        [string]$Text,
        [int]$Width = 80,
        $ForegroundColor = $null
    )
    # Clear the current line (ESC [2K)
    Write-Host -NoNewLine "$([char]27)[2K"
    
    # Create padded text to ensure that previous content is overwritten
    $padded = $Text.PadRight($Width)
    
    if ($ForegroundColor) {
        Write-Host $padded -ForegroundColor $ForegroundColor
    }
    else {
        Write-Host $padded
    }
}

# --- Helper: Render App/Task/Update Status Table ---
function Render-AppStatus {
    param(
        [hashtable]$StatusTable,
        [array]$Keys,
        [int]$startLine = 8,
        [int]$width = 80
    )
    # Always render the banner at the top
    Render-Banner

    # Position cursor to where the table should start
    Set-CursorPosition -Row $startLine -Column 1

    # Print header for table
    Write-ClearedLine -Text ("{0,-25} {1,-15}" -f "Item", "Status") -Width $width
    Write-ClearedLine -Text "------------------------------" -Width $width

    # Print each row
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

#########################
# WINDOWS UPDATES TASK  #
#########################
# Run Windows Updates as the first task after PS7 installation.
$updateTableStartLine = 8
$updateStatus = @{ "Windows Updates" = "Pending" }

Clear-Host
Write-Host "Executing Windows Updates..." -ForegroundColor Cyan
Render-AppStatus -StatusTable $updateStatus -Keys $updateStatus.Keys -startLine $updateTableStartLine
$updateTableHeight = 2 + $updateStatus.Count
$detailedUpdateRow = $updateTableStartLine + $updateTableHeight + 1

try {
    $updateStatus["Windows Updates"] = "Installing"
    Render-AppStatus -StatusTable $updateStatus -Keys $updateStatus.Keys -startLine $updateTableStartLine

    Set-CursorPosition -Row $detailedUpdateRow -Column 1
    Write-ClearedLine -Text "Starting Windows Update scan..." -Width 80 -ForegroundColor Cyan
    Write-Verbose "Initiating Windows Update scan..."
    UsoClient StartScan
    Start-Sleep -Seconds 10

    Set-CursorPosition -Row $detailedUpdateRow -Column 1
    Write-ClearedLine -Text "Starting Windows Update download..." -Width 80 -ForegroundColor Cyan
    Write-Verbose "Initiating Windows Update download..."
    UsoClient StartDownload
    Start-Sleep -Seconds 10

    Set-CursorPosition -Row $detailedUpdateRow -Column 1
    Write-ClearedLine -Text "Starting Windows Update install..." -Width 80 -ForegroundColor Cyan
    Write-Verbose "Initiating Windows Update install..."
    UsoClient StartInstall
    Start-Sleep -Seconds 10

    Set-CursorPosition -Row $detailedUpdateRow -Column 1
    Write-ClearedLine -Text "Suppressing automatic reboot post updates..." -Width 80 -ForegroundColor Cyan
    Write-Verbose "Suppressing automatic reboot after updates..."
    $auKeyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"
    if (-not (Test-Path $auKeyPath)) {
        New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" -Name "AU" -Force | Out-Null
    }
    Set-ItemProperty -Path $auKeyPath -Name NoAutoRebootWithLoggedOnUsers -Value 1 -Type DWord

    $updateStatus["Windows Updates"] = "Success"
    Render-AppStatus -StatusTable $updateStatus -Keys $updateStatus.Keys -startLine $updateTableStartLine
    Write-Host "Windows Updates process completed." -ForegroundColor Green

} catch {
    $updateStatus["Windows Updates"] = "Failed"
    Render-AppStatus -StatusTable $updateStatus -Keys $updateStatus.Keys -startLine $updateTableStartLine
    Write-Host "Windows Updates process encountered an error: $_" -ForegroundColor Red
}

#################################
# --- Variables Section ---
$vpnName       = "OcckVPN"
$serverAddress = "70.167.136.2"
$psk           = "jRSSPBXdzyaOeeT"
$vpnUsername   = "onboardingscript"
$vpnPassword   = "nqUhk6^&jdH4WjP^6bNL"

#########################
# TASK FUNCTIONS BELOW  #
#########################

function Repair-VpnServices {
    Write-Verbose "Repairing VPN services: RasMan, IKEEXT..."
    $services = @("RasMan", "IKEEXT")
    foreach ($svc in $services) {
        try {
            Write-Verbose "Restarting service: $svc"
            Restart-Service -Name $svc -Force -ErrorAction Stop
            Write-Verbose "Service $svc restarted successfully."
        }
        catch {
            Write-Verbose "Failed to restart service $svc $($_.Exception.Message)"
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
        Write-Verbose "Skipping Setup-VpnConnection because VPN functions are disabled."
        return "Skipped"
    }
    
    Write-Verbose "Setting up VPN Connection: $name with server $address"
    $existingVpn = Get-VpnConnection -Name $name -ErrorAction SilentlyContinue
    if ($existingVpn) {
        Write-Verbose "VPN connection $name already exists. Skipping setup."
        return "Skipped"
    }
    
    Write-Verbose "Adding VPN connection: $name"
    Add-VpnConnection -Name $name `
                      -ServerAddress $address `
                      -TunnelType L2tp `
                      -AuthenticationMethod MSChapv2 `
                      -L2tpPsk $psk `
                      -Force `
                      -RememberCredential
    Write-Verbose "VPN connection $name added successfully."
    
    Write-Verbose "Configuring IPsec settings for VPN connection: $name"
    Set-VpnConnectionIPsecConfiguration -ConnectionName $name `
        -AuthenticationTransformConstants SHA1 `
        -CipherTransformConstants DES3 `
        -EncryptionMethod DES3 `
        -IntegrityCheckMethod SHA1 `
        -DHGroup Group2 `
        -PfsGroup None `
        -Force
    Write-Verbose "VPN connection $name configured successfully."
    return "Success"
}

function Join-Domain {
    $domain = "ad.occk.com"
    Write-Verbose "Checking current domain..."
    $currentDomain = (Get-WmiObject Win32_ComputerSystem).Domain
    if ($currentDomain -and $currentDomain -ieq $domain) {
        Write-Verbose "Computer is already joined to $domain. Skipping domain join."
        return "Skipped"
    }
    Write-Verbose "Attempting to join domain: $domain"
    try {
        $pass = "68Slappy4u" | ConvertTo-SecureString -AsPlainText -Force  
        $user = "$domain\isupport" 
        $credential = New-Object System.Management.Automation.PSCredential($user, $pass)
        Add-Computer -DomainName $domain -Credential $credential -ErrorAction Stop
        Write-Verbose "Successfully joined domain: $domain"
        return "Success"
    } catch {
        Write-Host "Error joining domain: $($_.Exception.Message)" -ForegroundColor Red
        return "Failed"
    }
}

function Configure-hibernation {
    Write-Verbose "Checking hibernation state..."
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
        Write-Verbose "Power settings updated and hibernation disabled."
        return "Success"
    } catch {
        Write-Host "Failed to update power settings: $($_.Exception.Message)" -ForegroundColor Red
        return "Failed"
    }
}

function Teams-Personal {
    Write-Verbose "Checking if Microsoft Teams (Personal) is installed..."
    $teams = Get-AppxPackage -Name MicrosoftTeams -AllUsers -ErrorAction SilentlyContinue
    if (-not $teams) {
        Write-Verbose "Microsoft Teams (Personal) is not installed. Skipping removal."
        return "Skipped"
    }
    try {
        Get-AppxPackage -Name MicrosoftTeams -AllUsers | Remove-AppxPackage -AllUsers -ErrorAction Stop
        Write-Verbose "Microsoft Teams (Personal) removed successfully."
        return "Success"
    } catch {
        Write-Host "Error removing Microsoft Teams (Personal): $($_.Exception.Message)" -ForegroundColor Red
        return "Failed"
    }
}

function Configure-Hostfile {
    Write-Verbose "Updating hosts file with required entries."
    try {
        $file = "C:\Windows\System32\drivers\etc\hosts"
        $entriesToAdd = @(
            "10.1.1.245   ad.occk.com",
            "10.1.1.245   DC"
        )
        
        $existingContent = Get-Content -Path $file -ErrorAction Stop
        
        $skippedCount = 0
        foreach ($entry in $entriesToAdd) {
            if ($existingContent -contains $entry) {
                Write-Verbose "Entry already exists: $entry. Skipping."
                $skippedCount++
            }
            else {
                Write-Verbose "Adding entry: $entry"
                Add-Content -Path $file -Value $entry
            }
        }
        if ($skippedCount -eq $entriesToAdd.Count) {
            return "Skipped"
        }
        Write-Verbose "Hosts file update complete."
        return "Success"
    }
    catch {
        Write-Host "Error updating hosts file: $($_.Exception.Message)" -ForegroundColor Red
        return "Failed"
    }
}

function Create-OCCKADMIN {
    Write-Verbose "Checking if local user 'occk-admin' exists..."
    try {
        $user = Get-LocalUser -Name "occk-admin" -ErrorAction SilentlyContinue
        if ($user) {
            Write-Verbose "Local user 'occk-admin' already exists. Skipping creation."
            return "Skipped"
        }
    } catch {
        # Fallback to net user if needed.
    }
    Write-Verbose "Attempting to create local user 'occk-admin' and add to Administrators group."
    try {
        net user occk-admin Mt-Dew-4-u /add /expires:never
        net localgroup administrators occk-admin /add
        Write-Verbose "Local user 'occk-admin' created and added to Administrators group."
        return "Success"
    } catch {
        Write-Host "Error creating local user or user already exists: $($_.Exception.Message)" -ForegroundColor Red
        return "Failed"
    }
}

function Copy-Links {
    Write-Verbose "Checking if shortcuts already exist on Public Desktop..."
    $destination = "C:\users\public\desktop"
    if (Test-Path (Join-Path $destination "C:\Users\Public\Desktop\Ascentis.url")) {
        Write-Verbose "Shortcuts already present on Public Desktop. Skipping copy."
        return "Skipped"
    }
    try {
        Copy-Item -Path "C:\Occk-Onboarding-Script\Files\Links\*" -Destination $destination -Force
        Write-Verbose "Shortcuts copied successfully to Public Desktop."
        return "Success"
    } catch {
        Write-Host "Error copying shortcuts to Public Desktop: $($_.Exception.Message)" -ForegroundColor Red
        return "Failed"
    }
}

###############################
# APPLICATION INSTALLATION    #
###############################
$appsToInstall = @(
    @{ Name = "Google Chrome"; Source = "C:\Occk-Onboarding-Script\Files\googlechromestandaloneenterprise64.msi"; Args = "/qn /norestart"; CheckPath = "C:\Program Files\Google\Chrome\Application\chrome.exe" },
    @{ Name = "Firefox"; Source = "C:\Occk-Onboarding-Script\Files\Firefox Setup 117.0.exe"; Args = "/S"; CheckPath = "C:\Program Files\Mozilla Firefox\firefox.exe" },
    @{ Name = "Adobe Reader DC"; Source = "C:\Occk-Onboarding-Script\Files\AcroRdrDC2300320284_en_US.exe"; Args = "/sAll /rs /msi EULA_ACCEPT=YES"; CheckPath = "C:\Program Files (x86)\Adobe\Acrobat Reader DC\Reader\AcroRd32.exe" },
    @{ Name = "Sophos"; Source = "C:\Occk-Onboarding-Script\Files\SophosSetup.exe"; Args = "--quiet"; CheckPath = "C:\Program Files\Sophos\Endpoint Defense\SEDService.exe" },
    @{ Name = "VSA X"; Source = "C:\Occk-Onboarding-Script\Files\windows_agent_x64.msi"; Args = "/qn /norestart"; CheckPath = "C:\Program Files\VSA X\agent.exe" },
    @{ Name = "Teams Bootstrapper"; Source = "C:\Occk-Onboarding-Script\Files\teamsbootstrapper.exe"; Args = "-p"; CheckPath = "C:\Program Files\WindowsApps\MSTeams_25044.2208.3471.2155_x64__8wekyb3d8bbwe\ms-teams.exe" }
)

$appStatus = @{}
foreach ($app in $appsToInstall) {
    $appStatus[$app.Name] = "Pending"
}

$tableStartLine = 8
Clear-Host
Write-Host "Installing applications..." -ForegroundColor Cyan
Render-AppStatus -StatusTable $appStatus -Keys $appStatus.Keys -startLine $tableStartLine

$tableHeight = 2 + $appsToInstall.Count
$detailedLineRow = $tableStartLine + $tableHeight + 1

foreach ($app in $appsToInstall) {
    if ($app.Name -eq "Sophos") {
        # Custom check: look for the file or the service
        if ((Test-Path "C:\Program Files\Sophos\Endpoint Defense\SEDService.exe") -or (Get-Service -Name "Sophos Endpoint Defense Service" -ErrorAction SilentlyContinue)) {
            Write-Verbose "$($app.Name) is already installed. Skipping."
            $appStatus[$app.Name] = "Skipped"
            Render-AppStatus -StatusTable $appStatus -Keys $appStatus.Keys -startLine $tableStartLine
            continue
        }
    }
    else {
        if (Test-Path $app.CheckPath) {
            Write-Verbose "$($app.Name) is already installed. Skipping."
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
            throw "Source file not found: $($app.Source)"
        }
        Write-Verbose "Starting installation of $($app.Name)..."
        $process = Start-Process -FilePath $app.Source -ArgumentList $app.Args -Wait -PassThru -ErrorAction Stop
        if ($process.ExitCode -eq 0) {
            $appStatus[$app.Name] = "Success"
            Write-Verbose "$($app.Name) installed successfully."
        }
        else {
            $appStatus[$app.Name] = "Failed"
            Write-Verbose "$($app.Name) installation failed with exit code $($process.ExitCode)."
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

#################################
# ADDITIONAL TASK EXECUTION     #
#################################
$additionalTasks = @(
    @{ Name = "VPN Connection Setup"; Action = { Setup-VpnConnection -name $vpnName -address $serverAddress -psk $psk } },
    @{ Name = "VPN Split Tunneling"; Action = { 
            if ($skipVPN) { 
                Write-Verbose "Skipping VPN Split Tunneling."; 
                return "Skipped" 
            } else { 
                Set-VpnConnection -Name $vpnName -SplitTunneling $true -Force; 
                return "Success" 
            } 
        } 
    },
    @{ Name = "VPN Connect"; Action = { 
            if ($skipVPN) { 
                Write-Verbose "Skipping VPN Connect."; 
                return "Skipped" 
            }
            $vpn = Get-VpnConnection -Name $vpnName
            if ($vpn.ConnectionStatus -eq "Connected") {
                Write-Verbose "VPN already connected. Skipping."
                return "Skipped"
            }
            Write-Verbose "Attempting VPN connect..."
            $maxAttempts = 5
            $attempt = 0
            $success = $false
            while ($attempt -lt $maxAttempts -and -not $success) {
                $attempt++
                Write-Verbose "VPN Connect attempt $attempt"
                try {
                    $rasdialOutput = rasdial $vpnName $vpnUsername $vpnPassword 2>&1
                    Start-Sleep -Seconds 5
                    $vpn = Get-VpnConnection -Name $vpnName
                    if ($vpn.ConnectionStatus -eq "Connected") {
                        $success = $true
                    }
                    else {
                        if ($rasdialOutput -match "Remote server did not respond") {
                            Write-Verbose "Remote server did not respond, retrying..."
                        } else {
                            throw "VPN failed to connect: $rasdialOutput"
                        }
                    }
                } catch {
                    if ($_ -match "Remote server did not respond") {
                        Write-Verbose "Remote server did not respond, retrying..."
                    } else {
                        throw $_
                    }
                }
            }
            if (-not $success) {
                throw "VPN failed to connect after $maxAttempts attempts."
            }
            return "Success"
        } 
    },
    @{ Name = "Join Domain"; Action = { Join-Domain } },
    @{ Name = "Disable Hibernation"; Action = { Configure-hibernation } },
    @{ Name = "Remove MS Teams Personal"; Action = { Teams-Personal } },
    @{ Name = "Update Hosts File"; Action = { Configure-Hostfile } },
    @{ Name = "Create OCCK-ADMIN User"; Action = { Create-OCCKADMIN } },
    @{ Name = "Copy Shortcuts"; Action = { Copy-Links } }
)

if ($skipVPN) {
    Write-Verbose "Removing VPN tasks from additional tasks due to local IP settings."
    $additionalTasks = $additionalTasks | Where-Object { $_.Name -notmatch "VPN" }
}

$taskStatus = @{}
foreach ($task in $additionalTasks) {
    $taskStatus[$task.Name] = "Pending"
}

Clear-Host
Write-Host "Executing additional tasks..." -ForegroundColor Cyan
Render-AppStatus -StatusTable $taskStatus -Keys $taskStatus.Keys -startLine $tableStartLine

$tableHeight = 2 + $additionalTasks.Count
$detailedLineRow = $tableStartLine + $tableHeight + 1

foreach ($task in $additionalTasks) {
    $taskStatus[$task.Name] = "Installing"
    Render-AppStatus -StatusTable $taskStatus -Keys $taskStatus.Keys -startLine $tableStartLine

    Set-CursorPosition -Row $detailedLineRow -Column 1
    Write-ClearedLine -Text ("Executing: {0}" -f $task.Name) -Width 80 -ForegroundColor Cyan

    try {
        Write-Verbose "Executing task: $($task.Name)..."
        $result = $task.Action.Invoke() | Out-Null
        if ($result) {
            $taskStatus[$task.Name] = $result
        }
        else {
            $taskStatus[$task.Name] = "Success"
        }
        Write-Verbose "Task '$($task.Name)' completed with status $($taskStatus[$task.Name])."
    }
    catch {
        $taskStatus[$task.Name] = "Failed"
        Set-CursorPosition -Row $detailedLineRow -Column 1
        Write-ClearedLine -Text ("Error in {0}: {1}" -f $task.Name, $_) -Width 80 -ForegroundColor Red
        Write-Verbose "Task '$($task.Name)' failed: $_"
    }
    Render-AppStatus -StatusTable $taskStatus -Keys $taskStatus.Keys -startLine $tableStartLine
}

Set-CursorPosition -Row ($detailedLineRow + 2) -Column 1
Read-Host "Press Enter to exit..."

# --- End Transcript ---
Stop-Transcript
