<#
.SYNOPSIS
    Onboarding.psm1 automates the onboarding process of a machine based on a company-specific config.ini file.
.DESCRIPTION
    This module reads a config.ini (supplied via --company-ini) and:
      - Parses its sections ([General], [Credentials], [WingetApps], [Apps], [Compressed Files], [Commands])
      - Downloads and silently installs applications obtained via winget (saving installers to a universal folder)
      - Installs local applications if not already installed
      - Extracts archive files (.zip, .rar, .7z, .tar) to designated locations
      - Executes command strings from the [Commands] section with a custom status display (e.g. [ failures | successes ])
      - Provides live, colored console updates (banner and status tables) identical to sample-script.ps1
      - Logs every action with timestamps and runs completely non-interactively (no prompts)
.EXAMPLE
    Start-Onboarding -CompanyIni "C:\Path\To\workingdirectory\configs\MyCompany\config.ini"
#>

#region Global Variables & Logging

# Global counters for Commands section
$global:CommandFailures = 0
$global:CommandSuccesses  = 0

# Global status hashtables for tracking installation statuses
$global:WingetAppsStatus = @{}
$global:LocalAppsStatus  = @{}
$global:ArchivesStatus   = @{}

# Global variables for log file and working folders (set later)
$global:LogFile = $null
$global:WorkingDir = $null
$global:UniversalInstallersDir = $null

function Write-Log {
    param(
        [Parameter(Mandatory)]
        [string]$Message
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $entry = "$timestamp - $Message"
    if ($global:LogFile) {
        Add-Content -Path $global:LogFile -Value $entry
    }
    Write-Host $entry
}

#endregion Global Variables & Logging

#region Config Parsing

function Convert-IniToHashtable {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )
    if (-not (Test-Path $Path)) {
        Write-Log "Config file not found at $Path. Exiting."
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
    param(
        [Parameter(Mandatory)]
        [string]$BannerPath
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
        Write-Log "Banner file not found at $BannerPath."
    }
}

function Invoke-Appstatus {
    param(
        [hashtable]$WingetStatus,
        [hashtable]$LocalStatus,
        [hashtable]$ArchiveStatus
    )
    Write-Host "---------------------------------------------"
    Write-Host "Installation Status:" -ForegroundColor Cyan
    foreach ($key in $WingetStatus.Keys) {
        $status = $WingetStatus[$key]
        if ($status -eq "Success") {
            Write-Host "$key : $status" -ForegroundColor Green
        }
        elseif ($status -eq "Failed") {
            Write-Host "$key : $status" -ForegroundColor Red
        }
        else {
            Write-Host "$key : $status" -ForegroundColor Yellow
        }
    }
    foreach ($key in $LocalStatus.Keys) {
        $status = $LocalStatus[$key]
        if ($status -eq "Success") {
            Write-Host "$key : $status" -ForegroundColor Green
        }
        elseif ($status -eq "Failed") {
            Write-Host "$key : $status" -ForegroundColor Red
        }
        else {
            Write-Host "$key : $status" -ForegroundColor Yellow
        }
    }
    foreach ($key in $ArchiveStatus.Keys) {
        $status = $ArchiveStatus[$key]
        if ($status -eq "Success") {
            Write-Host "$key : $status" -ForegroundColor Green
        }
        elseif ($status -eq "Failed") {
            Write-Host "$key : $status" -ForegroundColor Red
        }
        else {
            Write-Host "$key : $status" -ForegroundColor Yellow
        }
    }
}

function Invoke-CommandsStatus {
    $failStr = "$global:CommandFailures"
    $succStr = "$global:CommandSuccesses"
    $formatted = "[ $failStr | $succStr ]"
    # Write the entire status string, then separately output the counts with color.
    Write-Host $formatted -ForegroundColor White
    Write-Host ("Failures: " + $failStr) -ForegroundColor Red -NoNewline; Write-Host "   " -NoNewline; Write-Host ("Successes: " + $succStr) -ForegroundColor Green
}

#endregion Console UI Functions

#region WingetApps Installation

function Install-WingetApps {
    param(
        [hashtable]$WingetSection
    )
    Write-Log "Starting WingetApps installation..."
    $appNumbers = @()
    foreach ($key in $WingetSection.Keys) {
        if ($key -match "^(App\d+)$") {
            $appNumbers += $matches[1]
        }
    }
    $appNumbers = $appNumbers | Sort-Object
    foreach ($appNum in $appNumbers) {
        $appName = $WingetSection["$appNum"]
        $versionKey = "$appNum" + "Version"
        $argsKey    = "$appNum" + "Args"
        $appVersion = $WingetSection[$versionKey]
        $appArgs    = $WingetSection[$argsKey]
        if (-not $appName) { continue }
        Write-Log "Processing Winget app: $appName"

        $wingetCmd = "winget show `"$appName`""
        if ($appVersion) {
            $wingetCmd += " --version $appVersion"
        }
        Write-Log "Executing command: $wingetCmd"
        try {
            $wingetOutput = Invoke-Expression $wingetCmd 2>&1
        }
        catch {
            Write-Log "Failed to execute winget show for $appName. Marking as Failed."
            $global:WingetAppsStatus[$appName] = "Failed"
            continue
        }
        $installerUrl = $null
        foreach ($line in $wingetOutput) {
            if ($line -match "Installer\s+Url:\s*(\S+)") {
                $installerUrl = $matches[1]
                break
            }
        }
        if (-not $installerUrl) {
            Write-Log "No installer URL found for $appName. Marking as Failed."
            $global:WingetAppsStatus[$appName] = "Failed"
            continue
        }
        Write-Log "Found installer URL for $appName $installerUrl"
        $filename = Split-Path $installerUrl -Leaf
        $destinationPath = Join-Path $global:UniversalInstallersDir $filename
        if (-not (Test-Path $destinationPath)) {
            Write-Log "Downloading installer for $appName..."
            try {
                Invoke-WebRequest -Uri $installerUrl -OutFile $destinationPath -UseBasicParsing
            }
            catch {
                Write-Log "Download failed for $appName. Marking as Failed."
                $global:WingetAppsStatus[$appName] = "Failed"
                continue
            }
        }
        else {
            Write-Log "Installer file already exists for $appName."
        }
        Write-Log "Installing $appName from $destinationPath..."
        try {
            $proc = Start-Process -FilePath $destinationPath -ArgumentList $appArgs -Wait -PassThru -WindowStyle Hidden
            if ($proc.ExitCode -eq 0 -or $proc.ExitCode -eq 3010) {
                Write-Log "$appName installed successfully."
                $global:WingetAppsStatus[$appName] = "Success"
            }
            else {
                Write-Log "$appName installation failed with exit code $($proc.ExitCode)."
                $global:WingetAppsStatus[$appName] = "Failed"
            }
        }
        catch {
            Write-Log "Exception during installation of $appName $_"
            $global:WingetAppsStatus[$appName] = "Failed"
        }
        Invoke-Appstatus -WingetStatus $global:WingetAppsStatus -LocalStatus @{} -ArchiveStatus @{}
    }
}

#endregion WingetApps Installation

#region Local Apps Installation

function Install-LocalApps {
    param(
        [hashtable]$AppsSection
    )
    Write-Log "Starting local Apps installation..."
    $appNumbers = @()
    foreach ($key in $AppsSection.Keys) {
        if ($key -match "^(App\d+Name)$") {
            $appNum = $matches[1] -replace "Name", ""
            $appNumbers += $appNum
        }
    }
    $appNumbers = $appNumbers | Sort-Object
    foreach ($appNum in $appNumbers) {
        $nameKey = "$appNum" + "Name"
        $sourceKey = "$appNum" + "Source"
        $argsKey = "$appNum" + "Args"
        $checkPathKey = "$appNum" + "CheckPath"
        $appName = $AppsSection[$nameKey]
        $appSource = $AppsSection[$sourceKey]
        $appArgs = $AppsSection[$argsKey]
        $appCheckPath = $AppsSection[$checkPathKey]
        if (-not $appName) { continue }
        Write-Log "Processing local app: $appName"
        if ($appCheckPath -and (Test-Path $appCheckPath)) {
            Write-Log "$appName is already installed. Skipping installation."
            $global:LocalAppsStatus[$appName] = "Skipped"
            continue
        }
        if (-not (Test-Path $appSource)) {
            Write-Log "Installer for $appName not found at $appSource. Marking as Failed."
            $global:LocalAppsStatus[$appName] = "Failed"
            continue
        }
        Write-Log "Installing $appName using source $appSource..."
        try {
            $proc = Start-Process -FilePath $appSource -ArgumentList $appArgs -Wait -PassThru -WindowStyle Hidden
            if ($proc.ExitCode -eq 0 -or $proc.ExitCode -eq 3010) {
                Write-Log "$appName installed successfully."
                $global:LocalAppsStatus[$appName] = "Success"
            }
            else {
                Write-Log "$appName installation failed with exit code $($proc.ExitCode)."
                $global:LocalAppsStatus[$appName] = "Failed"
            }
        }
        catch {
            Write-Log "Exception during installation of $appName $_"
            $global:LocalAppsStatus[$appName] = "Failed"
        }
        Invoke-Appstatus -WingetStatus @{} -LocalStatus $global:LocalAppsStatus -ArchiveStatus @{}
    }
}

#endregion Local Apps Installation

#region Archives Extraction

function Invoke-Archives {
    param(
        [hashtable]$ArchivesSection
    )
    Write-Log "Starting extraction of compressed files..."
    $archiveNumbers = @()
    foreach ($key in $ArchivesSection.Keys) {
        if ($key -match "^(Archive\d+Name)$") {
            $archNum = $matches[1] -replace "Name", ""
            $archiveNumbers += $archNum
        }
    }
    $archiveNumbers = $archiveNumbers | Sort-Object
    foreach ($archNum in $archiveNumbers) {
        $nameKey = "$archNum" + "Name"
        $destKey = "$archNum" + "Destination"
        $argsKey = "$archNum" + "Args"
        $archivePath = $ArchivesSection[$nameKey]
        $destPath = $ArchivesSection[$destKey]
        $extraArgs = $ArchivesSection[$argsKey]
        if (-not (Test-Path $archivePath)) {
            Write-Log "Archive not found: $archivePath. Marking as Failed."
            $global:ArchivesStatus[$archivePath] = "Failed"
            continue
        }
        Write-Log "Extracting archive: $archivePath to $destPath"
        try {
            $ext = [System.IO.Path]::GetExtension($archivePath).ToLower()
            switch ($ext) {
                ".zip" {
                    Expand-Archive -Path $archivePath -DestinationPath $destPath -Force
                    $global:ArchivesStatus[$archivePath] = "Success"
                }
                ".rar" {
                    if (Get-Command unrar -ErrorAction SilentlyContinue) {
                        unrar x $archivePath $destPath $extraArgs
                        $global:ArchivesStatus[$archivePath] = "Success"
                    }
                    else {
                        Write-Log "No unrar utility found for $archivePath."
                        $global:ArchivesStatus[$archivePath] = "Failed"
                    }
                }
                ".7z" {
                    if (Get-Command 7z -ErrorAction SilentlyContinue) {
                        7z x $archivePath -o$destPath $extraArgs
                        $global:ArchivesStatus[$archivePath] = "Success"
                    }
                    else {
                        Write-Log "No 7z utility found for $archivePath."
                        $global:ArchivesStatus[$archivePath] = "Failed"
                    }
                }
                ".tar" {
                    if (Get-Command tar -ErrorAction SilentlyContinue) {
                        tar -xf $archivePath -C $destPath
                        $global:ArchivesStatus[$archivePath] = "Success"
                    }
                    else {
                        Write-Log "No tar utility found for $archivePath."
                        $global:ArchivesStatus[$archivePath] = "Failed"
                    }
                }
                default {
                    Write-Log "Unsupported archive type: $ext for file $archivePath."
                    $global:ArchivesStatus[$archivePath] = "Failed"
                }
            }
        }
        catch {
            Write-Log "Exception extracting $archivePath $_"
            $global:ArchivesStatus[$archivePath] = "Failed"
        }
        Invoke-Appstatus -WingetStatus @{} -LocalStatus @{} -ArchiveStatus $global:ArchivesStatus
    }
}

#endregion Archives Extraction

#region Commands Execution

function Invoke-Commands {
    param(
        [hashtable]$CommandsSection
    )
    Write-Log "Executing commands from [Commands] section..."
    foreach ($key in $CommandsSection.Keys) {
        $cmd = $CommandsSection[$key]
        if ([string]::IsNullOrEmpty($cmd)) { continue }
        Write-Log "Executing command [$key]: $cmd"
        try {
            Invoke-Expression $cmd
            $global:CommandSuccesses++
        }
        catch {
            Write-Log "Command [$key] failed: $_"
            $global:CommandFailures++
        }
        Invoke-CommandsStatus
    }
}

#endregion Commands Execution

#region Final Summary

function Invoke-Summary {
    param(
        [datetime]$StartTime,
        [datetime]$EndTime
    )
    $duration = New-TimeSpan -Start $StartTime -End $EndTime
    Write-Log "Onboarding complete. Duration: $($duration.ToString())"
    Write-Host "Final WingetApps Status:" -ForegroundColor Cyan
    Invoke-Appstatus -WingetStatus $global:WingetAppsStatus -LocalStatus @{} -ArchiveStatus @{}
    Write-Host "Final Local Apps Status:" -ForegroundColor Cyan
    Invoke-Appstatus -WingetStatus @{} -LocalStatus $global:LocalAppsStatus -ArchiveStatus @{}
    Write-Host "Final Archives Extraction Status:" -ForegroundColor Cyan
    Invoke-Appstatus -WingetStatus @{} -LocalStatus @{} -ArchiveStatus $global:ArchivesStatus
    Write-Host "Commands Execution Status:" -ForegroundColor Cyan
    Invoke-CommandsStatus
}

#endregion Final Summary

#region Main Entry: Start-Onboarding

function Start-Onboarding {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$CompanyIni
    )
    try {
        $global:ScriptStart = Get-Date

        Write-Log "Parsing configuration file: $CompanyIni"
        $config = Convert-IniToHashtable -Path $CompanyIni

        # Derive WorkingDir from the CompanyIni file path.
        $configsDir = Split-Path $CompanyIni -Parent
        $global:WorkingDir = Split-Path $configsDir -Parent

        # Fallback if $global:WorkingDir is empty.
        if ([string]::IsNullOrEmpty($global:WorkingDir)) {
            $global:WorkingDir = Get-Location
        }
        Write-Log "Working Directory determined: $global:WorkingDir"
        $logsDir = Join-Path $global:WorkingDir "logs"
        if (-not (Test-Path $logsDir)) { New-Item -ItemType Directory -Path $logsDir | Out-Null }
        $timestamp = Get-Date -Format "yyyy-MM-dd_HHmm"
        $global:LogFile = Join-Path $logsDir "Onboarding_$timestamp.log"
        Write-Log "Log file created: $global:LogFile"
        $installersUniversal = Join-Path $global:WorkingDir "installers\universal"
        if (-not (Test-Path $installersUniversal)) { New-Item -ItemType Directory -Path $installersUniversal -Force | Out-Null }
        $global:UniversalInstallersDir = $installersUniversal
        Write-Log "Universal Installers directory: $global:UniversalInstallersDir"
        
        if ($config.General.bannerLocation) {
            Invoke-Banner -BannerPath $config.General.bannerLocation
        }
        else {
            Write-Log "No bannerLocation specified in [General]."
        }
        
        if ($config.WingetApps) {
            Install-WingetApps -WingetSection $config.WingetApps
        }
        else {
            Write-Log "No [WingetApps] section found."
        }
        
        if ($config.Apps) {
            Install-LocalApps -AppsSection $config.Apps
        }
        else {
            Write-Log "No [Apps] section found."
        }
        
        if ($config.'Compressed Files') {
            Invoke-Archives -ArchivesSection $config.'Compressed Files'
        }
        else {
            Write-Log "No [Compressed Files] section found."
        }
        
        if ($config.Commands) {
            Invoke-Commands -CommandsSection $config.Commands
        }
        else {
            Write-Log "No [Commands] section found."
        }
        
        $global:ScriptEnd = Get-Date
        Invoke-Summary -StartTime $global:ScriptStart -EndTime $global:ScriptEnd
    }
    catch {
        Write-Log "Onboarding process terminated with error: $_"
    }
}

Export-ModuleMember -Function Start-Onboarding

#endregion Main Entry: Start-Onboarding
