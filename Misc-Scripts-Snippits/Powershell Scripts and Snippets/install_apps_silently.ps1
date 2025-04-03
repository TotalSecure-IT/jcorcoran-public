# Define the paths to the installation files
$Program1Path = "C:\installers\program1.exe"
$Program2Path = "C:\installers\program2.msi"
$Program3Path = "C:\installers\program3.exe"

# Define the command-line arguments to run the installation files silently
$Program1Args = "/S /v`"/qn`""
$Program2Args = "/qn /norestart"
$Program3Args = "/S"

# Run the installation files silently
Start-Process -FilePath $Program1Path -ArgumentList $Program1Args -Wait
Start-Process -FilePath $Program2Path -ArgumentList $Program2Args -Wait
Start-Process -FilePath $Program3Path -ArgumentList $Program3Args -Wait
