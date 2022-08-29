$ErrorActionPreference = "SilentlyContinue"

$ADUser = (([adsisearcher]"(&(objectCategory=User)(samaccountname=$env:username))").FindOne()).properties
$ADComp = [ADSI](([adsisearcher]"(&(objectCategory=computer)(samaccountname=$env:ComputerName$))").FindOne()).Path

$ADComp.Description.value=("" + $ADUser.cn + " {" + $ADUser.samaccountname + "}")

$ADComp.SetInfo()