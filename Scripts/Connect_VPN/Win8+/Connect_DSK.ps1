# VPN-соединение установка параметров
$strVPNName              = "My_VPN"
$strHost                 = "190.90.80.10"
$strIPSec                = "123456"
$strTunnelType           = "L2TP"
$strAuthenticationMethod = "MSChapv2"
$strEncryptionLevel      = "Maximum"
$strUserName             = $args[0]
$strUserPwd              = $args[1]

# Поиск VPN-соединения для проверки предыдущих установок
$vpnConnections = Get-VpnConnection #-AllUserConnection
if ($vpnConnections.Name -eq $strVPNName) {
  Write-Host $strVPNName " соединение уже настроено в вашей системе." -ForegroundColor Yellow -BackgroundColor DarkGreen
} else {
  try {
    # Создайем VPN-соединение $strVPNName
    Write-Host "Создайем VPN-подключения " $strVPNName -ForegroundColor Yellow -BackgroundColor DarkGreen
    Add-VpnConnection -Name $strVPNName -ServerAddress $strHost -TunnelType $strTunnelType -L2tpPsk $strIPSec -AuthenticationMethod $strAuthenticationMethod -EncryptionLevel $strEncryptionLevel -SplitTunneling $False -Force #-PassThru

    # Добавляем маршрут для VPN соединения до подсети рабочих станций
    Write-Host "Добавляем маршрут для VPN соединения до подсети рабочих станций (10.117.0.0/24)." -ForegroundColor Yellow -BackgroundColor DarkGreen
    Add-VpnConnectionRoute -ConnectionName $strVPNName -DestinationPrefix "10.117.0.0/24"

    # Добавляем маршрут для VPN соединения до подсети новых серверов
    Write-Host "Добавляем маршрут для VPN соединения до подсети рабочих станций (10.118.0.0/24)." -ForegroundColor Yellow -BackgroundColor DarkGreen
    Add-VpnConnectionRoute -ConnectionName $strVPNName -DestinationPrefix "10.118.0.0/24"

    Write-Host ""
    Write-Host "VPN-соединение " $strVPNName " готово к использованию." -ForegroundColor Black -BackgroundColor White
  } catch {
    Write-Host "Ошибка при настройке подключения!" -ForegroundColor White -BackgroundColor Red
    Write-Host $_.Exception.Message
    throw
    Write-Host
    Write-Host "Для завершения нажмите Enter"
    $x = read-host
    exit
  }
}

$vpn = Get-VpnConnection -Name $strVPNName;
if ($vpn.ConnectionStatus -eq "Disconnected") {
  rasdial $strVPNName $strUserName $strUserPwd;
  Write-Host $strVPNName " соединение установлено." -ForegroundColor Yellow -BackgroundColor DarkGreen
} else {
  Write-Host $strVPNName " соединение уже установлено." -ForegroundColor Yellow -BackgroundColor DarkGreen
}

Write-Host
Write-Host "Для завершения нажмите Enter"
$x = read-host
