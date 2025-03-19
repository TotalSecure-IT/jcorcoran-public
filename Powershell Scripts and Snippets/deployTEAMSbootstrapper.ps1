$folderPath = "c:\wccit"
if (-Not (Test-Path -Path $folderPath)) {
    New-Item -Path $folderPath -ItemType Directory
    Write-Output "Folder created at $folderPath"
} else {
    Write-Output "Folder already exists at $folderPath"
}
invoke-webrequest -URI "https://go.microsoft.com/fwlink/?linkid=2243204&clcid=0x409" -OUTFILE c:\wccit\teamsbootstrapper.exe
c:\wccit\teamsbootstrapper.exe -p
