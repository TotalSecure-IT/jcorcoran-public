# Set the process name
$ProcessName = "processname.exe"

# Get the process ID(s)
$ProcessID = (Get-Process -Name $ProcessName).Id

# Kill the process
Stop-Process -Id $ProcessID -Force