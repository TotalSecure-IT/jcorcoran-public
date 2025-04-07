$folderPath = "c:\wccit"
if (-Not (Test-Path -Path $folderPath)) {
    New-Item -Path $folderPath -ItemType Directory
    Write-Output "Folder created at $folderPath"
} else {
    Write-Output "Folder already exists at $folderPath"
}
invoke-webrequest -URI https://software.sonicwall.com/NetExtender/NetExtender-x64-10.2.341.msi -Outfile c:\wccit\NetExtender-x64-10.2.341.msi
msiexec.exe /i c:\wccit\NetExtender-x64-10.2.341.msi server=174.76.130.114:4433 domain=ymca.local /qn /norestart ALLUSERS=2
