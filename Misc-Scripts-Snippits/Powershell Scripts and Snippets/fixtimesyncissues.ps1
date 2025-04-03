$manualPeers = "0.us.pool.ntp.org,1.us.pool.ntp.org,2.us.pool.ntp.org,3.us.pool.ntp.org"
& w32tm /config /syncfromflags:manual /manualpeerlist:"$manualPeers"
& w32tm /config /reliable:yes
Stop-Service w32time -Force
Start-Service w32time
& w32tm /resync /nowait