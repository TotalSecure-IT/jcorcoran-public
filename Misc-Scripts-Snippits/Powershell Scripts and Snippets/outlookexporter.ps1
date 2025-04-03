$exportFile = "C:\Temp\Export.PST"

$outlook = new-object -comobject outlook.application
$namespace = $outlook.GetNameSpace("MAPI")
$inbox = $namespace.GetDefaultFolder(6)

$namespace.AddStore($exportFile)
$exportFolderID = ($namespace.folders | where{$_.FolderPath -eq "\\jcorcoran-pc\testshare"}).EntryID
$exportPST = $namespace.GetFolderFromID($exportFolderID)
$exportPSTFolder = $exportPST.Folders.Add("Exported")

$messages = $inbox.items | where{$_.Subject -like "*GDPR*"}

Foreach($Message in $Messages){$messages.Move($exportPSTFolder)}