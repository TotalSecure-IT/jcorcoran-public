$filePath    = "\\Jcorcoran-tiny\data\monitor.txt"
$serviceName = "wuauserv"  # psqlWGE
$logDirectory = Split-Path $filePath

while ($true) {
    try {
        $iterationTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $logMessage = "Iteration started at $iterationTime`r`n"
        $logMessage += "Attempting to read from file: $filePath`r`n"
        
        $value = (Get-Content -Path $filePath -ErrorAction Stop).Trim().ToLower()
        $logMessage += "Value read from file: '$value'`r`n"
        
        if ($value -eq "true") {
            $logMessage += "Trigger detected: value is 'true'. Restarting service: $serviceName.`r`n"
            $logMessage += "About to restart service '$serviceName' with -Force.`r`n"
            
            Restart-Service -Name $serviceName -Force -ErrorAction Stop
            $logMessage += "Service '$serviceName' restarted successfully.`r`n"
            $logMessage += "Updating file content to 'false'.`r`n"
            
            Set-Content -Path $filePath -Value "false"
            $logMessage += "File updated successfully to 'false'.`r`n"
            
            # Create and write the success log file with a timestamp
            $timestampForFile = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
            $logFileName = "Success - $timestampForFile.txt"
            $logFilePath = Join-Path -Path $logDirectory -ChildPath $logFileName
            Set-Content -Path $logFilePath -Value $logMessage
        }
        elseif ($value -eq "false") {
            # No trigger – nothing to do
        }
        else {
            # Invalid content scenario
            $logMessage += "Error: Invalid content in file. Expected 'true' or 'false', but got '$value'.`r`n"
            
            # Write a failure log file for the invalid input
            $timestampForFile = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
            $logFileName = "Failure - $timestampForFile.txt"
            $logFilePath = Join-Path -Path $logDirectory -ChildPath $logFileName
            Set-Content -Path $logFilePath -Value $logMessage
            
            # Update the file to false to prevent repeated logging of the same error
            Set-Content -Path $filePath -Value "false"
        }
    }
    catch {
        # This catch block handles any exceptions, such as a failed service restart.
        $iterationTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $logMessage = "Iteration started at $iterationTime`r`n"
        $logMessage += "Exception encountered: $($_.Exception.Message)`r`n"
        
        $timestampForFile = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
        $logFileName = "Failure - $timestampForFile.txt"
        $logFilePath = Join-Path -Path $logDirectory -ChildPath $logFileName
        Set-Content -Path $logFilePath -Value $logMessage
        
        # Reset the file to avoid processing the error repeatedly.
        Set-Content -Path $filePath -Value "false"
    }
    
    Start-Sleep -Seconds 5
}
