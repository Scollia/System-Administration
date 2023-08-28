$ErrorActionPreference = "SilentlyContinue"

$username = "NewLocalAdmin"
$password = "NewLocalAdminPWD" | ConvertTo-SecureString -AsPlainText -Force 
$description = "Description"
$fullname = "Ful LocalAdmin Name"

if (Get-LocalUser | Where-Object {$_.Name -eq $username}) {
  write-host "Пользователь уже существует"
} else {
  New-LocalUser -Name $username -Password $password -FullName "$username" -Description "$description"
}