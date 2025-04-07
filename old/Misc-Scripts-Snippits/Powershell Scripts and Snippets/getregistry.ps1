# Define the start and end times for the filter
$startTime = Get-Date "March 12, 2025 07:55:00"
$endTime   = Get-Date "March 12, 2025 08:10:00"

# Define the output file (adjust path as needed)
$outputFile = ".\Events_Mar12_2025_0755-0810.txt"

# Remove the output file if it already exists
if (Test-Path $outputFile) {
    Remove-Item $outputFile -Force
}

# Define the specific logs to check
$logNames = @("Application", "System", "Security")

foreach ($logName in $logNames) {
    "=== Log: $logName ===" | Out-File $outputFile -Append
    try {
        # Build the filter hash table including LogName
        $filterHash = @{
            LogName   = $logName
            StartTime = $startTime
            EndTime   = $endTime
        }
        $events = Get-WinEvent -FilterHashtable $filterHash -ErrorAction Stop

        if ($events) {
            foreach ($event in $events) {
                $eventDetails = "TimeCreated: $($event.TimeCreated) | ID: $($event.Id) | Level: $($event.LevelDisplayName)`nMessage: $($event.Message)`n"
                $eventDetails | Out-File $outputFile -Append
            }
        } else {
            "No events found in this time range." | Out-File $outputFile -Append
        }
    }
    catch {
        "Error processing log: $logName. Exception: $($_.Exception.Message)" | Out-File $outputFile -Append
    }
    "----------------------------------------" | Out-File $outputFile -Append
}

Write-Output "Event extraction complete. Check the file: $outputFile"
