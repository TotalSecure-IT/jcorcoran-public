$folderPath = "c:\wccit"
if (-Not (Test-Path -Path $folderPath)) {
    New-Item -Path $folderPath -ItemType Directory
    Write-Output "Folder created at $folderPath"
} else {
    Write-Output "Folder already exists at $folderPath"
}
invoke-webrequest -URI https://ardownload2.adobe.com/pub/adobe/reader/win/AcrobatDC/2300320284/AcroRdrDC2300320284_en_US.exe -Outfile c:\wccit\AcroRdrDC2300320284_en_US.exe
c:\wccit\AcroRdrDC2300320284_en_US.exe /sAll /rs /msi EULA_ACCEPT=YES
