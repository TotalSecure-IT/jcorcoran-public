#Show error record of most recent error
$Error[0] | Format-List -Property * -Force

#Show error record of all errors
$Error | Format-List -Property * -Force

#Show error record of all errors in a table format
$Error | Format-Table -Property * -Force

#Show error record of all errors in a table format with specific properties
$Error | Format-Table -Property CategoryInfo, FullyQualifiedErrorId, ScriptStackTrace, Exception -Force

#Show error record of all errors in a table format with specific properties and no header
$Error | Format-Table -Property CategoryInfo, FullyQualifiedErrorId, ScriptStackTrace, Exception -Force -HideTableHeaders

#Group services by their status and display the result in a table format with wrapped text
Get-Service | Group-Object -Property Status | Format-Table -Wrap

# Open the standard input stream
$inputStream = [Console]::OpenStandardInput()
try {
    # Create a buffer to read data from the input stream
    $buffer = [byte[]]::new(1024)
    # Read data from the input stream into the buffer
    $read = $inputStream.Read($buffer, 0, $buffer.Length)
    # Display the read data in hexadecimal format
    Format-Hex -InputObject $buffer -Count $read
} finally {
    # Dispose of the input stream to release resources
    $inputStream.Dispose()
}

#Get the current date and time in UTC format
$utcDateTime = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ" -AsUTC

#Warning Message
$m = "This action can delete data."
Write-Warning -Message $m

#Warning with confirmation prompt
$WarningPreference = "Inquire"
$m = "This action can delete data."
Write-Warning -Message $m

#Prompt when a warning occurs
$m = "This action can delete data."
Write-Warning -Message $m -WarningAction Inquire

#Send Success, Warning, and Error streams to a file
&{
    Write-Warning "hello"
    Write-Error "hello"
    Write-Output "hi"
 } 3>&1 2>&1 > C:\Temp\redirection.log

# Download the file and save it
$uri = 'https://github.com/PowerShell/PowerShell/releases/download/v7.3.7/powershell-7.3.7-linux-arm64.tar.gz'
curl -s -L $uri > powershell.tar.gz

#Download and extract the file in one command
curl -s -L $uri | tar -xzvf - -C .

#Alternatively, you can use Invoke-WebRequest to download the file and extract it in one command
(Invoke-WebRequest $uri).Content | tar -xzvf - -C .

#Alternatively, you can use Invoke-WebRequest to download the file and extract it in one command with a different method
,(Invoke-WebRequest $uri).Content | tar -xzvf - -C .

#Write-Progress cmdlet displays a progress bar
https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/write-progress?view=powershell-7.5

#Display the progress of a `for` loop
for ($i = 1; $i -le 100; $i++ ) {
    Write-Progress -Activity "Search in Progress" -Status "$i% Complete:" -PercentComplete $i
    Start-Sleep -Milliseconds 250
}

#Display the progress while searching for a string in the System log
# Use Get-WinEvent to get the events in the System log and store them in the $Events variable.
$Events = Get-WinEvent -LogName System
# Pipe the events to the ForEach-Object cmdlet.
$Events | ForEach-Object -Begin {
    # In the Begin block, use Clear-Host to clear the screen.
    Clear-Host
    # Set the $i counter variable to zero.
    $i = 0
    # Set the $out variable to an empty string.
    $out = ""
} -Process {
    # In the Process script block search the message property of each incoming object for "bios".
    if($_.Message -like "*bios*")
    {
        # Append the matching message to the out variable.
        $out=$out + $_.Message
    }
    # Increment the $i counter variable which is used to create the progress bar.
    $i = $i+1
    # Determine the completion percentage
    $Completed = ($i/$Events.Count) * 100
    # Use Write-Progress to output a progress bar.
    # The Activity and Status parameters create the first and second lines of the progress bar
    # heading, respectively.
    Write-Progress -Activity "Searching Events" -Status "Progress:" -PercentComplete $Completed
} -End {
    # Display the matching messages using the out variable.
    $out
}

#Create a self-signed certificate for code signing
#This example creates a self-signed certificate for code signing and stores it in the current user's personal certificate store.
$params = @{
    Subject = 'CN=PowerShell Code Signing Cert'
    Type = 'CodeSigning'
    CertStoreLocation = 'Cert:\CurrentUser\My'
    HashAlgorithm = 'sha256'
}
$cert = New-SelfSignedCertificate @params

#To use this script, copy the following text into a text file, and name it Add-Signature.ps1.
#Signs a file
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string] $File
)
$cert = Get-ChildItem Cert:\CurrentUser\My -CodeSigningCert |
    Select-Object -First 1
Set-AuthenticodeSignature -FilePath $File -Certificate $cert

#To sign the Add-Signature.ps1 script file, type the following commands at the PowerShell command prompt:
$cert = Get-ChildItem Cert:\CurrentUser\My -CodeSigningCert |
    Select-Object -First 1
Set-AuthenticodeSignature Add-Signature.ps1 $cert




