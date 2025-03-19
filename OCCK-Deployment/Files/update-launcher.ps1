# Define GitHub raw URLs (replace with your actual GitHub repo URLs)
$GITHUB_RAW_URL_BAT = "https://raw.githubusercontent.com/TotalSecure-IT/jcorcoran-public/refs/heads/main/OCCK-Deployment/Files/occk-deploy-test.bat"
$GITHUB_RAW_URL_PS1 = "https://raw.githubusercontent.com/TotalSecure-IT/jcorcoran-public/refs/heads/main/OCCK-Deployment/Files/occk-deploy-test.ps1"

# Define local file paths
$SCRIPT_FOLDER = "$PSScriptRoot"
$LOCAL_BAT = "$SCRIPT_FOLDER\Occk-Deploy-Test.bat"
$LOCAL_PS1 = "$SCRIPT_FOLDER\Occk-Deploy-Test.ps1"

# Function to download and replace files
Function Update-File {
    param (
        [string]$Url,
        [string]$Destination
    )

    try {
        Write-Host "Downloading $Url..."
        Invoke-WebRequest -Uri $Url -OutFile $Destination -ErrorAction Stop
        Write-Host "Successfully updated: $Destination"
    }
    catch {
        Write-Host "Failed to update: $Destination"
        Write-Host $_.Exception.Message
    }
}

# Download the latest scripts
Update-File -Url $GITHUB_RAW_URL_BAT -Destination $LOCAL_BAT
Update-File -Url $GITHUB_RAW_URL_PS1 -Destination $LOCAL_PS1

# Launch Occk-Deploy.bat
Write-Host "Launching Occk-Deploy-Test.bat..."
Start-Process -FilePath $LOCAL_BAT -NoNewWindow -Wait
