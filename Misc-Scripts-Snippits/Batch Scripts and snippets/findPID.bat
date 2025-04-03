@echo off
for /f "tokens=3" %%a in ('sc queryex syncedtool ^| findstr PID') do set ps=%%a
if %ps%==0 (
	@echo.
)
set pid=%ps%
taskkill /f /PID %pid%
taskkill /f /IM agent_gui.exe
timeout /t 3 & start "" "C:\Program Files (x86)\WCCiT SyncDrive\bin\agent_gui.exe"