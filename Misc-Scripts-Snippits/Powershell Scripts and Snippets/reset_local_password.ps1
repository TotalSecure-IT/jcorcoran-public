# Define variables
$Username = "LocalUser"
$NewPassword = "NewP@ssw0rd"
$SecureNewPassword = ConvertTo-SecureString $NewPassword -AsPlainText -Force
$ComputerName = $env:COMPUTERNAME

# Get the local user account object
$User = Get-LocalUser -Name $Username

# Set the new password for the account
Set-LocalUser -InputObject $User -Password $SecureNewPassword

# Display the new password to the console
Write-Host "The password for the account $Username on computer $ComputerName has been reset to $NewPassword."