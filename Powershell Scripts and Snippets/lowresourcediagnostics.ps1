###############################
# Combined Diagnostics Script #
# (Silent Operation)          #
###############################

# This script collects system info, performance metrics, installed software, network status,
# disk space, Windows update logs, running processes, and up to 50 unique events (from System & Application logs)
# that are Error or Critical and whose messages contain "driver", "network", or "update" (case-insensitive).
# Duplicate events (with different timestamps) are grouped (showing duplicate counts on one line).
#
# The entire diagnostic report is written to a log file.
# Run this script in an elevated PowerShell prompt.

#################################
# Configuration (Update as needed)
#################################

# Set the report output path:
$outputFile = "C:\DiagnosticsReport.txt"

#################################
# Script Begins Here
#################################

# Remove any existing report
if (Test-Path $outputFile) {
    Remove-Item $outputFile
}

# Helper function: Append text to the report file.
function Log-Output {
    param (
        [string]$message
    )
    Add-Content -Path $outputFile -Value $message
}

# Helper function: Write a section header.
function Write-SectionHeader {
    param (
        [string]$header
    )
    Log-Output "==============================="
    Log-Output $header
    Log-Output "==============================="
    Log-Output ""
}

# ----------------------------
# Performance Metrics Functions
# ----------------------------
function Get-CPUUsage {
    $cpuCounter = Get-Counter '\Processor(_Total)\% Processor Time'
    $cpuUsage = $cpuCounter.CounterSamples[0].CookedValue
    return [math]::Round($cpuUsage, 2)
}

function Get-MemoryUsage {
    $os = Get-CimInstance -ClassName Win32_OperatingSystem
    $totalMem = $os.TotalVisibleMemorySize
    $freeMem = $os.FreePhysicalMemory
    $usedMem = $totalMem - $freeMem
    $memUsage = ($usedMem / $totalMem) * 100
    return [math]::Round($memUsage, 2)
}

function Get-DiskUsage {
    $diskCounter = Get-Counter '\LogicalDisk(C:)\% Disk Time'
    $diskUsage = $diskCounter.CounterSamples[0].CookedValue
    return [math]::Round($diskUsage, 2)
}

function Get-PageFileUsage {
    $pageCounter = Get-Counter '\Paging File(_Total)\% Usage'
    $pageUsage = $pageCounter.CounterSamples[0].CookedValue
    return [math]::Round($pageUsage, 2)
}

function Get-TopProcesses {
    $topProcesses = Get-Process | Sort-Object CPU -Descending | Select-Object -First 5 -Property Name, CPU, Id
    return $topProcesses
}

# ----------------------------
# Collecting Diagnostics Data
# ----------------------------

# 1. System Information
Write-SectionHeader "System Information"
(Get-ComputerInfo) | Out-File -Append -FilePath $outputFile

# 2. Aggregated Filtered Recent Events (50 Unique Relevant Errors/Critical)
Write-SectionHeader "Filtered Recent Events (50 Unique Relevant Errors/Critical)"
# Initialize a hashtable to hold unique errors.
$uniqueErrors = @{}
$eventCounter = 0
$desiredUniqueCount = 50

# Scan the entire System and Application logs for Error (level 2) and Critical (level 1) events.
$allEvents = Get-WinEvent -FilterHashtable @{LogName=@("System", "Application"); Level=@(1,2)} | Sort-Object TimeCreated -Descending

foreach ($event in $allEvents) {
    $eventCounter++
    if ($event.Message -match '(?i)(driver|network|update)') {
         # Build a unique key using ProviderName, Event ID, and trimmed Message text.
         $key = $event.ProviderName + "|" + $event.Id + "|" + ($event.Message.Trim())
         if ($uniqueErrors.ContainsKey($key)) {
              $uniqueErrors[$key].Count++
         } else {
              $uniqueErrors[$key] = [PSCustomObject]@{
                     ProviderName = $event.ProviderName
                     TimeCreated  = $event.TimeCreated
                     Id           = $event.Id
                     Message      = $event.Message.Trim()
                     Count        = 1
              }
         }
         if ($uniqueErrors.Keys.Count -ge $desiredUniqueCount) {
              break
         }
    }
}

$uniqueErrorsArray = $uniqueErrors.Values | Sort-Object TimeCreated -Descending

if ($uniqueErrorsArray) {
    foreach ($error in $uniqueErrorsArray) {
         if ($error.Count -gt 1) {
              Log-Output ("[{0}] {1} (Event ID: {2}, {3}) - Occurred {4} times" -f $error.TimeCreated, $error.ProviderName, $error.Id, $error.Message, $error.Count)
         }
         else {
              Log-Output ("[{0}] {1} (Event ID: {2}) - {3}" -f $error.TimeCreated, $error.ProviderName, $error.Id, $error.Message)
         }
    }
} else {
    Log-Output "No matching recent events found."
}

# 3. Performance Metrics
Write-SectionHeader "Performance Metrics"
$cpuUsage  = Get-CPUUsage
$memUsage  = Get-MemoryUsage
$diskUsage = Get-DiskUsage
$pageUsage = Get-PageFileUsage
$topProcesses = Get-TopProcesses

Log-Output "CPU Usage: $cpuUsage %"
Log-Output "Memory Usage: $memUsage %"
Log-Output "Disk Activity (% Disk Time on C:): $diskUsage %"
Log-Output "Page File Usage: $pageUsage %"
Log-Output ""
Log-Output "Analysis:"
if ($cpuUsage -gt 80) { Log-Output " - High CPU usage detected. Look for any runaway processes." }
if ($memUsage -gt 80) { Log-Output " - High memory usage detected. This might indicate resource saturation or a memory leak." }
if ($diskUsage -gt 80) { Log-Output " - High disk activity detected. Check for disk bottlenecks." }
if ($pageUsage -gt 80) { Log-Output " - High page file usage detected. This suggests low physical memory." }
if (($cpuUsage -le 80) -and ($memUsage -le 80) -and ($diskUsage -le 80) -and ($pageUsage -le 80)) {
    Log-Output " - All key metrics are within normal ranges. Consider other causes such as background processes, driver issues, or hardware problems."
}
Log-Output ""
Log-Output "Top 5 Processes by CPU Usage:"
$topProcessesOutput = $topProcesses | Format-Table | Out-String
Log-Output $topProcessesOutput
Log-Output ""

# 4. Recently Installed Software
Write-SectionHeader "Recently Installed Software"
Get-WmiObject -Class Win32_Product | 
    Select-Object Name, InstallDate | 
    Sort-Object InstallDate -Descending | 
    Out-File -Append -FilePath $outputFile

# 5. Network Status
Write-SectionHeader "Network Status"
Test-Connection -ComputerName google.com -Count 4 | Out-File -Append -FilePath $outputFile

# 6. Disk Space Information
Write-SectionHeader "Disk Space Information"
Get-PSDrive -PSProvider FileSystem | 
    Select-Object Name, 
        @{Name="Used(GB)";Expression={[math]::round(($_.Used/1GB),2)}}, 
        @{Name="Free(GB)";Expression={[math]::round(($_.Free/1GB),2)}}, 
        @{Name="Total(GB)";Expression={[math]::round((($_.Used + $_.Free)/1GB),2)}} | 
    Out-File -Append -FilePath $outputFile

# 7. Windows Update Status
Write-SectionHeader "Windows Update Status"
$oldProgress = $ProgressPreference
$ProgressPreference = "SilentlyContinue"
Get-WindowsUpdateLog 2>$null | Out-File -Append -FilePath $outputFile
$ProgressPreference = $oldProgress

# 8. Running Processes
Write-SectionHeader "Running Processes"
Get-Process | Sort-Object CPU -Descending | Select-Object -First 20 Name, CPU, Id | Out-File -Append -FilePath $outputFile

# End of script.
