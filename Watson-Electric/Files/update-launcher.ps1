# Define GitHub raw URLs (replace with your actual GitHub repo URLs)
$GITHUB_RAW_URL_BAT = "https://raw.githubusercontent.com/TotalSecure-IT/jcorcoran-public/refs/heads/main/CCA-Deployment/Files/CCA-Deploy.bat"
$GITHUB_RAW_URL_PS1 = "https://raw.githubusercontent.com/TotalSecure-IT/jcorcoran-public/refs/heads/main/CCA-Deployment/Files/CCA-Deploy.ps1"
$GITHUB_RAW_URL_BANNER = "https://raw.githubusercontent.com/TotalSecure-IT/jcorcoran-public/refs/heads/main/CCA-Deployment/Files/banner.txt"

# Define local file paths
$SCRIPT_FOLDER = "$PSScriptRoot"
$LOCAL_BAT = "$SCRIPT_FOLDER\CCA-Deploy.bat"
$LOCAL_PS1 = "$SCRIPT_FOLDER\CCA-Deploy.ps1"
$LOCAL_BANNER = "$SCRIPT_FOLDER\banner.txt"

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
Update-File -Url $GITHUB_RAW_URL_BANNER -Destination $LOCAL_BANNER

# Launch CCA-Deploy.bat
Write-Host "Launching CCA-Deploy.bat..."
Start-Process -FilePath $LOCAL_BAT -NoNewWindow -Wait
