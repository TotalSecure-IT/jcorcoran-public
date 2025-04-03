@echo off

setlocal
set i=0
for %%a in (16,17,18,19,20) do (
	set /A i+=1
	set ki[!i!]=%%a
)

for /L %%i in (1,1,5) do (
	taskkill /f /IM wpwin!ki[%%i]!.wpt && (
		echo SUCCESS
	) || (
		echo Version !ki[%%i]! is not running
	)
)
endlocal