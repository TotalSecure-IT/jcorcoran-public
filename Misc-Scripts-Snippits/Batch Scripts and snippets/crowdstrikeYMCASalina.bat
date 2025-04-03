
@ECHO off

REM Check if CrowdStrike Falcon Sensor is already installed
REM reg query "HKLM\SOFTWARE\CrowdStrike\Falcon" >nul 2>&1
REM if %errorlevel%==0 (
REM    echo CrowdStrike Falcon Sensor is already installed.
REM    exit /b 0
REM )

REM Install CrowdStrike Falcon Sensor
\\ADS1\SYS\Crowdstrike\FalconSensor_Windows.exe /install /quiet /norestart ProvNoWait=1 CID=2EEF42DE24C443E698C75112173EB1FD-ED /log "\\ADS1\SYS\crowdstrike\logs\crowdinstall.txt"

