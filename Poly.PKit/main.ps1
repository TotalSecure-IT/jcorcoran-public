# Clear the screen immediately upon launch
Clear-Host

# Set working directory to the parent of the script's folder (assumes main.ps1 is in the "init" folder)
$workingDir = Split-Path -Parent $PSScriptRoot
Set-Location $workingDir

# Check for mode flags passed as arguments and act accordingly
if ($args -contains '--online-mode') {
    Write-Host "Mode:" -NoNewline
    Write-Host " ONLINE" -ForegroundColor Green

    # In ONLINE mode, verbosely check/create the folder structure.
    # Note: "configs" should already exist since it contains secret offline files.
    $configsPath = Join-Path $workingDir "configs"
    if (-Not (Test-Path -Path $configsPath)) {
         Write-Host "Warning: 'configs' folder not found. It should exist prior to script launch." -ForegroundColor Yellow
    }
    else {
         Write-Host "'configs' folder exists."
    }

    # Create "Orgs" and "modules" folders if they do not exist.
    $folders = @("Orgs", "modules")
    foreach ($folder in $folders) {
        $folderPath = Join-Path $workingDir -ChildPath $folder
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
