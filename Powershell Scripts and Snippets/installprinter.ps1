# Unzip drivers
$zipFilePath = "C:\wccit_scripts\occkprinter.zip"
$destinationFolderPath = "C:\wccit_scripts\occkprinter"
New-Item -ItemType Directory -Force -Path $destinationFolderPath
Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::ExtractToDirectory($zipFilePath, $destinationFolderPath)

# install driver to driver store
pnputil.exe /a "C:\wccit_scripts\occkprinter\Win_x64\KOAXCJ__.inf"

# Define printer variables
$printerName = "KONICA MINOLTA C360iSeriesPCL"
$driverName = "KONICA MINOLTA C360iSeriesPCL"
$portName = "IP_10.1.5.243"

# Install printer driver
Add-PrinterDriver -Name $driverName

# Create printer port
Add-PrinterPort -Name $portName -PrinterHostAddress "10.1.5.243"

# Add printer connection for all users
Add-Printer -Name $printerName -DriverName $driverName -PortName $portName

# Get a list of all user profiles on the computer
$userProfiles = Get-ChildItem "C:\Users" | Where-Object { $_.PSIsContainer }

# Set printer as default for each user
foreach ($user in $userProfiles) {
    $userSID = $user.Name
    $printer = Get-Printer -Name $printerName
    Set-PrintConfiguration -PrinterName $printer.Name -PrintConfiguration $printer.PrintConfiguration -Force -User $userSID
}