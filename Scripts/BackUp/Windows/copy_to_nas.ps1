#If (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator"))
#{   
#    $arguments = "& '" + $myinvocation.mycommand.definition + "'"
#    Start-Process powershell -Verb runAs -ArgumentList $arguments
#    Break
#}
#Set-ExecutionPolicy -ExecutionPolicy Bypass -Force
Push-Location C:

$tmp_backup_dir = "E:\Daily"
$tmp_log_dir = "E:\log"
$net_backup_dir = "Microsoft.Powershell.Core\FileSystem::\\corp.dskvrn.ru\1C_Files\Архивы баз" 
#$net_backup_dir = "Microsoft.Powershell.Core\FileSystem::\\SRV-NAS-132\1c_Archive"
$srv_name = $env:computername
$today = get-date
$lastDay = [DateTime]::DaysInMonth($today.Year, $today.Month)
# Days of keeping temporary copies
$doktc = 1
# Days of keeping daily copies
$dokdc = 30
# Days of keeping monthly copies
$dokmc = 365

$datelog = $today.ToString("yyyyMMdd")
Start-Transcript -Append -Path "$tmp_log_dir\LogCopy_$datelog.log" #Место хранения лога

write-host "---                Удаление устаревших файлов (старше $dokdc) из сететевой папки $net_backup_dir\$srv_name\Daily\                 ---"
Get-ChildItem $net_backup_dir\$srv_name\Daily | where { $_.LastAccessTime -lt ((Get-Date).AddDays(-$dokdc)) } | Remove-Item -Force -Verbose
write-host "---                Копирование файлов в сететевую папку $net_backup_dir\$srv_name\Daily                 ---"
Get-ChildItem $tmp_backup_dir | where { $_.LastAccessTime -ge ((Get-Date).AddDays(-$doktc)) } | Copy-Item -Destination $net_backup_dir\$srv_name\Daily -Exclude (Get-ChildItem "$net_backup_dir\$srv_name\Daily\") –Force -Verbose

if ($today.Day -eq $lastDay) {
#  Write-Host Последний в месяце
  write-host "---                Удаление устаревших файлов (старше $dokmc) из сететевой папки $net_backup_dir\$srv_name\Monthly\                 ---"
  Get-ChildItem $net_backup_dir\$srv_name\Monthly | where { $_.LastWriteTime -lt ((Get-Date).AddDays(-$dokmc)) } | Remove-Item -Force -Verbose
  write-host "---                Копирование файлов в сететевую папку $net_backup_dir\$srv_name\Monthly                 ---"
  Get-ChildItem $tmp_backup_dir | where { $_.LastAccessTime -ge ((Get-Date).AddDays(-$dokdc)) } | Copy-Item -Destination $net_backup_dir\$srv_name\Monthly -Exclude (Get-ChildItem "$net_backup_dir\$srv_name\Monthly\") –Force -Verbose
  if ($today.Month -eq 12) {
#    Write-Host Последний в году
    write-host "---                Копирование файлов в сететевую папку $net_backup_dir\$srv_name\Yearly                 ---"
    Get-ChildItem $tmp_backup_dir | where { $_.LastAccessTime -ge ((Get-Date).AddDays(-$dokmc)) } | Copy-Item -Destination $net_backup_dir\$srv_name\Yearly -Exclude (Get-ChildItem "$net_backup_dir\$srv_name\Yearly\") –Force -Verbose
      }
} else {
#  Write-Host "Обычный"
}


write-host "---                Удаление устаревших файлов (старше $doktc) из временной папки $tmp_backup_dir                 ---"
Get-ChildItem $tmp_backup_dir | where { $_.LastAccessTime -lt ((Get-Date).AddDays(-$doktc)) } | Remove-Item -Force -Verbose
#LastWriteTime
write-host "---                Удаление устаревших файлов (старше $doktc) из временной папки $tmp_log_dir                 ---"
Get-ChildItem $tmp_log_dir | where { $_.LastAccessTime -lt ((Get-Date).AddDays(-$dokdc)) } | Remove-Item -Force -Verbose

Stop-Transcript
Pop-Location
#Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Force
exit