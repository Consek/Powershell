#Test open TCP port
Test-NetConnection $computer -Port 80 -InformationLevel Detailed


#Scanning TCP Ports
$From = 100
$To = 200
while($From -le $To){
    Write-Host "Port $i"
    Test-NetConnection $computer -Port $i -InformationLevel Quiet -WarningAction SilentlyContinue
    $i++
}

#Diagnose routing
Test-NetConnection -DiagnoseRouting $computer

#List interfaces
Get-NetIPInterface

#List routing table
Get-NetRoute

