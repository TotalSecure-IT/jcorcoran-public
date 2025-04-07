function Get-DirectorySize {
    param ([string]$Path)
    $size = Get-ChildItem -Path $Path -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum
    [math]::Round($size.Sum / 1GB, 2)
}

function Get-FolderSizes {
    param ([string]$Path = ".", [int]$Depth = 1)

    $systemFolders = @(
        "C:\Windows",
        "C:\Program Files",
        "C:\Program Files (x86)",
        "C:\Users\Administrator",
        "C:\Users\Default",
        "C:\Users\Public",
        "C:\ProgramData"
    )

    Get-ChildItem -Path $Path -Directory -Recurse -ErrorAction SilentlyContinue |
        Where-Object {
            ($systemFolders -notcontains $_.FullName) -and
            ($systemFolders -notcontains [System.IO.Path]::GetDirectoryName($_.FullName)) -and
            ($_.FullName -split '\\').Count -le ($Path -split '\\').Count + $Depth
        } |
        ForEach-Object {
            [PSCustomObject]@{
                Folder = $_.FullName
                SizeGB = Get-DirectorySize -Path $_.FullName
            }
        } |
        Sort-Object SizeGB -Descending |
        Select-Object -First 10
}

function Get-LargestFiles {
    param ([string]$Path = ".")

    Get-ChildItem -Path $Path -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object {
            ($_.FullName -notlike "C:\Windows\*") -and
            ($_.FullName -notlike "C:\Program Files\*") -and
            ($_.FullName -notlike "C:\Program Files (x86)\*") -and
            ($_.FullName -notlike "C:\Users\Administrator\*") -and
            ($_.FullName -notlike "C:\Users\Default\*") -and
            ($_.FullName -notlike "C:\Users\Public\*") -and
            ($_.FullName -notlike "C:\ProgramData\*")
        } |
        Sort-Object Length -Descending |
        Select-Object @{Name="FileName"; Expression={$_.FullName}}, @{Name="SizeGB"; Expression={[math]::Round($_.Length / 1GB, 2)}} -First 20
}

Write-Output "Top 10 Largest Folders (excluding critical system folders):"
$folders = Get-FolderSizes -Path "C:\" -Depth 2
$folders | Format-Table -AutoSize

Write-Output "`nTop 20 Largest Files (excluding critical system files):"
$files = Get-LargestFiles -Path "C:\"
$files | Format-Table -AutoSize
