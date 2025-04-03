$folderPath = "c:\wccit"
if (-Not (Test-Path -Path $folderPath)) {
    New-Item -Path $folderPath -ItemType Directory
    Write-Output "Folder created at $folderPath"
} else {
    Write-Output "Folder already exists at $folderPath"
}
invoke-webrequest -URI https://www.kyoceradocumentsolutions.com/asia/download/driver/Kx84_UPD_8.4.1716_en_RC5_WHQL.zip -Outfile C:\wccit\kyoceradriver.zip
