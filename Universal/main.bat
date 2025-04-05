@echo off
setlocal EnableDelayedExpansion

REM Set BASE to the directory where this batch file resides.
set "BASE=%~dp0"
if "%BASE:~-1%"=="\" set "BASE=%BASE:~0,-1%"
echo BASE is %BASE%

REM ----- Check if Winget is installed -----
where winget >nul 2>&1
if errorlevel 1 (
    echo Winget is not installed. Installing winget using Microsoft script...
    powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
      "$progressPreference = 'silentlyContinue';" ^
      "$installDir = '%BASE%';" ^
      "$latestWingetMsixBundleUri = (Invoke-RestMethod https://api.github.com/repos/microsoft/winget-cli/releases/latest).assets.browser_download_url | Where-Object { $_.EndsWith('.msixbundle') };" ^
      "$latestWingetMsixBundle = $latestWingetMsixBundleUri.Split('/')[-1];" ^
      "Write-Information 'Downloading winget to artifacts directory...';" ^
      "Invoke-WebRequest -Uri $latestWingetMsixBundleUri -OutFile (Join-Path $installDir $latestWingetMsixBundle);" ^
      "Invoke-WebRequest -Uri https://aka.ms/Microsoft.VCLibs.x64.14.00.Desktop.appx -OutFile (Join-Path $installDir 'Microsoft.VCLibs.x64.14.00.Desktop.appx');" ^
      "Add-AppxPackage (Join-Path $installDir 'Microsoft.VCLibs.x64.14.00.Desktop.appx');" ^
      "Add-AppxPackage (Join-Path $installDir $latestWingetMsixBundle);"
) else (
    echo Winget is installed.
)

REM ----- Check if PowerShell 7 is installed -----
if exist "C:\Program Files\PowerShell\7\pwsh.exe" (
    goto PS7Installed
)

REM If PS7 is not installed, update winget and install PS7 via winget.
echo Updating Winget...
winget upgrade --id Microsoft.Winget --silent --accept-source-agreements --accept-package-agreements
if errorlevel 1 (
    echo Winget upgrade encountered an error. Continuing...
)

echo Installing PowerShell 7...
winget install --id Microsoft.PowerShell --silent --accept-package-agreements --accept-source-agreements
if errorlevel 1 (
    echo PowerShell 7 installation encountered an error. Please install it manually.
    pause
    exit /b
)

:WaitForPS7
echo Waiting for PowerShell 7 to be installed...
timeout /t 2 >nul
if not exist "C:\Program Files\PowerShell\7\pwsh.exe" goto WaitForPS7

:PS7Installed
echo PowerShell 7 detected.
echo Launching main.ps1 with PS7...
"C:\Program Files\PowerShell\7\pwsh.exe" -ExecutionPolicy Bypass -NoProfile -File "%BASE%\main.ps1" -UsbRoot "%BASE%"
endlocal
exit /b
