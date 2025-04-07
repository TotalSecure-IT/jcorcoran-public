$create_shortcut = (New-Object -ComObject WScript.Shell).CreateShortcut
$s = $create_shortcut.invoke("c:\users\public\desktop\Synced Tool.lnk")
$s.TargetPath = "C:\Synced Tool" 
$s.IconLocation = "imageres.dll,3"
$s.Description = "Monitor Forms"
$s.Save()