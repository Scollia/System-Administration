# VPN-соединение установка параметров
$strVPNName = "My_VPN"

$vpn = Get-VpnConnection -Name $strVPNName;
Write-Host $vpn.ConnectionStatus
if ($vpn.ConnectionStatus -eq "Connected") {
  rasdial $strVPNName /disconnect;
  Write-Host $strVPNName " соединение завершено." -ForegroundColor Yellow -BackgroundColor DarkGreen
} else {
  Write-Host $strVPNName " соединение уже завершено." -ForegroundColor Yellow -BackgroundColor DarkGreen
}

Write-Host
Write-Host "ƒл€ завершени€ нажмите Enter"
$x = read-host
