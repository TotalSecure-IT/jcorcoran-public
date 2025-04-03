# Outputs
$tpm2 = "has TPM 2.0"
try {
    $Tpm = Get-WmiObject -Namespace "Root\CIMv2\Security\MicrosoftTpm" -Class Win32_Tpm -ErrorAction Stop
    if ($Tpm -ne $null) {
        if ($Tpm.SpecVersion -ge "2.0") {
            Write-Output "This computer has TPM 2.0 capability."
        } else {
            Write-Output "This computer has TPM, but it is not version 2.0. Detected version: $($Tpm.SpecVersion)"
        }
    } else {
        Write-Output "No TPM detected on this computer."
    }
} catch {
    Write-Output "Unable to detect TPM. Please ensure you have the appropriate permissions and that your system supports TPM."
}

