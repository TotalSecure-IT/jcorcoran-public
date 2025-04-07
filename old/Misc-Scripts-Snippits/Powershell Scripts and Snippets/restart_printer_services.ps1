# Get the printing services
$Services = Get-Service -DisplayName "Print Spooler","LPR Port Monitor","LPR Remote Port Monitor","Internet Printing Client"

# Restart each printing service
foreach ($Service in $Services) {
    Restart-Service $Service.Name -Force
}