# Define the source network share path and destination folder path
$sourcePath = "\\reflections-onedefense\Deployment_toolkit\msi\" # Update this with your network share path
$destinationPath = "C:\wccit\msi"
$username = "administrator"
$password = "PASSWORD"

net use $sourcePath $password /USER:$username

# Create the destination folder if it does not exist
if (-not (Test-Path -Path $destinationPath)) {
    New-Item -Path $destinationPath -ItemType Directory
}

# Copy the contents from the network share to the destination folder
try {
    Copy-Item -Path $sourcePath\* -Destination $destinationPath -Recurse -Force
} catch {
    Write-Error "An error occurred while copying files: $_"
}

msiexec /i c:\wccit\msi\BackupClient64.msi TRANSFORMS=c:\wccit\msi\BackupClient64.msi.mst /l*v C:\wccit\faillog.txt /qn /norestart
net use $sourcePath /delete
