# Check for mode flags passed as arguments
if ($args -contains '--online-mode') {
    Write-Host "Mode:" -NoNewline
    Write-Host " ONLINE" -ForegroundColor Green
} elseif ($args -contains '--cached-mode') {
    Write-Host "Mode:" -NoNewline
    Write-Host " CACHED" -ForegroundColor Red
} else {
    Write-Host "No mode specified."
}
