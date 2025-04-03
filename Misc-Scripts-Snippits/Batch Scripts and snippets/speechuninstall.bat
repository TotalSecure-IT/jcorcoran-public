@echo off

IF EXIST "C:\Program Files (x86)\Philips Speech\SpeechExec Enterprise Transcribe\SEETrans.exe" (
	msiexec.exe /x \\hldc1\Enterprise_Software\transcribe\speechexec.msi /quiet
	goto :next
) ELSE (
	goto :next
)

:next
IF EXIST "C:\Program Files (x86)\Philips Speech\SpeechExec Enterprise Dictate\SEEDict.exe" (
	msiexec.exe /x \\hldc1\Enterprise_Software\dictate\speechexec.msi /quiet
	exit
) ELSE (
	exit
)