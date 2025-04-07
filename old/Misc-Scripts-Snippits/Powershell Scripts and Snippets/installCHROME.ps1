$folderPath = "c:\wccit"
if (-Not (Test-Path -Path $folderPath)) {
    New-Item -Path $folderPath -ItemType Directory
    Write-Output "Folder created at $folderPath"
} else {
    Write-Output "Folder already exists at $folderPath"
}
invoke-webrequest -URI https://dl.google.com/tag/s/appguid%3D%7B8A69D345-D564-463C-AFF1-A69D9E530F96%7D%26iid%3D%7B4878309C-5428-1B13-E68D-0269D2CEE65A%7D%26lang%3Den%26browser%3D4%26usagestats%3D0%26appname%3DGoogle%2520Chrome%26needsadmin%3Dprefers%26ap%3Dx64-stable%26brand=GCEA/dl/chrome/install/googlechromestandaloneenterprise64.msi -Outfile c:\wccit\googlechromestandaloneenterprise64.msi
msiexec.exe /i c:\wccit\googlechromestandaloneenterprise64.msi /qn /norestart
