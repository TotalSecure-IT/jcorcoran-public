# Set the SelectiveSuspendEnabled registry value to 0 (disabled)
New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\USB" -Name "SelectiveSuspendEnabled" -Value 0 -PropertyType DWORD -Force | Out-Null

# Restart the USB host controller
Restart-Service -Name "UsbHub3" -Force