$Source = "E:\Users" #Change the source path to the hard drive you want to scan
$Destination = "G:\recovered" #Change the destination path to where you want to copy the images
$ImageTypes = @("*.jpg", "*.jpeg", "*.png", "*.bmp", "*.gif", "*.doc", "*.xlsx", "*.xls", "*.pdf", "*.docx", "*.odt", "*.rtf", "*.html", "*.xlr", "*.zip") #The list of image file types to search for

#Check if the destination folder exists, and create it if it doesn't
if (!(Test-Path -Path $Destination))
{
    New-Item -ItemType Directory -Path $Destination
}

#Get a list of all folders containing image files
$Folders = Get-ChildItem -Path $Source -Recurse | 
    Where-Object { $_.PSIsContainer } | 
    Where-Object { (Get-ChildItem $_.FullName -Recurse | Where-Object { $_.Extension -in $ImageTypes }) }

#Loop through each folder
foreach ($Folder in $Folders)
{
    #Get the relative path of the folder from the source folder
    $RelativePath = $Folder.FullName.Substring($Source.Length)

    #Build the full destination path
    $DestinationPath = Join-Path -Path $Destination -ChildPath $RelativePath

    #Copy the folder and its contents to the destination
    Copy-Item -Path $Folder.FullName -Destination $DestinationPath -Recurse
}