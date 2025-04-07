function Get-Config {
    param(
        [Parameter(Mandatory=$true)]
        [string]$workingDir
    )

    # Define the configuration file path
    $configFilePath = Join-Path $workingDir "configs\main.ini"

    # If the configuration file does not exist, alert the user and exit.
    if (-not (Test-Path -Path $configFilePath)) {
        Write-Host "Configuration file 'main.ini' is required for all functionality." -ForegroundColor Red
        Write-Host "Please ensure that 'main.ini' exists in the 'configs' folder."
        Read-Host "Press Enter to exit..."
        exit 1
    }

    # Parse the INI file into a hashtable.
    $ini = @{}
    foreach ($line in Get-Content $configFilePath) {
        $line = $line.Trim()
        # Skip empty lines and comments (lines starting with ; or #)
        if ($line -eq "" -or $line.StartsWith(";") -or $line.StartsWith("#")) {
            continue
        }
        # Skip section headers (e.g., [Section])
        if ($line.StartsWith("[")) {
            continue
        }
        # Expect lines in the form key=value (optionally with spaces around '=')
        $pair = $line -split "=",2
        if ($pair.Length -eq 2) {
            $key = $pair[0].Trim()
            $value = $pair[1].Trim()
            $ini[$key] = $value
        }
    }
    return $ini
}

Export-ModuleMember -Function Get-Config
