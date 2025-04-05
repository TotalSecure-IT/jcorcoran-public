@echo off
setlocal EnableDelayedExpansion

REM Set BASE to the directory where this batch file resides.
set "BASE=%~dp0"

REM Remove trailing backslash if present.
if "%BASE:~-1%"=="\" set "BASE=%BASE:~0,-1%"

echo BASE is %BASE%

REM ----- Check if Winget is installed -----
where winget >nul 2>&1
if errorlevel 1 (
    echo Winget is not installed. Attempting to install Winget...
    REM Download Winget installer (App Installer package) from GitHub.
    set "wingetInstaller=%TEMP%\AppInstaller.msixbundle"
    powershell -Command "Invoke-WebRequest -Uri 'https://github.com/microsoft/winget-cli/releases/download/v1.2.5111/AppInstaller.msixbundle' -OutFile '%TEMP%\AppInstaller.msixbundle'"
    if exist "%wingetInstaller%" (
        echo Installing Winget...
        powershell -Command "Add-AppxPackage -Path '%wingetInstaller%'"
        timeout /t 5 >nul
    ) else (
        echo Failed to download Winget installer.
        pause
        exit /b
    )
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