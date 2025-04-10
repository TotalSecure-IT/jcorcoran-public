# WingetImporter.psm1
# -----------------------------------------
# For "ONBOARD" action: downloads apps.json, downloads banner.txt,
# presents pinned banner, then runs winget to install from local apps.json.

# We'll have a single exported function:

$Global:BannerBlankLines = 3  # number of empty lines below the banner

function Invoke-Onboard {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$appsJson,
        [Parameter(Mandatory=$true)][string]$folderName,
        [Parameter(Mandatory=$true)][string]$workingDir
    )
    <#
       1) Download apps.json => workingDir\orgs\$folderName\apps.json
       2) Download banner.txt => workingDir\orgs\$folderName\banner.txt
       3) Clear screen
       4) Pinned banner region
       5) Call winget with local apps.json
       6) Keep re-drawing the banner region as winget scrolls
    #>

    # 1) Download apps.json
    $orgFolder       = Join-Path (Join-Path $workingDir "orgs") $folderName
    if (-not (Test-Path $orgFolder)) {
        New-Item -ItemType Directory -Path $orgFolder | Out-Null
    }
    $appsJsonLocal   = Join-Path $orgFolder "apps.json"

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
    $bannerUrl       = "https://raw.githubusercontent.com/TotalSecure-IT/jcorcoran-public/refs/heads/main/Poly.PKit/orgs/$folderName/banner.txt"
    $bannerLocal     = Join-Path $orgFolder "banner.txt"

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

    # We'll do a pinned region at the top of the console
    # We'll store the top line as $Global:BannerStartLine = 0, for instance.
    $Global:BannerStartLine = 0

    # Let's define a helper function to re-draw the banner region
    # We also insert $Global:BannerBlankLines lines after the banner content.
    function Redraw-Banner {
        param([System.Management.Automation.Host.Coordinates]$oldPos)
        # We'll forcibly overwrite lines from $BannerStartLine through
        # ($BannerStartLine + $BannerLines.Count + BannerBlankLines - 1).
        $startY = $Global:BannerStartLine
        $oldCursor = $Host.UI.RawUI.CursorPosition

        # If $oldPos was given, we restore to that eventually
        if ($oldPos) {
            $oldCursor = $oldPos
        }

        for ($i = 0; $i -lt $Global:BannerLines.Count; $i++) {
            $Host.UI.RawUI.CursorPosition = [System.Management.Automation.Host.Coordinates]::new(0, $startY + $i)
            $line = $Global:BannerLines[$i]
            # We'll pad or clear the line to avoid overlap
            $width = $Host.UI.RawUI.WindowSize.Width
            $padded = $line.PadRight($width)
            Write-Host $padded -NoNewline -ForegroundColor "Yellow" -BackgroundColor "DarkBlue"
        }
        # Now the blank lines
        for ($j = 0; $j -lt $Global:BannerBlankLines; $j++) {
            $Host.UI.RawUI.CursorPosition = [System.Management.Automation.Host.Coordinates]::new(0, $startY + $Global:BannerLines.Count + $j)
            $width = $Host.UI.RawUI.WindowSize.Width
            $blankLine = " ".PadRight($width)
            Write-Host $blankLine -NoNewline -ForegroundColor "Yellow" -BackgroundColor "DarkBlue"
        }

        # restore cursor
        $Host.UI.RawUI.CursorPosition = $oldCursor
    }

    # We'll do an initial draw
    Redraw-Banner

    # 5) Now we call winget to install from local apps.json
    # We'll intercept winget's output and keep re-drawing the banner region
    $wingetCommand = "winget import `"$appsJsonLocal`" --accept-package-agreements --accept-source-agreements --disable-interactivity"

    Write-Host "Starting winget install using: $wingetCommand" -ForegroundColor Green

    # We'll create a function that reads output line by line and re-draws the banner region after each line
    function Run-WingetWithBanner {
        param([string]$commandLine)

        # We'll start a process with redirected output so we can read line by line
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName  = "cmd.exe"
        $psi.Arguments = "/c $commandLine"
        $psi.UseShellExecute               = $false
        $psi.RedirectStandardOutput        = $true
        $psi.RedirectStandardError         = $true
        $psi.CreateNoWindow                = $true

        $p = New-Object System.Diagnostics.Process
        $p.StartInfo = $psi
        $p.Start() | Out-Null

        # Read output and error lines
        while (-not $p.HasExited) {
            # read a line from stdout
            if (-not $p.StandardOutput.EndOfStream) {
                $line = $p.StandardOutput.ReadLine()
                # We'll write it and re-draw the banner
                Write-Host $line
                Redraw-Banner
            }
            # read error lines if any
            if (-not $p.StandardError.EndOfStream) {
                $errLine = $p.StandardError.ReadLine()
                if ($errLine) {
                    Write-Host $errLine -ForegroundColor Red
                    Redraw-Banner
                }
            }
            Start-Sleep -Milliseconds 50
        }
        # final flush of leftover lines
        while (-not $p.StandardOutput.EndOfStream) {
            $line = $p.StandardOutput.ReadLine()
            Write-Host $line
            Redraw-Banner
        }
        while (-not $p.StandardError.EndOfStream) {
            $errLine = $p.StandardError.ReadLine()
            Write-Host $errLine -ForegroundColor Red
            Redraw-Banner
        }

        $exitCode = $p.ExitCode
        $p.Dispose()
        return $exitCode
    }

    Write-Host "Press any key to begin winget install..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

    $code = Run-WingetWithBanner -commandLine $wingetCommand
    Write-Host "winget install finished with exit code $code"
    Write-Host "Press any key to continue..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

Export-ModuleMember -Function Invoke-Onboard