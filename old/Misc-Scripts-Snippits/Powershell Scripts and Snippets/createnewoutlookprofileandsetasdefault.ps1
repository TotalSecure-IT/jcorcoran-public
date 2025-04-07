function Close-Outlook {
    $outlookProcess = Get-Process -Name "OUTLOOK" -ErrorAction SilentlyContinue
    if ($outlookProcess) {
        Write-Host "Closing Outlook..."
        Stop-Process -Name "OUTLOOK" -Force
        Start-Sleep -Seconds 5
    } else {
        Write-Host "No running Outlook instances found."
    }
}

Close-Outlook

$profileName = "ehogeland"
$emailAddress = "ehogeland@ymca.com"
$mailServer = "outlook.office365.com"
$profileKeyPath = "HKCU:\Software\Microsoft\Office\16.0\Outlook\Profiles"
$Outlook = New-Object -ComObject Outlook.Application
$Namespace = $Outlook.GetNamespace("MAPI")
$Namespace.Logon()
New-Item -Path $profileKeyPath -Name $profileName
$defaultProfilePath = "HKCU:\Software\Microsoft\Office\16.0\Outlook"
Set-ItemProperty -Path $defaultProfilePath -Name "DefaultProfile" -Value $profileName

$imapConfig = @"
[Internet Account Manager]
Account Name=$emailAddress
IMAP Server=$mailServer
SMTP Server=$mailServer
"@

$imapKeyPath = "$profileKeyPath\$profileName\9375CFF0413111d3B88A00104B2A6676"
New-Item -Path $imapKeyPath
Set-ItemProperty -Path $imapKeyPath -Name "Email Address" -Value $emailAddress
Set-ItemProperty -Path $imapKeyPath -Name "IMAP Server" -Value $mailServer

$Namespace.Logon($profileName)

$cachedModeKeyPath = "HKCU:\Software\Microsoft\Office\16.0\Outlook\Cached Mode"
Set-ItemProperty -Path $cachedModeKeyPath -Name "Enabled" -Value 1

Write-Host "New Outlook profile created and set as default."
