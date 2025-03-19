FOR /F "tokens=5 delims= " %%I IN (
    'netstat -ano ^| find "127.0.0.1:3389" ^| find "CLOSE_WAIT"'
) DO (
    taskkill /PID %%I /f
)
pause