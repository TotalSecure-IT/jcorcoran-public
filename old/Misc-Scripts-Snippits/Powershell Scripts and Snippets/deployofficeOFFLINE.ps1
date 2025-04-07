$odtUrl = "https://download.microsoft.com/download/2/7/A/27AF1BE6-DD20-4CB4-B154-EBAB8A7D4A7E/officedeploymenttool_17830-20162.exe"
$odtExePath = "$env:TEMP\OfficeDeploymentTool.exe"
$odtInstallPath = "C:\ODT"
$officeDownloadPath = "C:\Office365Offline"
$officeXMLPath = "$officeDownloadPath\Configuration.xml"
$officeInstallLog = "$officeDownloadPath\OfficeInstallLog.txt"

Invoke-WebRequest -Uri $odtUrl -OutFile $odtExePath
Start-Process -FilePath $odtExePath -ArgumentList "/quiet /extract:$odtInstallPath" -Wait

$xmlContent = @"
<Configuration>
    <Add OfficeClientEdition="64" Channel="Current" SourcePath="$officeDownloadPath">
        <Product ID="O365ProPlusRetail">
            <Language ID="en-us" />
        </Product>
    </Add>
    <Display Level="None" AcceptEULA="TRUE" />
    <Property Name="AUTOACTIVATE" Value="1" />
</Configuration>
"@
New-Item -Path $officeDownloadPath -ItemType Directory -Force
$xmlContent | Set-Content -Path $officeXMLPath

Start-Process -FilePath "$odtInstallPath\setup.exe" -ArgumentList "/download $officeXMLPath" -Wait
Start-Process -FilePath "$odtInstallPath\setup.exe" -ArgumentList "/configure $officeXMLPath /log $officeInstallLog" -Wait

Write-Host "Microsoft 365 Apps Suite installation complete."
