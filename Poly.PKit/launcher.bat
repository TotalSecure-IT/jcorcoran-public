@echo off
echo Checking for administrative privileges...
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Please right-click and run as Administrator.
    pause
    exit /b 1
)

echo Changing directory to script location...
cd /d "%~dp0"

echo Creating "logs" folder if it doesn't exist...
if not exist "logs" (
    mkdir "logs"
)
echo Creating "init" folder if it doesn't exist...
if not exist "init" (
    mkdir "init"
)

echo Testing network connectivity...
ping -n 2 8.8.8.8 >nul 2>&1
if errorlevel 1 (
    set "MODE=CACHED"
    echo Network unreachable. Mode set to CACHED.
) else (
    set "MODE=ONLINE"
    echo Network reachable. Mode set to ONLINE.
)

if /i "%MODE%"=="ONLINE" (
    echo Checking for winget installation...
    winget --version >nul 2>&1
    if errorlevel 1 (
        echo winget not found. Installing winget...
        powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "irm 'https://github.com/asheroto/winget-install/releases/latest/download/winget-install.ps1' | iex" 
        )
    ) else (
        echo winget is installed. Upgrading winget...
        winget upgrade --id Microsoft.Winget --silent --accept-source-agreements --accept-package-agreements
    )
    echo Checking for PowerShell 7 (pwsh.exe)...
    where pwsh.exe >nul 2>&1
    if errorlevel 1 (
        echo PowerShell 7 not found. Installing PowerShell 7...
        winget install --id Microsoft.PowerShell --silent --accept-package-agreements --accept-source-agreements 
    ) else (
        echo PowerShell 7 is installed.
)
if /i "%MODE%"=="CACHED" (
    echo Running in CACHED mode...
    if exist "init\main.ps1" (
        echo Launching main.ps1 in CACHED mode...
        powershell -ExecutionPolicy Bypass -NoProfile -File "init\main.ps1" --cached-mode
    ) else (
        echo main.ps1 not found in init folder.
        pause
        exit /b 1
    )
) else if /i "%MODE%"=="ONLINE" (
    echo Running in ONLINE mode...
    echo Downloading main.ps1 from GitHub...
    powershell -ExecutionPolicy Bypass -NoProfile -Command "Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/TotalSecure-IT/jcorcoran-public/refs/heads/main/Poly.PKit/main.ps1' -OutFile '%~dp0init\main.ps1'"
    echo Launching main.ps1 in ONLINE mode...
    "C:\Program Files\PowerShell\7\pwsh.exe" -ExecutionPolicy Bypass -NoProfile -File "%~dp0init\main.ps1" --online-mode
)
echo Exiting script.
pause
exit /b 0
