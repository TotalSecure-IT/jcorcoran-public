@echo off
set group1=DictateUsers
set group2=TranscribeUsers
set user=%username%
setlocal enabledelayedexpansion

:main
echo Checking if %user% is a security group member of %group1% or %group2%
echo.

:search1
set i=0
call :gsearch1
if %i% == 1 (
	goto :dictate
) ELSE (
	echo.
)

:search2
set i=0
call :gsearch2
if %i% == 2 (
	goto :transcribe
) ELSE (
	echo.
	goto :end3
)

:transcribe
set i=0
call :gsearch2
IF EXIST "C:\Program Files (x86)\Philips Speech\SpeechExec Enterprise Transcribe\SEETrans.exe" (
	goto :end2
) ELSE (
	if %i% == 2 (
		echo %user% is a member of %group2%
		echo.
	) ELSE (
		goto :end2
	)
	echo Installing Transcribe. Please wait...
	echo.
	@echo off
	powershell -Command "& {set-executionpolicy -executionpolicy unrestricted -scope process}
	msiexec.exe /i \\hldc1\Enterprise_Software\transcribe\speechexec.msi TRANSFORMS="\\hldc1\Enterprise_Software\transcribe\transcribe_1033.mst" /quiet /l*v c:\transcribelog.txt
	goto :end2
)

:dictate
set i=0
call :gsearch1
IF EXIST "C:\Program Files (x86)\Philips Speech\SpeechExec Enterprise Dictate\SEEDict.exe" (
	goto :end1
) ELSE (
	if %i% == 1 (
		echo %user% is a member of %group1%
		echo.
	) ELSE (
		goto :end1
	)
	echo Installing Dictate. Please wait...
	echo.
	@echo off
	powershell -Command "& {set-executionpolicy -executionpolicy unrestricted -scope process}
	msiexec.exe /i \\hldc1\Enterprise_Software\dictate\speechexec.msi TRANSFORMS="\\hldc1\Enterprise_Software\dictate\dictate_1033.mst" /quiet /l*v c:\dictatelog.txt
	goto :end1
)

:end1
IF EXIST "C:\Program Files (x86)\Philips Speech\SpeechExec Enterprise Transcribe\SEETrans.exe" (
	echo Your machine has been blessed with DICTATE and/or TRANSCRIBE by Justin at WCCIT
	echo Please notify me whether the install was successful at justin@wccit.com
	@echo off
	timeout /t -1
	exit
) ELSE (
	goto :transcribe
)

:end2
@echo off
set i=0
IF EXIST "C:\Program Files (x86)\Philips Speech\SpeechExec Enterprise Dictate\SEEDict.exe" (
	
	echo Your machine has been blessed with DICTATE and/or TRANSCRIBE by Justin at WCCIT. 
	echo Please notify me whether the install was successful at justin@wccit.com
	@echo off
	timeout /t -1
	exit
) ELSE (
	goto :dictate
)

:end3
@echo off

echo Justin at WCCIT says: You were not required to receive Dictate or Transcribe. Thank you!
@echo off
timeout /t -1
exit

:gsearch1
for /f %%f in ('"net user %user% /domain | findstr /i %group1%"') do set /a i=%i%+1
goto :EOF

:gsearch2
for /f %%f in ('"net user %user% /domain | findstr /i %group2%"') do set /a i=%i%+2
goto :EOF