@echo off
REM Check if PowerShell 7 is already installed
if exist "C:\Program Files\PowerShell\7\pwsh.exe" (
    echo PowerShell 7 detected. Launching script directly...
    "C:\Program Files\PowerShell\7\pwsh.exe" -ExecutionPolicy Bypass -File "C:\Occk-Onboarding-Script\Files\Occk-Deploy-test.ps1"
    exit /b
)

REM If PS7 is not installed, run the script with the existing PowerShell
echo PowerShell 7 not detected. Running script with PowerShell 5...
powershell.exe -ExecutionPolicy Bypass -File "C:\Occk-Onboarding-Script\Files\Occk-Deploy-test.ps1"

REM Wait for PowerShell 7 installation to complete
:WaitForPS7
if exist "C:\Program Files\PowerShell\7\pwsh.exe" goto Relaunch
timeout /t 1 >nul
goto WaitForPS7

:Relaunch
echo PowerShell 7 is now installed.
echo Relaunching script using PowerShell 7...
"C:\Program Files\PowerShell\7\pwsh.exe" -ExecutionPolicy Bypass -File "C:\Occk-Onboarding-Script\Files\Occk-Deploy-test.ps1"
