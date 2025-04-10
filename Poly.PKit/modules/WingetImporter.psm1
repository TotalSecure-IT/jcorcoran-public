# WingetImporter.psm1
# -----------------------------------------
# For "ONBOARD" action: downloads apps.json, downloads banner.txt,
# presents pinned banner, then runs winget to import from local apps.json.
# Export a single function: Invoke-Onboard

Export-ModuleMember -Function Invoke-Onboard

$Global:BannerBlankLines = 3  # number of empty lines below the banner

function Invoke-Onboard {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$appsJson,
        [Parameter(Mandatory=$true)][string]$folderName,
        [Parameter(Mandatory=$true)][string]$workingDir
    )
    <#
       Steps:
       1) Download apps.json => workingDir\orgs\$folderName\apps.json
       2) Download banner.txt => workingDir\orgs\$folderName\banner.txt
       3) Clear screen
       4) Present pinned banner region
       5) Call winget with local apps.json (using "import" instead of "-i")
       6) Continuously re-draw the banner region as winget outputs
    #>

    # 1) Download apps.json
    $orgFolder     = Join-Path (Join-Path $workingDir "orgs") $folderName
    if (-not (Test-Path $orgFolder)) {
        New-Item -ItemType Directory -Path $orgFolder | Out-Null
    }
    $appsJsonLocal = Join-Path $orgFolder "apps.json"

    try {
        Invoke-WebRequest -Uri $appsJson -OutFile $appsJsonLocal -UseBasicParsing -ErrorAction Stop
    }
    catch {
        Write-Host "Error downloading apps.json: $_" -ForegroundColor Red
        Write-Host "Press any key to return..."
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        return
    }

    # 2) Download banner.txt
    $bannerUrl   = "https://raw.githubusercontent.com/TotalSecure-IT/jcorcoran-public/refs/heads/main/Poly.PKit/orgs/$folderName/banner.txt"
    $bannerLocal = Join-Path $orgFolder "banner.txt"

    try {
        Invoke-WebRequest -Uri $bannerUrl -OutFile $bannerLocal -UseBasicParsing -ErrorAction Stop
    }
    catch {
        Write-Host "Error downloading banner.txt: $_" -ForegroundColor Yellow
        Write-Host "Proceeding without a banner..."
        $bannerLocal = $null
    }

    # 3) Clear screen
    Clear-Host

    # 4) Present pinned banner region
    if ($bannerLocal -and (Test-Path $bannerLocal)) {
        $Global:BannerLines = Get-Content $bannerLocal
    }
    else {
        $Global:BannerLines = @("No banner found for $folderName.")
    }

    # Option: Change this if you want a different background color.
    # Currently, "DarkBlue" is used.
    $BannerBackgroundColor = "DarkBlue"

    # We'll pin the banner at the top (line 0)
    $Global:BannerStartLine = 0

    function Redraw-Banner {
        param([System.Management.Automation.Host.Coordinates]$oldPos)
        $startY = $Global:BannerStartLine
        $oldCursor = $Host.UI.RawUI.CursorPosition
        if ($oldPos) { $oldCursor = $oldPos }
        for ($i = 0; $i -lt $Global:BannerLines.Count; $i++) {
            $Host.UI.RawUI.CursorPosition = [System.Management.Automation.Host.Coordinates]::new(0, $startY + $i)
            $line = $Global:BannerLines[$i]
            $width = $Host.UI.RawUI.WindowSize.Width
            $padded = $line.PadRight($width)
            # Change "DarkBlue" to a different color if needed.
            Write-Host $padded -NoNewline -ForegroundColor "Yellow" -BackgroundColor $BannerBackgroundColor
        }
        for ($j = 0; $j -lt $Global:BannerBlankLines; $j++) {
            $Host.UI.RawUI.CursorPosition = [System.Management.Automation.Host.Coordinates]::new(0, $startY + $Global:BannerLines.Count + $j)
            $width = $Host.UI.RawUI.WindowSize.Width
            $blankLine = " ".PadRight($width)
            Write-Host $blankLine -NoNewline -ForegroundColor "Yellow" -BackgroundColor $BannerBackgroundColor
        }
        $Host.UI.RawUI.CursorPosition = $oldCursor
    }

    Redraw-Banner

    # 5) Now, prepare and run winget to import using the downloaded apps.json
    # Updated command: use "winget import"
    $wingetCommand = "import `"$appsJsonLocal`" --accept-package-agreements --accept-source-agreements --disable-interactivity"
    # Prepare to run winget directly (without cmd /c)
    Write-Host "Starting winget install using: winget $wingetCommand" -ForegroundColor Green

    function Run-WingetWithBanner {
        param([string]$commandLine)
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = "winget"
        $psi.Arguments = $commandLine
        $psi.UseShellExecute = $false
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        $psi.CreateNoWindow = $true

        $proc = New-Object System.Diagnostics.Process
        $proc.StartInfo = $psi
        $proc.Start() | Out-Null

        while (-not $proc.HasExited) {
            if (-not $proc.StandardOutput.EndOfStream) {
                $line = $proc.StandardOutput.ReadLine()
                Write-Host $line
                Redraw-Banner
            }
            if (-not $proc.StandardError.EndOfStream) {
                $errLine = $proc.StandardError.ReadLine()
                if ($errLine) {
                    Write-Host $errLine -ForegroundColor Red
                    Redraw-Banner
                }
            }
            Start-Sleep -Milliseconds 50
        }
        while (-not $proc.StandardOutput.EndOfStream) {
            $line = $proc.StandardOutput.ReadLine()
            Write-Host $line
            Redraw-Banner
        }
        while (-not $proc.StandardError.EndOfStream) {
            $errLine = $proc.StandardError.ReadLine()
            Write-Host $errLine -ForegroundColor Red
            Redraw-Banner
        }
        $exitCode = $proc.ExitCode
        $proc.Dispose()
        return $exitCode
    }

    Write-Host "Press any key to begin winget install..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

    $exitCode = Run-WingetWithBanner -commandLine $wingetCommand
    Write-Host "winget install finished with exit code $exitCode"
    Write-Host "Press any key to continue..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

Export-ModuleMember -Function Invoke-Onboard
