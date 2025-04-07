function Get-Config {
    param(
        [Parameter(Mandatory=$true)]
        [string]$workingDir
    )

    # Define the configuration file path
    $configFilePath = Join-Path $workingDir "configs\main.ini"

    # If the configuration file does not exist, alert the user and exit.
    if (-not (Test-Path -Path $configFilePath)) {
        Write-Error "Configuration file 'main.ini' is required and was not found in '$($workingDir)\configs'."
        exit 1
    }

    Write-Verbose "Reading configuration file: $configFilePath"
    $ini = @{}
    $lines = Get-Content $configFilePath

    foreach ($line in $lines) {
        $line = $line.Trim()
        # Skip empty lines and comments (lines starting with ; or #)
        if ([string]::IsNullOrEmpty($line) -or $line.StartsWith(";") -or $line.StartsWith("#")) {
            continue
        }
        # Skip section headers (e.g., [Section])
        if ($line.StartsWith("[")) {
            continue
        }
        # Use regex to parse key=value pairs. Accept quotes around value.
        if ($line -match "^\s*(\S+)\s*=\s*(.*)$") {
            $key = $matches[1].Trim()
            $value = $matches[2].Trim().Trim('"')
            $ini[$key] = $value
            Write-Verbose "Loaded key '$key' with value '$value'"
        }
        else {
            Write-Verbose "Skipping unrecognized line: $line"
        }
    }
    Write-Verbose "Total keys loaded: $($ini.Count)"
    return $ini
}

Export-ModuleMember -Function Get-Config
