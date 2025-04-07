Add-Type -AssemblyName PresentationCore,PresentationFramework

$query = @"
SELECT *
FROM __InstanceCreationEvent 
WITHIN 5 
WHERE TargetInstance ISA 'Win32_NTLogEvent'
  AND TargetInstance.EventCode = 24001
  AND (TargetInstance.Message LIKE '%Received Request Start Remote Control RC session%'
       OR TargetInstance.Message LIKE '%Received Request Get screen details%')
"@

Register-WmiEvent -Query $query -Action {
    $eventMessage = $Event.SourceEventArgs.NewEvent.TargetInstance.Message
    [System.Windows.MessageBox]::Show("Detected Event ID 24001 with message:`n`n$eventMessage", "New Event Detected", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
} | Out-Null

while ($true) { Start-Sleep -Seconds 5 }
