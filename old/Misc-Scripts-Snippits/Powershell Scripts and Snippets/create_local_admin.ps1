# Define variables
$Username = "NewAdmin"
$Password = ConvertTo-SecureString "P@ssw0rd" -AsPlainText -Force

# Create new local user account
New-LocalUser -Name $Username -Password $Password -FullName "New Administrator Account" -Description "Local administrator account"

# Add the new account to the local Administrators group
Add-LocalGroupMember -Group "Administrators" -Member $Username
