# ===================================
# Версия 2.2
# От 01.07.2025
# Добавлена процедура копирвание на FTP по структуре конфигурационных каталогов
# От 02.07.2025
# Оформление отдельных этапов в виде функций
# ===================================

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
#--------------------------------------------
# Функция отправки сообщения в Telegram чат
#--------------------------------------------
function Send-Telegram {
  [CmdletBinding()]
  param(
    [Parameter()]  
    [string] $vtg_token,
    [string] $vtg_chat_id,
    [string] $vMessage
  )

  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

  if ($vtg_chat_id.IndexOf("_") -gt 0) {
    $vtg_message_thread_id = "&message_thread_id="+$vtg_chat_id.Substring($vtg_chat_id.IndexOf("_") + 1)
  } else {
    $vtg_message_thread_id = ""
  }

#  write-host "https://api.telegram.org/bot$($vtg_token)/sendMessage?chat_id=$($vtg_chat_id)&text=$($vMessage)&parse_mode=html"
  $Response = Invoke-RestMethod -Uri "https://api.telegram.org/bot$($vtg_token)/sendMessage?chat_id=$($vtg_chat_id)$($vtg_message_thread_id)&text=$($vMessage)&parse_mode=html" 
  return $Response
}

#--------------------------------------------
# Функция создания архивов во временной локальной дитектории
#--------------------------------------------
function Create-DBArchive-in-TmpDir {
  $err_message = ""
  try {
    if ($include_db.Count -eq 0) {
      write-host "---                Архивирование баз данных (""Черный список"")                ---"
      foreach ($database_name in $list_db) {
        if(-not ($database_name -in $exclude_db)) { 
          $Backup_name = $database_name + '_backup_' + ($today.ToString("yyyyMMdd_HHmmss_ffffff")) + '.bak'
          write-host "ПОДРОБНО: Выполнение операции ""Архивирование базы данных"" над целевым объектом"$database_name" в файл "$tmp_backup_dir\$Backup_name
          try {
            Backup-SqlDatabase -ServerInstance $srv_name -Database $database_name -BackupFile $tmp_backup_dir\$Backup_name -CompressionOption on
          } catch {
            $err_message = $err_message + "$($PSItem.Exception.Message)`n"
          }
        } else {
          write-host "ПОДРОБНО: Выполнение операции ""Пропуск архивирования базы данных"" над целевым объектом "$database_name
        }
      }
    } else {
      write-host "---                Архивирование баз данных (""Белый список"")                ---"
      foreach ($database_name in $list_db) {
        if($database_name -in $include_db) { 
          $Backup_name = $database_name + '_backup_' + ($today.ToString("yyyyMMdd_HHmmss_ffffff")) + '.bak'
          write-host "ПОДРОБНО: Выполнение операции ""Архивирование базы данных"" над целевым объектом"$database_name" в файл "$tmp_backup_dir\$Backup_name
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
    $err_message  = $err_message + "`n$($PSItem.Exception.Message)"
  }

  if ($err_message -eq "") {
    $message  = "Создание архивов БД на сервере <b>$srv_name </b> завершено успешно."
  } else {
    $message  = "Создание архивов БД на сервере <b>$srv_name</b> завершено с ошибками:<pre>$($err_message.Substring(0, $err_message.Length - 1))</pre>"
  }

  $Response = (Send-Telegram $tg_token $tg_chat_id $Message)
}

#--------------------------------------------
# Функция удаления "устаревших" архивов
#--------------------------------------------
function Delete-Old-DBArchive {
  [CmdletBinding()]
  param(
    [Parameter()]  
    [string] $work_dir,
    [string] $dok
  )

  $err_message = ""
  try {
    write-host "---                Удаление устаревших файлов (старше $dok) из папки $work_dir                 ---"
    Get-ChildItem "$work_dir" | where { $_.LastAccessTime -lt ((Get-Date).AddDays(-$dok)) } | Remove-Item -Force -Verbose
  } catch {
    $err_message  = "`n$($PSItem.Exception.Message)"
  }

  if ($err_message -eq "") {
    $message  = "Удаление устаревших файлов (старше $dok) из папки $work_dir на сервере <b>$srv_name</b> завершено успешно."
  } else {
    $message  = "Удаление устаревших файлов (старше $dok) из папки $work_dir на сервере <b>$srv_name</b> завершено с ошибками:<pre>$($err_message.Substring(0, $err_message.Length - 1))</pre>"
  }

  return $message
}

#--------------------------------------------
# Функция копирования архивов на сетевое хранилище
#--------------------------------------------
function Copy-DBArchive-to-NAT
  [CmdletBinding()]
  param(
    [Parameter()]  
    [string] $src_dir,
    [string] $dst_dir,
    [string] $dok
  )

  $err_message = ""
  try {
    write-host "---                Копирование файлов в сететевую папку $net_backup_dir\$srv_name\Daily                 ---"
    Get-ChildItem $src_dir | where { $_.LastAccessTime -ge ((Get-Date).AddDays(-$dok)) } | Copy-Item -Destination $dst_dir -Exclude (Get-ChildItem "$dst_dir") –Force -Verbose
  } catch {
    $err_message  = "`n$($PSItem.Exception.Message)"
  }

  if ($err_message -eq "") {
    $message  = "Копирование файлов (старше $dok) из папки $src_dir в папку $dst_dir на сервере <b>$srv_name</b> завершено успешно."
  } else {
    $message  = "Копирование файлов (старше $dok) из папки $src_dir в папку $dst_dir на сервере <b>$srv_name</b> завершено с ошибками:<pre>$($err_message.Substring(0, $err_message.Length - 1))</pre>"
  }

  return $message
}
#--------------------------------------------
# Функция копирования архивов на FTP
#--------------------------------------------
function Copy-DBArchive-to-FTP
  [CmdletBinding()]
  param(
    [Parameter()]  
    [string] $src_dir,
    [string] $ftp_conf_dir
  )

  $ftp_srv_comf_file      = "$ftp_conf_dir\server.conf"
  $include_db_to_ftp_file = "$ftp_conf_dir\include_DB.conf"
  $exclude_db_to_ftp_file = "$ftp_conf_dir\exclude_DB.conf"

  if (Test-Path -Path $ftp_srv_comf_file -PathType Leaf) { 
    $ftp_srv_comf = (Get-Content -path $ftp_srv_comf_file | ? {$_.trim() -ne "" })
  } else {
    $ftp_srv_comf = ""
    Set-Content -Path $ftp_srv_comf_file -Value ""  
  }
  $ftp_username = $ftp_srv_comf[0]
  $ftp_password = $ftp_srv_comf[1]
  $ftp_url      = $ftp_srv_comf[2]

  if (Test-Path -Path $include_db_to_ftp_file -PathType Leaf) { 
    $include_db_to_ftp = (Get-Content -path $include_db_to_ftp_file | ? {$_.trim() -ne "" })
  } else {
    $include_db_to_ftp = ""
    Set-Content -Path $include_db_to_ftp_file -Value ""  
  }

  if (Test-Path -Path $exclude_db_to_ftp_file -PathType Leaf) { 
    $exclude_db_to_ftp = (Get-Content -path $exclude_db_to_ftp_file | ? {$_.trim() -ne "" })
  } else {
    $exclude_db_to_ftp = ""
    Set-Content -Path $exclude_db_to_ftp_file -Value ""
  }

  if (-not ($ftp_url -eq "")) {
    $err_message = ""
    try {
      if ($include_db_to_ftp.Count -eq 0) {
        write-host "---                Копирование файлов на ftp $ftp_url (""Черный список"")                ---"
        foreach ($database_name in $list_db) {
          if(-not ($database_name -in $exclude_db_to_ftp)) { 
            write-host "ПОДРОБНО: Выполнение операции ""Копирование базы данных"" над целевым объектом "$database_name" на ftp"

            Get-ChildItem -File -Path $src_dir -Name "*$database_name*" | %{ 
              [System.Net.FtpWebRequest]$WR = [System.Net.WebRequest]::Create("$ftp_url/$_") 
              $WR.Method = [System.Net.WebRequestMethods+FTP]::UploadFile ;
              $WR.Credentials = New-Object System.Net.NetworkCredential($ftp_username, $ftp_password) ;
              $WR.UseBinary = $true
              $WR.UsePassive = $true

              try {
                $fileStream = [System.IO.File]::OpenRead("$src_dir/$_")
                $ftpRequestStream = $WR.GetRequestStream()

                $fileStream.CopyTo($ftpRequestStream)

                $ftpRequestStream.Close()
                $fileStream.Close()
              } catch {
                $err_message  = $err_message + "$($PSItem.Exception.Message)`n"
              }
            } 
          } else {
            write-host "ПОДРОБНО: Выполнение операции ""Пропуск копирования базы данных"" над целевым объектом "$database_name" на ftp"
          }
        }
      } else {
        write-host "---                Копирование файлов на ftp $ftp_url (""Белый список"")                ---"
        foreach ($database_name in $list_db) {
          if($database_name -in $include_db_to_ftp) { 
            write-host "ПОДРОБНО: Выполнение операции ""Копирование базы данных"" над целевым объектом "$database_name" Копирование файлов на ftp"

            Get-ChildItem -File -Path $src_dir -Name "*$database_name*" | %{ 
              [System.Net.FtpWebRequest]$WR = [System.Net.WebRequest]::Create("$ftp_url/$_") 
              $WR.Method = [System.Net.WebRequestMethods+FTP]::UploadFile ;
              $WR.Credentials = New-Object System.Net.NetworkCredential($ftp_username, $ftp_password) ;
              $WR.UseBinary = $true
              $WR.UsePassive = $true

              try {
                $fileStream = [System.IO.File]::OpenRead("$src_dir/$_")
                $ftpRequestStream = $WR.GetRequestStream()

                $fileStream.CopyTo($ftpRequestStream)

                $ftpRequestStream.Close()
                $fileStream.Close()
              } catch {
                $err_message  = $err_message + "$($PSItem.Exception.Message)`n"
              }
            } 
          } else {
            write-host "ПОДРОБНО: Выполнение операции ""Пропуск копирования базы данных"" над целевым объектом "$database_name" на ftp"
          }
        }
      }
    } catch {
      $err_message  = "`n$($PSItem.Exception.Message)"
    }

    if ($err_message -eq "") {
      $message  = "Копирование файлов c <b>$srv_name</b> на ftp <b>$ftp_url</b> завершено успешно."
    } else {
      $message  = "Копирование файлов c <b>$srv_name</b> на ftp <b>$ftp_url</b> завершено с ошибками:<pre>$($err_message.Substring(0, $err_message.Length - 1))</pre>"
    }

    return $message
  }
}

#============================================
# Задание рабочих переменных
#============================================
# Место хранения логов
$tmp_log_dir    = "E:\Backups_SQL.log"
$tmp_backup_dir = "E:\Backups_SQL"
$net_backup_dir = "Microsoft.Powershell.Core\FileSystem::\\SRV-NAS-242.CORP.TRBYTE.RU\1c_Archive" 

# Имя сервера (компьютера)
$srv_name = $env:computername

# Имена файлов для хранения списков баз данных
$include_db_file = "E:\Backups_SQL.conf\include_DB.conf"
$exclude_db_file = "E:\Backups_SQL.conf\exclude_DB.conf"
$list_db_file    = "E:\Backups_SQL.conf\list_DB"
$ftp_conf_dir    = "E:\Backups_SQL.conf\ftp.conf"

# Количество дней хранения временных копий
$doktc = 1
# Количество дней хранения ежедневных копий
$dokdc = 14
# Количество дней хранения месячных копий
$dokmc = 365

# Текущая дата 
$today   = get-date
$lastDay = [DateTime]::DaysInMonth($today.Year, $today.Month)
$datelog = $today.ToString("yyyyMMdd")

# Задание параметров для Telegram бота
$tg_token   = "5442649570:AAHO7-cxy5U6kCvaGIOZjNo8UwcozA4UA5E"
$tg_chat_id = "-1002276726102_2"

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
# Основное тело скрипта
#============================================
# Создание архивов во временной локальной дитектории
$message = (Create-DBArchive-in-TmpDir)
$Response = (Send-Telegram $tg_token $tg_chat_id $message)

# Удаление "устаревших" архивов
$message = ""

write-host "---                Удаление устаревших файлов (старше $dokdc) из сететевой папки $net_backup_dir\$srv_name\Daily\                 ---"
$message = $message + (Delete-Old-DBArchive "$net_backup_dir\$srv_name\Daily" $dokdc) + "`n"

if ($today.Day -eq $lastDay) {
  # Последний в месяце
  write-host "---                Удаление устаревших файлов (старше $dokmc) из сететевой папки $net_backup_dir\$srv_name\Monthly\                 ---"
  $message = $message + (Delete-Old-DBArchive "$net_backup_dir\$srv_name\Monthly" $dokmc) + "`n"

  if ($today.Month -eq 12) {
    # Последний в году
  }
}

write-host "---                Удаление устаревших файлов (старше $doktc) из временной папки $tmp_backup_dir                 ---"
$message = $message + (Delete-Old-DBArchive "$tmp_backup_dir" $doktc) + "`n"

write-host "---                Удаление устаревших файлов (старше $doktc) из временной папки $tmp_log_dir                 ---"
$message = $message + (Delete-Old-DBArchive "$tmp_log_dir" $dokdc)

$Response = (Send-Telegram $tg_token $tg_chat_id $message)

# Копирование архивов на сетевое хранилище
$message = ""

write-host "---                Копирование файлов в сететевую папку $net_backup_dir\$srv_name\Daily                 ---"
$message = $message + (Copy-DBArchive-to-NAT "$tmp_backup_dir" "$net_backup_dir\$srv_name\Daily" $dokdc) + "`n"

if ($today.Day -eq $lastDay) {
  # Последний в месяце
  write-host "---                Копирование файлов в сететевую папку $net_backup_dir\$srv_name\Monthly                 ---"
  $message = $message + (Copy-DBArchive-to-NAT "$tmp_backup_dir" "$net_backup_dir\$srv_name\Monthly" $dokmc) + "`n"

  if ($today.Month -eq 12) {
    # Последний в году
    write-host "---                Копирование файлов в сететевую папку $net_backup_dir\$srv_name\Yearly                 ---"
    $message = $message + (Copy-DBArchive-to-NAT "$tmp_backup_dir" "$net_backup_dir\$srv_name\Yearly" $dokmc)
  }
}

$Response = (Send-Telegram $tg_token $tg_chat_id $message)

# Копирование архивов на FTP
$message = ""

if (-not (Test-Path -Path "$ftp_conf_dir")) { 
  New-Item -Path "$ftp_conf_dir" -ItemType Directory
}

foreach ($ftp_name in Get-ChildItem $ftp_conf_dir) {
  $message = $message + (Copy-DBArchive-to-FTP "$tmp_backup_dir" "$ftp_conf_dir\$ftp_name") + "`n"
}

$Response = (Send-Telegram $tg_token $tg_chat_id $Message)

#============================================
# Завершение работы
#============================================

Stop-Transcript
Pop-Location
#Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Force
exit