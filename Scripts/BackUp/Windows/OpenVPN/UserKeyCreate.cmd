echo off 
SetLocal EnableExtensions
setlocal EnableDelayedExpansion

if "%1" EQU "" (
  Echo Должен быть задан хотя бы один входной параметр
  exit
)

set "bcert=<cert>"
set "ecert=</cert>"
set "bkey=<key>"
set "ekey=</key>"

set user_name=%1

rem cd C:\Program Files\OpenVPN\easy-rsa
rem EasyRSA-Start.bat
rem ./easyrsa gen-req %user_name%
rem ./easyrsa sign-req client %user_name% nopass

copy "C:\Program Files\OpenVPN\sample-config\client_def.ovpn" "D:\VPN_Key\%user_name%.ovpn"

echo. >> "D:\VPN_Key\%user_name%.ovpn"
echo !bcert!>> "D:\VPN_Key\%user_name%.ovpn"
type "C:\Program Files\OpenVPN\easy-rsa\pki\issued\%user_name%.crt" >> "D:\VPN_Key\%user_name%.ovpn"
echo !ecert!>> "D:\VPN_Key\%user_name%.ovpn"

echo. >> "D:\VPN_Key\%user_name%.ovpn"
echo !bkey!>> "D:\VPN_Key\%user_name%.ovpn"
type "C:\Program Files\OpenVPN\easy-rsa\pki\private\%user_name%.key" >> "D:\VPN_Key\%user_name%.ovpn"
echo !ekey!>> "D:\VPN_Key\%user_name%.ovpn"
