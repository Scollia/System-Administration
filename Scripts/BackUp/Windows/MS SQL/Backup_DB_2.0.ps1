#If (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator"))
#{   
#    $arguments = "& '" + $myinvocation.mycommand.definition + "'"
#    Start-Process powershell -Verb runAs -ArgumentList $arguments
#    Break
#}
#Set-ExecutionPolicy -ExecutionPolicy Bypass -Force

#============================================
# Подключение дополнительных модулей
#============================================
import-module sqlps -DisableNameChecking

#============================================
# Дополнительные функции
#============================================
# Функция отправки сообщения в Telegram чат
function Send-Telegram {
  [CmdletBinding()]
  param(
    [Parameter()]  
    [string] $vtg_token,
    [string] $vtg_chat_id,
    [string] $vMessage
  )    

  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

#  write-host "https://api.telegram.org/bot$($vtg_token)/sendMessage?chat_id=$($vtg_chat_id)&text=$($vMessage)&parse_mode=html"
  $Response = Invoke-RestMethod -Uri "https://api.telegram.org/bot$($vtg_token)/sendMessage?chat_id=$($vtg_chat_id)&text=$($vMessage)&parse_mode=html" 
  return $Response    
}

#============================================
# Задание рабочих переменных
#============================================
# Место хранения логов
$tmp_log_dir = "E:\Backups_SQL.log"
$tmp_backup_dir = "E:\Backups_SQL"
$net_backup_dir = "Microsoft.Powershell.Core\FileSystem::\\SRV-NAS-242.CORP.TRBYTE.RU\1c_Archive" 

# Имя сервера (компьютера)
$srv_name = $env:computername

# Имена файлов для хранения списков баз данных
$include_db_file = "E:\Backups_SQL.conf\include_DB.conf"
$exclude_db_file = "E:\Backups_SQL.conf\exclude_DB.conf"
$list_db_file    = "E:\Backups_SQL.conf\list_DB"

# Количество дней хранения временных копий
$doktc = 1
# Количество дней хранения ежедневных копий
$dokdc = 14
# Количество дней хранения месячных копий
$dokmc = 365

# Текущая дата 
$today = get-date
$lastDay = [DateTime]::DaysInMonth($today.Year, $today.Month)
$datelog = $today.ToString("yyyyMMdd")

# Задание параметров для Telegram бота
$tg_token="5442649570:AAHO7-cxy5U6kCvaGIOZjNo8UwcozA4UA5E"
$tg_chat_id="-899082778"

#============================================
# Подготовка окружения
#============================================
# Запуск транскибирования в лог файл
Push-Location C:
Start-Transcript -Append -Path "$tmp_log_dir\$datelog.log"

# Чтение "Черных" и "Белых" списков баз данных
if (Test-Path -Path $include_db_file -PathType Leaf) { 
  $include_db = (Get-Content -path $include_db_file | ? {$_.trim() -ne "" })
} else {
  $include_db = ""
  Set-Content -Path $include_db_file -Value ""  
}
if (Test-Path -Path $exclude_db_file -PathType Leaf) { 
  $exclude_db = (Get-Content -path $exclude_db_file | ? {$_.trim() -ne "" })
} else {
  $exclude_db = ""
  Set-Content -Path $exclude_db_file -Value ""
}

# Чтение списка активных баз на серврвере баз данных
[System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMO') | out-null
$s = New-Object ('Microsoft.SqlServer.Management.Smo.Server')
$dbs=$s.Databases
$list_db = (New-Object ('Microsoft.SqlServer.Management.Smo.Server')).Databases | SELECT Name | Select-Object -ExpandProperty Name

# Сохранение списка активных баз в файл
Set-Content -Path $list_db_file -Value $list_db

# инициализация серевого протокола для отправки сообщений в Telegram
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

#============================================
# Создание архивов во временной локальной дитектории
#============================================
try {
  $err_message = ""

  if ($include_db.Count -eq 0) {
    write-host "---                Архивирование баз данных (""Черный список"")                ---"
    foreach ($database_name in $list_db) {
      if(-not ($database_name -in $exclude_db)) { 
        $Backup_name = $database_name + '_backup_' + ($today.ToString("yyyyMMdd_HHmmss_ffffff")) + '.bak'
        write-host "ПОДРОБНО: Выполнение операции ""Архивирование базы данных"" над целевым объектом"$database_name" в файл "$tmp_backup_dir\$Backup_name
       
#  #      $fr="BACKUP DATABASE " + $database_name + " TO DISK = N'" + $Backup_name + "'"
#  #      sqlcmd -E -W -Q ("BACKUP DATABASE " + $database_name + " TO DISK = N'" + $Backup_name + "' " + "WITH NOFORMAT, NOINIT, NAME = N'" + $Backup_name + "', SKIP, NOREWIND, NOUNLOAD, COMPRESSION, STATS = 10")
        try {
          Backup-SqlDatabase -ServerInstance $srv_name -Database $database_name -BackupFile $tmp_backup_dir\$Backup_name -CompressionOption on
        } catch {
          $err_message  = $err_message + "$($PSItem.Exception.Message)`n"
        }
      } else {
        write-host "ПОДРОБНО: Выполнение операции ""Пропуск архивирования базы данных"" над целевым объектом"$database_name
      }
    }
  } else {
    write-host "---                Архивирование баз данных (""Белый список"")                ---"
    foreach ($database_name in $list_db) {
      if($database_name -in $include_db) { 
        $Backup_name = $database_name + '_backup_' + ($today.ToString("yyyyMMdd_HHmmss_ffffff")) + '.bak'
        write-host "ПОДРОБНО: Выполнение операции ""Архивирование базы данных"" над целевым объектом"$database_name" в файл "$tmp_backup_dir\$Backup_name
       
#  #      $fr="BACKUP DATABASE " + $database_name + " TO DISK = N'" + $Backup_name + "'"
#  #      sqlcmd -E -W -Q ("BACKUP DATABASE " + $database_name + " TO DISK = N'" + $Backup_name + "' " + "WITH NOFORMAT, NOINIT, NAME = N'" + $Backup_name + "', SKIP, NOREWIND, NOUNLOAD, COMPRESSION, STATS = 10")
        try {
          Backup-SqlDatabase -ServerInstance $srv_name -Database $database_name -BackupFile $tmp_backup_dir\$Backup_name -CompressionOption on
        } catch {
          $err_message  = $err_message + "$($PSItem.Exception.Message)`n"
        }
      } else {
        write-host "ПОДРОБНО: Выполнение операции ""Пропуск архивирования базы данных"" над целевым объектом"$database_name
      }
    }
  }
} catch {
  $err_message  = "`n$($PSItem.Exception.Message)"
}

if ($err_message -eq "") {
  $message  = "Создание архивов БД на сервере <b>$srv_name </b> успешно завершено."
} else {
  $message  = "Создание архивов БД на сервере <b>$srv_name</b> завершено с ошибками:<pre>$($err_message.Substring(0, $err_message.Length - 1))</pre>"
}

$Response = (Send-Telegram $tg_token $tg_chat_id $Message)
#============================================
# Удаление "устаревших" архивов
#============================================
try {
  write-host "---                Удаление устаревших файлов (старше $dokdc) из сететевой папки $net_backup_dir\$srv_name\Daily\                 ---"
  Get-ChildItem $net_backup_dir\$srv_name\Daily | where { $_.LastAccessTime -lt ((Get-Date).AddDays(-$dokdc)) } | Remove-Item -Force -Verbose

  if ($today.Day -eq $lastDay) {
  # Последний в месяце
    write-host "---                Удаление устаревших файлов (старше $dokmc) из сететевой папки $net_backup_dir\$srv_name\Monthly\                 ---"
    Get-ChildItem $net_backup_dir\$srv_name\Monthly | where { $_.LastWriteTime -lt ((Get-Date).AddDays(-$dokmc)) } | Remove-Item -Force -Verbose
    if ($today.Month -eq 12) {
  # Последний в году
    }
  }

  write-host "---                Удаление устаревших файлов (старше $doktc) из временной папки $tmp_backup_dir                 ---"
  Get-ChildItem $tmp_backup_dir | where { $_.LastAccessTime -lt ((Get-Date).AddDays(-$doktc)) } | Remove-Item -Force -Verbose
  #LastWriteTime
  write-host "---                Удаление устаревших файлов (старше $doktc) из временной папки $tmp_log_dir                 ---"
  Get-ChildItem $tmp_log_dir | where { $_.LastAccessTime -lt ((Get-Date).AddDays(-$dokdc)) } | Remove-Item -Force -Verbose

  $message  = "Удаление устаревших файлов <b>$srv_name</b> успешно завершено."
  $Response = (Send-Telegram $tg_token $tg_chat_id $Message)
} catch {
  $message  = "Удаление устаревших файлов <b>$srv_name</b> завершено с ошибками."
  $Response = (Send-Telegram $tg_token $tg_chat_id $Message)
}

#============================================
# Копирование архивов на сетевое хранилище
#============================================
try {
  write-host "---                Копирование файлов в сететевую папку $net_backup_dir\$srv_name\Daily                 ---"
  Get-ChildItem $tmp_backup_dir | where { $_.LastAccessTime -ge ((Get-Date).AddDays(-$doktc)) } | Copy-Item -Destination $net_backup_dir\$srv_name\Daily -Exclude (Get-ChildItem "$net_backup_dir\$srv_name\Daily\") –Force -Verbose

  if ($today.Day -eq $lastDay) {
  # Последний в месяце
    write-host "---                Копирование файлов в сететевую папку $net_backup_dir\$srv_name\Monthly                 ---"
    Get-ChildItem $tmp_backup_dir | where { $_.LastAccessTime -ge ((Get-Date).AddDays(-$dokdc)) } | Copy-Item -Destination $net_backup_dir\$srv_name\Monthly -Exclude (Get-ChildItem "$net_backup_dir\$srv_name\Monthly\") –Force -Verbose
    if ($today.Month -eq 12) {
  # Последний в году
      write-host "---                Копирование файлов в сететевую папку $net_backup_dir\$srv_name\Yearly                 ---"
      Get-ChildItem $tmp_backup_dir | where { $_.LastAccessTime -ge ((Get-Date).AddDays(-$dokmc)) } | Copy-Item -Destination $net_backup_dir\$srv_name\Yearly -Exclude (Get-ChildItem "$net_backup_dir\$srv_name\Yearly\") –Force -Verbose
    }
  }
  
  $message  = "Копирование файлов в сететевые папки <b>$srv_name</b> успешно завершено."
  $Response = (Send-Telegram $tg_token $tg_chat_id $Message)
} catch {
  $message  = "Копирование файлов в сететевые папки <b>$srv_name</b> завершено с ошибками."
  $Response = (Send-Telegram $tg_token $tg_chat_id $Message)
}

#============================================
# Завершение работы
#============================================

Stop-Transcript
Pop-Location
#Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Force
exit