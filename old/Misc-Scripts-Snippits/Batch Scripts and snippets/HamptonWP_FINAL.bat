@echo off
SETLOCAL ENABLEDELAYEDEXPANSION
set user=%username%
call :taskkill
IF EXIST "C:\Program Files (x86)\Corel\WordPerfect Office 2021" (exit) ELSE (echo --Success. These are not actually errors. This process will take approximately 10 minutes or less. Please wait...)
echo.
echo.
echo.
net use x: "\\hlps\Program Installs\WordPerfect2021\English"
"x:\setup.exe" UPGRADE_PRODUCT=All UPGRADE_PRODUCT_DEFAULT=Off MIGRATE_PRODUCT=16,17,18,19,20 SERIALNUMBER=WP21C22-Z9J6U8S-9BXTA22-5GNCQP6 FORCENOSHOWLIC=1 /qr /norestart
net use x: /delete
exit
:taskkill
SETLOCAL
set i=0
for %%a in (16,17,18,19,20) do (set /A i+=1 & set ki[!i!]=%%a)
for /L %%i in (1,1,5) do (@taskkill /f /IM wpwin!ki[%%i]!.exe)
ENDLOCAL
goto :EOF
