# Check for mode flags passed as arguments
if ($args -contains '--online-mode') {
    Write-Host "Running in ONLINE mode"
} elseif ($args -contains '--cached-mode') {
    Write-Host "Running in CACHED mode"
} else {
    Write-Host "No mode specified."
}