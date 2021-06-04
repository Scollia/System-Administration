$ErrorActionPreference = "SilentlyContinue"

$ADUser = (([adsisearcher]"(&(objectCategory=User)(samaccountname=$env:username))").FindOne()).properties
$ADComp = [ADSI](([adsisearcher]"(&(objectCategory=computer)(samaccountname=$env:ComputerName$))").FindOne()).Path

$ADComp.Description.value=($env:username)
#$ADComp.Description.value=($ADUser.samaccountname)
#$ADComp.managedBy.value =$ADUser.distinguishedName

$ADComp.SetInfo()