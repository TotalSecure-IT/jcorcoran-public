@echo off
setlocal enabledelayedexpansion

set LOGFILE=logs/script_%date:~-4,4%-%date:~-10,2%-%date:~-7,2%_%time:~0,2%-%time:~3,2%-%time:~6,2%.log
echo [INFO]  Starting script at %date% %time% > "%LOGFILE%"
echo [INFO]  %~nx0 >> "%LOGFILE%"
echo [INFO]  Version: 2.0 >> "%LOGFILE%"
echo [INFO]  Initializing Script.. >> "%LOGFILE%"
echo [INFO]  Are we an admin? >> "%LOGFILE%"
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [INFO]  Attempting to launch as admin.. >> "%LOGFILE%"
    powershell -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    pause
    exit /b 1
)

echo [INFO]  Changing directory to script location.. >> "%LOGFILE%"
echo [INFO]  Script location: %~dp0 >> "%LOGFILE%"
cd /d "%~dp0"

for %%D in (logs init) do (
    if not exist "%%D" (
        echo [INFO]  Creating "%%D" folder >> "%LOGFILE%"
        mkdir "%%D"
    )
)

echo [INFO]  Checking for winget installation >> "%LOGFILE%"
winget --version >nul 2>&1
    if errorlevel 1 (
        echo [FAIL]  winget not found. Attempting installation. >> "%LOGFILE%"
        powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
            "Invoke-WebRequest -Uri 'https://github.com/asheroto/winget-install/releases/latest/download/winget-install.ps1' -OutFile '%~dp0init\winget-install.ps1'; if (!(Test-Path '%~dp0init\winget-install.ps1')) { Write-Host 'Failed to download winget-install.ps1'; exit 1 } ; %~dp0init\winget-install.ps1" >> "%LOGFILE%"
    ) else (
        echo [SUCC]  winget is installed. Upgrading winget >> "%LOGFILE%"
        winget upgrade --id Microsoft.Winget --silent --accept-source-agreements --accept-package-agreements >> "%LOGFILE%" 2>&1
)

echo [INFO]  Checking for PowerShell 7 (pwsh.exe) >> "%LOGFILE%"
where pwsh.exe >nul 2>&1
if errorlevel 1 (
        echo [FAIL]  PowerShell 7 not found. Attempting installation. >> "%LOGFILE%"
        winget install --id Microsoft.PowerShell --silent --accept-package-agreements --accept-source-agreements >> "%LOGFILE%" 2>&1
    ) else (
        echo [SUCC]  PowerShell 7 is installed. >> "%LOGFILE%"
)

echo [INFO]  Downloading main.ps1 from GitHub >> "%LOGFILE%"
powershell.exe -ExecutionPolicy Bypass -NoProfile -Command ^
    "Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/TotalSecure-IT/jcorcoran-public/refs/heads/main/Poly.PKit/main.ps1' -OutFile '%~dp0init\main.ps1'; if (!(Test-Path '%~dp0init\main.ps1')) { Write-Host 'Failed to download main.ps1'; exit 1 }" >> "%LOGFILE%"

echo [INFO]  Launching main.ps1 in ONLINE mode >> "%LOGFILE%"
"C:\Program Files\PowerShell\7\pwsh.exe" -ExecutionPolicy Bypass -NoProfile -File "%~dp0init\main.ps1" --online-mode >> "%LOGFILE%" 2>&1)

echo [INFO]  Script end time: %date% %time%  >> "%LOGFILE%"
echo [INFO]  Exiting script. >> "%LOGFILE%"