# Path to the zip file to extract
$zipFilePath = "C:\wccit_scripts\occkprinter.zip"

# Path to the folder where the contents of the zip file will be extracted
$destinationFolderPath = "C:\wccit_scripts\occkprinter"

# Create the folder if it doesn't already exist
New-Item -ItemType Directory -Force -Path $destinationFolderPath

# Extract the contents of the zip file to the destination folder
Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::ExtractToDirectory($zipFilePath, $destinationFolderPath)