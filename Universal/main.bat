@echo off
setlocal EnableDelayedExpansion

REM Set BASE to the directory where this batch file resides.
set "BASE=%~dp0"
if "%BASE:~-1%"=="\" set "BASE=%BASE:~0,-1%"
echo BASE is %BASE%

REM Create a "logs" folder in BASE.
if not exist "%BASE%\logs" mkdir "%BASE%\logs"

REM ----- Check if Winget is installed -----
where winget >nul 2>&1
if errorlevel 1 (
    echo Winget is not installed. Installing Winget using external script...
    powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "irm 'https://github.com/asheroto/winget-install/releases/latest/download/winget-install.ps1' | iex"
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
echo Launching main.ps1 from GitHub with PS7...
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "& { $script = (irm 'https://raw.githubusercontent.com/TotalSecure-IT/jcorcoran-public/refs/heads/main/Universal/main.ps1'); & ([scriptblock]::Create($script)) -UsbRoot '%BASE%' }"
endlocal
exit /b
