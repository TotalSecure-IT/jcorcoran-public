@echo off
REM
if exist "C:\Program Files\PowerShell\7\pwsh.exe" (
    echo PowerShell 7 detected. Launching script directly...
    "C:\Program Files\PowerShell\7\pwsh.exe" -ExecutionPolicy Bypass -File "C:\OCCK-Deployment\Files\Occk-Deploy.ps1"
    exit /b
)

REM
echo PowerShell 7 not detected. Running script with PowerShell 5...
powershell.exe -ExecutionPolicy Bypass -File "C:\OCCK-Deployment\Files\Occk-Deploy.ps1"

REM
:WaitForPS7
if exist "C:\Program Files\PowerShell\7\pwsh.exe" goto Relaunch
timeout /t 1 >nul
goto WaitForPS7

:Relaunch
echo PowerShell 7 is now installed.
echo Relaunching script using PowerShell 7...
"C:\Program Files\PowerShell\7\pwsh.exe" -ExecutionPolicy Bypass -File "C:\OCCK-Deployment\Files\Occk-Deploy.ps1"
