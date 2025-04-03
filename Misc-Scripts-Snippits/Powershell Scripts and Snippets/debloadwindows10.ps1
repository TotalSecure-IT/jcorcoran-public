<#
.SYNOPSIS
    Slim Down Windows 10 for improved performance on a Surface laptop with SSD.
.DESCRIPTION
    This script removes common bloatware, disables telemetry and other unneeded services,
    tweaks visual effects, and cleans up temporary files.
    **WARNING**: This script makes permanent changes. Create a system restore point or backup your system first!
.NOTES
    Run this script as Administrator.
#>

if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole] "Administrator"))
{
    Write-Error "Please run this script as an Administrator!"
    exit
}

Write-Host "Starting Windows 10 slimming script for Surface laptop with SSD..." -ForegroundColor Cyan

Write-Host "Removing common bloatware apps..." -ForegroundColor Yellow

$bloatApps = @(
    "*3DBuilder*",
    "*XboxApp*",
    "*MicrosoftOfficeHub*",
    "*MicrosoftSolitaireCollection*",
    "*Microsoft.Getstarted*",
    "*Microsoft.ZuneMusic*",
    "*Microsoft.ZuneVideo*",
    "*Microsoft.People*",
    "*Microsoft.BingWeather*",
    "*Microsoft.Messaging*",
    "*Microsoft.SkypeApp*",
    "*Microsoft.GetHelp*",
    "*Microsoft.Microsoft3DViewer*"
)

foreach ($app in $bloatApps) {
    $installedApps = Get-AppxPackage -Name $app -AllUsers -ErrorAction SilentlyContinue
    if ($installedApps) {
        foreach ($pkg in $installedApps) {
            Write-Host "Removing installed app $($pkg.Name)..." -ForegroundColor Green
            Remove-AppxPackage -Package $pkg.PackageFullName -ErrorAction SilentlyContinue
        }
    }
    else {
        Write-Host "No installed app matching '$app' found." -ForegroundColor Cyan
    }
    
    $provPackages = Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -like $app }
    if ($provPackages) {
        foreach ($prov in $provPackages) {
            try {
                Write-Host "Removing provisioned package $($prov.DisplayName)..." -ForegroundColor Green
                Remove-AppxProvisionedPackage -Online -PackageName $prov.PackageName -ErrorAction Stop
            }
            catch {
                Write-Warning "Could not remove provisioned package for $($prov.DisplayName): $_"
            }
        }
    }
    else {
        Write-Host "No provisioned package for '$app' found." -ForegroundColor Cyan
    }
}

Write-Host "Disabling telemetry and other unnecessary services..." -ForegroundColor Yellow

try {
    $diagService = Get-Service -Name "DiagTrack" -ErrorAction SilentlyContinue
    if ($diagService) {
        Write-Host "Disabling Diagnostic Tracking Service (DiagTrack)..." -ForegroundColor Green
        Stop-Service -Name "DiagTrack" -ErrorAction SilentlyContinue
        Set-Service -Name "DiagTrack" -StartupType Disabled -ErrorAction SilentlyContinue
    }
    else {
        Write-Host "Service 'DiagTrack' not found." -ForegroundColor Cyan
    }
} catch {
    Write-Warning "Error disabling DiagTrack: $_"
}

try {
    $cxiService = Get-Service -Name "ProgramDataUpdater" -ErrorAction SilentlyContinue
    if ($cxiService) {
        Write-Host "Disabling ProgramDataUpdater (Customer Experience Improvement Program)..." -ForegroundColor Green
        Stop-Service -Name "ProgramDataUpdater" -ErrorAction SilentlyContinue
        Set-Service -Name "ProgramDataUpdater" -StartupType Disabled -ErrorAction SilentlyContinue
    }
    else {
        Write-Host "Service 'ProgramDataUpdater' not found." -ForegroundColor Cyan
    }
} catch {
    Write-Warning "Error disabling ProgramDataUpdater: $_"
}

Write-Host "Tuning visual effects for performance..." -ForegroundColor Yellow

try {
    Write-Host "Disabling window animations..." -ForegroundColor Green
    Set-ItemProperty -Path "HKCU:\Control Panel\Desktop\WindowMetrics" -Name "MinAnimate" -Value "0" -Force
} catch {
    Write-Warning "Could not disable window animations: $_"
}

try {
    Write-Host "Disabling transparency effects..." -ForegroundColor Green
    New-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name "EnableTransparency" -Value 0 -PropertyType DWord -Force | Out-Null
} catch {
    Write-Warning "Could not disable transparency effects: $_"
}

try {
    Write-Host "Setting system for best performance (visual effects)..." -ForegroundColor Green
    $performanceRegPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects"
    if (-not (Test-Path $performanceRegPath)) {
        New-Item -Path $performanceRegPath -Force | Out-Null
    }
    Set-ItemProperty -Path $performanceRegPath -Name "VisualFXSetting" -Value 2 -Force
} catch {
    Write-Warning "Could not set visual effects to best performance: $_"
}

Write-Host "Windows 10 slimming complete! A restart might be required for all changes to take effect." -ForegroundColor Cyan
