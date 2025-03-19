[CmdletBinding()]
param(
[Parameter(Mandatory=$true)]
[string[]]$UserAccounts,
[Parameter(ParameterSetName="set", Mandatory=$true)]
[switch]$SetOption,
[Parameter(ParameterSetName="remove", Mandatory=$true)]
[switch]$RemoveOption
)
 
foreach($UserAccount in $UserAccounts) {
try {
$UserObj = Get-ADUser -Identity $UserAccount -EA Stop -Properties PasswordNeverExpires
if($UserObj.PasswordNeverExpires) {
if($RemoveOption) {
Set-ADUser -Identity $UserAccount -PasswordNeverExpires:$false -EA Stop
Write-Host "$UserAccount : Successfully removed the password never expires option" -ForegroundColor Green
} else {
Write-Host "$UserAccount : Option already enabled" -ForegroundColor Yellow
}
} else {
if($SetOption) {
Set-ADUser -Identity $UserAccount -PasswordNeverExpires:$true -EA Stop
Write-Host "$UserAccount : Successfully enabled password never expires option" -ForegroundColor Green
} else {
Write-host "$UserAccount : Option already removed" -ForegroundColor Yellow
}
 
}
 
} catch {
Write-host "$UserAccount : Error Occurred. $_" -ForegroundColor Red
 
}
 
}