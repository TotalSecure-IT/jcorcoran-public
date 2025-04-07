# Clear the screen immediately upon launch
Clear-Host

# Ensure that we are in the same folder as the script (same as launcher.bat)
Set-Location $PSScriptRoot

# Check for mode flags passed as arguments and act accordingly
if ($args -contains '--online-mode') {
    Write-Host "Mode:" -NoNewline
    Write-Host " ONLINE" -ForegroundColor Green

    # Verbosely create the following folder structure if they do not exist:
    # configs, Orgs, and modules. (The logs and init folders are created by launcher.bat)
    $folders = @("configs", "Orgs", "modules")
    foreach ($folder in $folders) {
        $folderPath = Join-Path -Path $PSScriptRoot -ChildPath $folder
        if (-Not (Test-Path -Path $folderPath)) {
            Write-Host "Creating folder '$folder'..."
            New-Item -ItemType Directory -Path $folderPath | Out-Null
        }
        else {
            Write-Host "Folder '$folder' already exists."
        }
    }
}
elseif ($args -contains '--cached-mode') {
    Write-Host "Mode:" -NoNewline
    Write-Host " CACHED" -ForegroundColor Red
}
else {
    Write-Host "No mode specified."
}
