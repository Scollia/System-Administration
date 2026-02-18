$ErrorActionPreference = "SilentlyContinue"
$LastLogoff=Get-Date -format "dd.MM.yyy HH:mm:ss"

$ADUser = (([adsisearcher]"(&(objectCategory=User)(samaccountname=$env:username))").FindOne()).properties
$ADComp = [ADSI](([adsisearcher]"(&(objectCategory=computer)(samaccountname=$env:ComputerName$))").FindOne()).Path

$ADComp.Description.value=("* " + $ADUser.cn + " {" + $ADUser.samaccountname + "} [" + $LastLogoff + "] ")

$ADComp.SetInfo()