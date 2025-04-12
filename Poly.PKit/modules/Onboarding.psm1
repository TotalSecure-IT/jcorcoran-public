<#
.SYNOPSIS
    Automates the onboarding process using a company-specific config.ini.
.DESCRIPTION
    This module reads the given config.ini (passed via -CompanyIni) and performs:
      • Config parsing (supports sections: [General], [Credentials], [WingetApps], [Apps],
        [Compressed Files], and [Commands])
      • Downloading & silent installation of applications via winget as well as local installers
      • Extraction of compressed files
      • Execution of command strings from the [Commands] section
      • Live, colored status updates and logging (non-interactive)
.EXAMPLE
    Start-Onboarding -CompanyIni "C:\Users\isupport\Desktop\test\configs\OCCK\config.ini"
#>

#region Global Variables & Logging

$script:CommandFailures = 0
$script:CommandSuccesses  = 0
$script:WingetAppsStatus = @{}
$script:LocalAppsStatus  = @{}
$script:ArchivesStatus   = @{}

$script:LogFile = $null
$script:WorkingDir = $null
$script:UniversalInstallersDir = $null

function Write-PKitLog {
    <#
    .SYNOPSIS
         Writes a timestamped log entry.
    #>
    param(
        [Parameter(Mandatory=$true)][string]$Message
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $entry = "$timestamp - $Message"
    if ($script:LogFile) {
        Add-Content -Path $script:LogFile -Value $entry
    }
    Write-Host $entry
}

#endregion Global Variables & Logging

#region Config Parsing

function Convert-IniToHashtable {
    <#
    .SYNOPSIS
         Converts an INI file to a hashtable.
    .DESCRIPTION
         Reads the INI file at the given path and builds a nested hashtable.
    .EXAMPLE
         $config = Convert-IniToHashtable -Path "C:\Path\config.ini"
    #>
    param(
        [Parameter(Mandatory=$true)][string]$Path
    )
    if (-not (Test-Path $Path)) {
        Write-PKitLog "Config file not found at $Path. Exiting."
        throw "Config file not found."
    }
    $ini = @{}
    $currentSection = ""
    foreach ($line in Get-Content $Path) {
        $line = $line.Trim()
        if ($line -match '^\[(.+)\]$') {
            $currentSection = $matches[1]
            $ini[$currentSection] = @{}
        }
        elseif ($line -match '^(.*?)=(.*)$') {
            $key = $matches[1].Trim()
            $value = $matches[2].Trim().Trim('"')
            if ($currentSection) {
                $ini[$currentSection][$key] = $value
            }
            else {
                $ini[$key] = $value
            }
        }
    }
    return $ini
}

#endregion Config Parsing

#region Console UI Functions

function Invoke-Banner {
    <#
    .SYNOPSIS
         Displays a banner file with color.
    .EXAMPLE
         Invoke-Banner -BannerPath "C:\Path\banner.txt"
    #>
    param(
        [Parameter(Mandatory=$true)][string]$BannerPath
    )
    if (Test-Path $BannerPath) {
        $bannerLines = Get-Content $BannerPath -Encoding UTF8
        $colors = @("DarkBlue", "Blue", "DarkCyan", "DarkGreen", "Green", "Cyan", "Gray", "DarkGray", "Green", "DarkGreen")
        for ($i = 0; $i -lt $bannerLines.Count; $i++) {
            $color = if ($i -lt $colors.Count) { $colors[$i] } else { "Yellow" }
            Write-Host $bannerLines[$i] -ForegroundColor $color
        }
    }
    else {
        Write-PKitLog "Banner file not found at $BannerPath."
    }
}

function Invoke-AppStatus {
    <#
    .SYNOPSIS
         Displays app installation statuses.
    #>
    param(
        [hashtable]$WingetStatus,
        [hashtable]$LocalStatus,
        [hashtable]$ArchiveStatus
    )
    Write-Host "---------------------------------------------"
    Write-Host "Installation Status:" -ForegroundColor Cyan
    foreach ($key in $WingetStatus.Keys) {
        $status = $WingetStatus[$key]
        if ($status -eq "Success") { Write-Host "$key : $status" -ForegroundColor Green }
        elseif ($status -eq "Failed") { Write-Host "$key : $status" -ForegroundColor Red }
        else { Write-Host "$key : $status" -ForegroundColor Yellow }
    }
    foreach ($key in $LocalStatus.Keys) {
        $status = $LocalStatus[$key]
        if ($status -eq "Success") { Write-Host "$key : $status" -ForegroundColor Green }
        elseif ($status -eq "Failed") { Write-Host "$key : $status" -ForegroundColor Red }
        else { Write-Host "$key : $status" -ForegroundColor Yellow }
    }
    foreach ($key in $ArchiveStatus.Keys) {
        $status = $ArchiveStatus[$key]
        if ($status -eq "Success") { Write-Host "$key : $status" -ForegroundColor Green }
        elseif ($status -eq "Failed") { Write-Host "$key : $status" -ForegroundColor Red }
        else { Write-Host "$key : $status" -ForegroundColor Yellow }
    }
}

function Invoke-CommandsStatus {
    <#
    .SYNOPSIS
         Displays command execution status as “[ failures | successes ]”.
    #>
    $failStr = "$script:CommandFailures"
    $succStr = "$script:CommandSuccesses"
    $formatted = "[ $failStr | $succStr ]"
    Write-Host $formatted -ForegroundColor White
    Write-Host ("Failures: " + $failStr) -ForegroundColor Red -NoNewline
    Write-Host "   " -NoNewline
    Write-Host ("Successes: " + $succStr) -ForegroundColor Green
}

#endregion Console UI Functions

#region WingetApps Installation

function Install-WingetApp {
    <#
    .SYNOPSIS
         Installs a single Winget application.
    .DESCRIPTION
         Uses winget show to retrieve the installer URL, downloads the installer to the universal folder,
         and silently runs the installer.
    .EXAMPLE
         Install-WingetApp -AppName "Google.Chrome" -AppVersion "" -AppArgs "/qn"
    #>
    param(
        [Parameter(Mandatory=$true)][string]$AppName,
        [string]$AppVersion,
        [string]$AppArgs
    )
    Write-PKitLog "Processing Winget app: $AppName"
    $wingetCmd = "winget show `"$AppName`""
    if ($AppVersion) { $wingetCmd += " --version $AppVersion" }
    Write-PKitLog "Executing command: $wingetCmd"
    try {
        $wingetOutput = Invoke-Expression $wingetCmd 2>&1
    }
    catch {
        Write-PKitLog "Failed to execute winget show for $AppName. Marking as Failed."
        $script:WingetAppsStatus[$AppName] = "Failed"
        return
    }
    $installerUrl = $null
    foreach ($line in $wingetOutput) {
        if ($line -match "Installer\s+Url:\s*(\S+)") {
            $installerUrl = $matches[1]
            break
        }
    }
    if (-not $installerUrl) {
        Write-PKitLog "No installer URL found for $AppName. Marking as Failed."
        $script:WingetAppsStatus[$AppName] = "Failed"
        return
    }
    Write-PKitLog "Found installer URL for $AppName: $installerUrl"
    $filename = Split-Path $installerUrl -Leaf
    $destinationPath = Join-Path $script:UniversalInstallersDir $filename
    if (-not (Test-Path $destinationPath)) {
        Write-PKitLog "Downloading installer for $AppName..."
        try {
            Invoke-WebRequest -Uri $installerUrl -OutFile $destinationPath -UseBasicParsing
        }
        catch {
            Write-PKitLog "Download failed for $AppName. Marking as Failed."
            $script:WingetAppsStatus[$AppName] = "Failed"
            return
        }
    }
    else { Write-PKitLog "Installer file already exists for $AppName." }
    Write-PKitLog "Installing $AppName from $destinationPath..."
    try {
        $proc = Start-Process -FilePath $destinationPath -ArgumentList $AppArgs -Wait -PassThru -WindowStyle Hidden
        if ($proc.ExitCode -eq 0 -or $proc.ExitCode -eq 3010) {
            Write-PKitLog "$AppName installed successfully."
            $script:WingetAppsStatus[$AppName] = "Success"
        } else {
            Write-PKitLog "$AppName installation failed with exit code $($proc.ExitCode)."
            $script:WingetAppsStatus[$AppName] = "Failed"
        }
    }
    catch {
        Write-PKitLog "Exception during installation of $AppName: $_"
        $script:WingetAppsStatus[$AppName] = "Failed"
    }
    Invoke-AppStatus -WingetStatus $script:WingetAppsStatus -LocalStatus @{} -ArchiveStatus @{}
}

function Install-WingetApps {
    <#
    .SYNOPSIS
         Processes all Winget apps as defined in the config.
    .EXAMPLE
         Install-WingetApps -WingetSection $config.WingetApps
    #>
    param(
        [Parameter(Mandatory=$true)][hashtable]$WingetSection
    )
    Write-PKitLog "Starting Winget apps installation..."
    foreach ($key in $WingetSection.Keys) {
        if ($key -match "^(App\d+)$") {
            $appNumber = $matches[1]
            $appName = $WingetSection[$appNumber]
            $appVersion = $WingetSection["$appNumber" + "Version"]
            $appArgs = $WingetSection["$appNumber" + "Args"]
            if ($appName) {
                Install-WingetApp -AppName $appName -AppVersion $appVersion -AppArgs $appArgs
            }
        }
    }
}

#endregion WingetApps Installation

#region Local Apps Installation

function Install-LocalApp {
    <#
    .SYNOPSIS
         Installs a single local application.
    .DESCRIPTION
         Checks if the application is already installed via AppCheckPath,
         then runs the installer from the local source.
    .EXAMPLE
         Install-LocalApp -AppName "VSA X" -AppSource "C:\Installers\agent.msi" `
            -AppArgs "/qn" -AppCheckPath "C:\Program Files\VSA X\app.exe"
    #>
    param(
        [Parameter(Mandatory=$true)][string]$AppName,
        [Parameter(Mandatory=$true)][string]$AppSource,
        [string]$AppArgs,
        [string]$AppCheckPath
    )
    Write-PKitLog "Processing local app: $AppName"
    if ($AppCheckPath -and (Test-Path $AppCheckPath)) {
        Write-PKitLog "$AppName is already installed. Skipping installation."
        $script:LocalAppsStatus[$AppName] = "Skipped"
        return
    }
    if (-not (Test-Path $AppSource)) {
        Write-PKitLog "Installer for $AppName not found at $AppSource. Marking as Failed."
        $script:LocalAppsStatus[$AppName] = "Failed"
        return
    }
    Write-PKitLog "Installing $AppName using source $AppSource..."
    try {
        $proc = Start-Process -FilePath $AppSource -ArgumentList $AppArgs -Wait -PassThru -WindowStyle Hidden
        if ($proc.ExitCode -eq 0 -or $proc.ExitCode -eq 3010) {
            Write-PKitLog "$AppName installed successfully."
            $script:LocalAppsStatus[$AppName] = "Success"
        }
        else {
            Write-PKitLog "$AppName installation failed with exit code $($proc.ExitCode)."
            $script:LocalAppsStatus[$AppName] = "Failed"
        }
    }
    catch {
        Write-PKitLog "Exception during installation of $AppName: $_"
        $script:LocalAppsStatus[$AppName] = "Failed"
    }
    Invoke-AppStatus -WingetStatus @{} -LocalStatus $script:LocalAppsStatus -ArchiveStatus @{}
}

function Install-LocalApps {
    <#
    .SYNOPSIS
         Processes all local apps from the config.
    .EXAMPLE
         Install-LocalApps -AppsSection $config.Apps
    #>
    param(
        [Parameter(Mandatory=$true)][hashtable]$AppsSection
    )
    Write-PKitLog "Starting local apps installation..."
    foreach ($key in $AppsSection.Keys) {
        if ($key -match "^(App\d+Name)$") {
            $num = $matches[1] -replace "Name", ""
            $appName = $AppsSection["$num" + "Name"]
            $appSource = $AppsSection["$num" + "Source"]
            $appArgs = $AppsSection["$num" + "Args"]
            $appCheckPath = $AppsSection["$num" + "CheckPath"]
            if ($appName) {
                Install-LocalApp -AppName $appName -AppSource $appSource -AppArgs $appArgs -AppCheckPath $appCheckPath
            }
        }
    }
}

#endregion Local Apps Installation

#region Archives Extraction

function Invoke-Archive {
    <#
    .SYNOPSIS
         Extracts a single archive file.
    .DESCRIPTION
         Based on the file extension (.zip, .rar, .7z, .tar), extracts the archive to the destination.
    .EXAMPLE
         Invoke-Archive -ArchivePath "C:\Installers\app.zip" -DestinationPath "C:\Extracted"
    #>
    param(
        [Parameter(Mandatory=$true)][string]$ArchivePath,
        [Parameter(Mandatory=$true)][string]$DestinationPath,
        [string]$ExtraArgs
    )
    if (-not (Test-Path $ArchivePath)) {
        Write-PKitLog "Archive not found: $ArchivePath. Marking as Failed."
        $script:ArchivesStatus[$ArchivePath] = "Failed"
        return
    }
    Write-PKitLog "Extracting archive: $ArchivePath to $DestinationPath"
    try {
        $ext = [System.IO.Path]::GetExtension($ArchivePath).ToLower()
        switch ($ext) {
            ".zip" {
                Expand-Archive -Path $ArchivePath -DestinationPath $DestinationPath -Force
                $script:ArchivesStatus[$ArchivePath] = "Success"
            }
            ".rar" {
                if (Get-Command unrar -ErrorAction SilentlyContinue) {
                    unrar x $ArchivePath $DestinationPath $ExtraArgs
                    $script:ArchivesStatus[$ArchivePath] = "Success"
                }
                else {
                    Write-PKitLog "No unrar utility found for $ArchivePath."
                    $script:ArchivesStatus[$ArchivePath] = "Failed"
                }
            }
            ".7z" {
                if (Get-Command 7z -ErrorAction SilentlyContinue) {
                    7z x $ArchivePath -o$DestinationPath $ExtraArgs
                    $script:ArchivesStatus[$ArchivePath] = "Success"
                }
                else {
                    Write-PKitLog "No 7z utility found for $ArchivePath."
                    $script:ArchivesStatus[$ArchivePath] = "Failed"
                }
            }
            ".tar" {
                if (Get-Command tar -ErrorAction SilentlyContinue) {
                    tar -xf $ArchivePath -C $DestinationPath
                    $script:ArchivesStatus[$ArchivePath] = "Success"
                }
                else {
                    Write-PKitLog "No tar utility found for $ArchivePath."
                    $script:ArchivesStatus[$ArchivePath] = "Failed"
                }
            }
            default {
                Write-PKitLog "Unsupported archive type: $ext for file $ArchivePath."
                $script:ArchivesStatus[$ArchivePath] = "Failed"
            }
        }
    }
    catch {
        Write-PKitLog "Exception extracting $ArchivePath: $_"
        $script:ArchivesStatus[$ArchivePath] = "Failed"
    }
    Invoke-AppStatus -WingetStatus @{} -LocalStatus @{} -ArchiveStatus $script:ArchivesStatus
}

function Invoke-Archives {
    <#
    .SYNOPSIS
         Processes all compressed files defined in the config.
    .EXAMPLE
         Invoke-Archives -ArchivesSection $config.'Compressed Files'
    #>
    param(
        [Parameter(Mandatory=$true)][hashtable]$ArchivesSection
    )
    Write-PKitLog "Starting extraction of compressed files..."
    foreach ($key in $ArchivesSection.Keys) {
        if ($key -match "^(Archive\d+Name)$") {
            $num = $matches[1] -replace "Name", ""
            $archivePath = $ArchivesSection["$num" + "Name"]
            $destinationPath = $ArchivesSection["$num" + "Destination"]
            $extraArgs = $ArchivesSection["$num" + "Args"]
            Invoke-Archive -ArchivePath $archivePath -DestinationPath $destinationPath -ExtraArgs $extraArgs
        }
    }
}

#endregion Archives Extraction

#region Commands Execution

function Invoke-Commands {
    <#
    .SYNOPSIS
         Executes command strings from the [Commands] section.
    .EXAMPLE
         Invoke-Commands -CommandsSection $config.Commands
    #>
    param(
        [Parameter(Mandatory=$true)][hashtable]$CommandsSection
    )
    Write-PKitLog "Executing commands from [Commands] section..."
    foreach ($key in $CommandsSection.Keys) {
        $cmd = $CommandsSection[$key]
        if ([string]::IsNullOrEmpty($cmd)) { continue }
        Write-PKitLog "Executing command [$key]: $cmd"
        try {
            # Invoke-Expression is used by design.
            Invoke-Expression $cmd
            $script:CommandSuccesses++
        }
        catch {
            Write-PKitLog "Command [$key] failed: $_"
            $script:CommandFailures++
        }
        Invoke-CommandsStatus
    }
}

#endregion Commands Execution

#region Final Summary

function Invoke-Summary {
    <#
    .SYNOPSIS
         Presents the final summary of the onboarding process.
    .EXAMPLE
         Invoke-Summary -StartTime $ScriptStart -EndTime (Get-Date)
    #>
    param(
        [Parameter(Mandatory=$true)][datetime]$StartTime,
        [Parameter(Mandatory=$true)][datetime]$EndTime
    )
    $duration = New-TimeSpan -Start $StartTime -End $EndTime
    Write-PKitLog "Onboarding complete. Duration: $($duration.ToString())"
    Write-Host "Final WingetApps Status:" -ForegroundColor Cyan
    Invoke-AppStatus -WingetStatus $script:WingetAppsStatus -LocalStatus @{} -ArchiveStatus @{}
    Write-Host "Final Local Apps Status:" -ForegroundColor Cyan
    Invoke-AppStatus -WingetStatus @{} -LocalStatus $script:LocalAppsStatus -ArchiveStatus @{}
    Write-Host "Final Archives Extraction Status:" -ForegroundColor Cyan
    Invoke-AppStatus -WingetStatus @{} -LocalStatus @{} -ArchiveStatus $script:ArchivesStatus
    Write-Host "Commands Execution Status:" -ForegroundColor Cyan
    Invoke-CommandsStatus
}

#endregion Final Summary

#region Main Entry: Start-Onboarding

function Start-Onboarding {
    <#
    .SYNOPSIS
         Begins the onboarding process.
    .DESCRIPTION
         Reads the provided company config.ini, creates required folders (logs, installers),
         then processes Winget apps, local apps, compressed files, and commands.
    .EXAMPLE
         Start-Onboarding -CompanyIni "C:\Users\isupport\Desktop\test\configs\OCCK\config.ini"
    #>
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [Parameter(Mandatory=$true)][string]$CompanyIni
    )
    try {
        $script:ScriptStart = Get-Date
        Write-PKitLog "Parsing configuration file: $CompanyIni"
        $config = Convert-IniToHashtable -Path $CompanyIni

        # Derive working directory: if $CompanyIni has '\configs\' then extract text before it.
        if ($CompanyIni -match "^(.*?)[\\/]configs[\\/].*$") {
            $script:WorkingDir = $matches[1]
        }
        else {
            $script:WorkingDir = Split-Path $CompanyIni -Parent
        }
        Write-PKitLog "Working Directory determined: $script:WorkingDir"

        # Create logs folder under WorkingDir\logs\$hostname.
        $hostname = $env:COMPUTERNAME
        $logsDir = Join-Path $script:WorkingDir "logs\$hostname"
        if (-not (Test-Path $logsDir)) { New-Item -ItemType Directory -Path $logsDir | Out-Null }
        $timestamp = Get-Date -Format "yyyy-MM-dd_HHmm"
        $script:LogFile = Join-Path $logsDir "Onboarding_$timestamp.log"
        Write-PKitLog "Log file created: $script:LogFile"

        # Create installers folder under WorkingDir\installers\universal.
        $installersUniversal = Join-Path $script:WorkingDir "installers\universal"
        if (-not (Test-Path $installersUniversal)) { New-Item -ItemType Directory -Path $installersUniversal -Force | Out-Null }
        $script:UniversalInstallersDir = $installersUniversal
        Write-PKitLog "Universal Installers directory: $script:UniversalInstallersDir"
        
        if ($config.General.bannerLocation) {
            Invoke-Banner -BannerPath $config.General.bannerLocation
        }
        else {
            Write-PKitLog "No bannerLocation specified in [General]."
        }
        
        if ($config.WingetApps) {
            Install-WingetApps -WingetSection $config.WingetApps
        }
        else {
            Write-PKitLog "No [WingetApps] section found."
        }
        
        if ($config.Apps) {
            Install-LocalApps -AppsSection $config.Apps
        }
        else {
            Write-PKitLog "No [Apps] section found."
        }
        
        if ($config.'Compressed Files') {
            Invoke-Archives -ArchivesSection $config.'Compressed Files'
        }
        else {
            Write-PKitLog "No [Compressed Files] section found."
        }
        
        if ($config.Commands) {
            Invoke-Commands -CommandsSection $config.Commands
        }
        else {
            Write-PKitLog "No [Commands] section found."
        }
        
        $script:ScriptEnd = Get-Date
        Invoke-Summary -StartTime $script:ScriptStart -EndTime $script:ScriptEnd
    }
    catch {
        Write-PKitLog "Onboarding process terminated with error: $_"
    }
}

Export-ModuleMember -Function Start-Onboarding

#endregion Main Entry: Start-Onboarding
