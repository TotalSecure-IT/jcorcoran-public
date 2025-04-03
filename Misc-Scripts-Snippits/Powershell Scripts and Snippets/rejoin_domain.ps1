# Define variables
$DomainName = "yourdomain.com"
$DomainUser = "yourdomainadmin"
$DomainPassword = "yourdomainadminpassword"
$ComputerName = $env:COMPUTERNAME

# Prompt for domain administrator credentials
$Credential = Get-Credential -UserName $DomainUser -Message "Enter domain administrator credentials"

# Unjoin the computer from the domain
$UnjoinOptions = [System.DirectoryServices.ActiveDirectory.UnjoinOptions]::LeaveSourceDC
Remove-Computer -UnjoinDomainCredential $Credential -PassThru -Verbose -Restart -Force

# Wait for the computer to restart
Start-Sleep -Seconds 60

# Join the computer to the domain
$JoinOptions = New-Object System.DirectoryServices.ActiveDirectory.JoinOptions
$JoinOptions += [System.DirectoryServices.ActiveDirectory.JoinOptions]::JoinWithNewName
$JoinOptions += [System.DirectoryServices.ActiveDirectory.JoinOptions]::AccountCreate
$JoinOptions += [System.DirectoryServices.ActiveDirectory.JoinOptions]::BypassInstallCheck
Add-Computer -DomainName $DomainName -Credential $Credential -NewName $ComputerName -Options $JoinOptions -Verbose -Restart -Force