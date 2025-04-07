$desiredQuota = 16384
$regSubPath = "SOFTWARE\Microsoft\Windows NT\CurrentVersion\Windows"

try {
    $regKey = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey($regSubPath, $true)
    if ($regKey) {
        $currentValue = $regKey.GetValue("GDIProcessHandleQuota", $null)
        if ($currentValue -ne $null) {
            $valueKind = $regKey.GetValueKind("GDIProcessHandleQuota")
            if ($valueKind -eq [Microsoft.Win32.RegistryValueKind]::DWord -and $currentValue -ne $desiredQuota) {
                $regKey.SetValue("GDIProcessHandleQuota", $desiredQuota, [Microsoft.Win32.RegistryValueKind]::DWord)
            }
        }
        $regKey.Close()
    }
} catch {}

try {
    $compSys = Get-CimInstance -ClassName Win32_ComputerSystem
    $compSys.AutomaticManagedPagefile = $false
    Set-CimInstance -InputObject $compSys
} catch {}

$initialSizeMB = 64 * 1024
$maxSizeMB = 72 * 1024

try {
    $pageFile = Get-WmiObject -Class Win32_PageFileSetting -Filter "Name = 'C:\\pagefile.sys'" -ErrorAction SilentlyContinue
    if (-not $pageFile) {
        $pageFileClass = [WmiClass]"\\.\root\cimv2:Win32_PageFileSetting"
        $pageFile = $pageFileClass.CreateInstance()
        $pageFile.Name = "C:\pagefile.sys"
    }
    $pageFile.InitialSize = $initialSizeMB
    $pageFile.MaximumSize = $maxSizeMB
    $null = $pageFile.Put()
} catch {}
