# ===================================
# Версия 2.3
# От 20.07.2025
# Искенение состава и назначения основных переменных
# Добавлены комманды создания директорий
# От 02.07.2025
# Оформление отдельных этапов в виде функций
# От 01.07.2025
# Добавлена процедура копирвание на FTP по структуре конфигурационных каталогов
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
# Задание рабочих переменных
#============================================
# Место хранения логов
$tmp_log_dir    = "D:\Backups_SQL.log"
$tmp_backup_dir = "D:\Backups_SQL"
$net_backup_dir = "Microsoft.Powershell.Core\FileSystem::\\SRV-01\1c_Arch" 

# Имя сервера (компьютера)
$srv_name = $env:computername

# Путь для хранения настроек
$conf_dir	 = "D:\Backups_SQL.conf"

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
$tg_token   = "5442649570:AAECB61mW7S8YGAtlmW3JeQ2vt0hJ7_svoQ"
$tg_chat_id = "-1002548730791_229"

#============================================
# Подготовка окружения
#============================================
# Запуск транскибирования в лог файл
Push-Location C:
Start-Transcript -Append -Path "$tmp_log_dir\$datelog.log"

if (-not (Test-Path -Path "$conf_dir")) { 
  New-Item -Path "$conf_dir" -ItemType Directory
}

# Чтение "Черных" и "Белых" списков баз данных
if (Test-Path -Path "$conf_dir\include_DB.conf" -PathType Leaf) { 
  $include_db = (Get-Content -path "$conf_dir\include_DB.conf" | ? {$_.trim() -ne "" })
} else {
  $include_db = ""
  Set-Content -Path "$conf_dir\include_DB.conf" -Value ""  
}
if (Test-Path -Path "$conf_dir\exclude_DB.conf" -PathType Leaf) { 
  $exclude_db = (Get-Content -path "$conf_dir\exclude_DB.conf" | ? {$_.trim() -ne "" })
} else {
  $exclude_db = ""
  Set-Content -Path "$conf_dir\exclude_DB.conf" -Value ""
}

# Чтение списка активных баз на серврвере баз данных
[System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMO') | out-null
$s = New-Object ('Microsoft.SqlServer.Management.Smo.Server')
$dbs=$s.Databases
$list_db = (New-Object ('Microsoft.SqlServer.Management.Smo.Server')).Databases | SELECT Name | Select-Object -ExpandProperty Name

# Сохранение списка активных баз в файл
Set-Content -Path "$conf_dir\list_DB" -Value $list_db

# инициализация серевого протокола для отправки сообщений в Telegram
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

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
    [string] $vMessage,
    [string] $vErr_Message
  )
  
  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

  $url_chat  = "https://api.telegram.org/bot$($vtg_token)/"

  if ($vtg_chat_id.IndexOf("_") -gt 0) {
    $tg_chat_id           = $vtg_chat_id.Substring(0, $vtg_chat_id.IndexOf("_"))
    $tg_message_thread_id = $vtg_chat_id.Substring($vtg_chat_id.IndexOf("_") + 1)
  } else {
    $tg_chat_id           = $vtg_chat_id
    $tg_message_thread_id = ""
  }

  $Message = $vMessage
  if ($vErr_Message.Length -ge 600) {
    $Message = $Message + "<pre>" + $vErr_Message.Substring(0, 600) + "</pre>"
#    $Response = Invoke-RestMethod -Method Post -Uri "$($url_chat)&text=$($Message)&parse_mode=html" -ContentType 'multipart/form-data' -Body [byte]$file
    $Response = Invoke-RestMethod -Uri "$($url_chat)sendMessage?chat_id=$($tg_chat_id)&message_thread_id=$($tg_message_thread_id)&text=$($Message)&parse_mode=html"
  } else {
    if ($vErr_Message.Length -gt 0) {
      $Message = $Message + "<pre>" + $vErr_Message + "</pre>"
    }

    $Response = Invoke-RestMethod -Uri "$($url_chat)sendMessage?chat_id=$($tg_chat_id)&message_thread_id=$($tg_message_thread_id)&text=$($Message)&parse_mode=html"
  }

  return $Response
}

#--------------------------------------------
# Функция создания архивов во временной локальной дитектории
#--------------------------------------------
function Create-DBArchive {
  $err_message = ""

  if (-not (Test-Path -Path "$tmp_backup_dir")) { 
    New-Item -Path "$tmp_backup_dir" -ItemType Directory
  }

  if ($include_db.Count -eq 0) {
    write-host "---                Архивирование баз данных (`"Черный список`")                ---"
    foreach ($database_name in $list_db) {
      if (-not ($database_name -in $exclude_db)) { 
        $Backup_name = $database_name + '_backup_' + ($today.ToString("yyyyMMdd_HHmmss_ffffff")) + '.bak'
        try {
          Backup-SqlDatabase -ServerInstance $srv_name -Database $database_name -BackupFile $tmp_backup_dir\$Backup_name -CompressionOption on
          write-host "INFO: Архивирование базы данных $($database_name) в файл $($tmp_backup_dir)\$($Backup_name)"
        } catch {
          $err_message = $err_message + "`n$($PSItem.Exception.Message)"
          write-host "ERRO: Ошибка архивирования базы данных $($database_name) в файл $($tmp_backup_dir)\$($Backup_name)"
        }
      } else {
        write-host "INFO: Пропуск архивирования базы данных $($database_name)"
      }
    }
  } else {
    write-host "---                Архивирование баз данных (`"Белый список`")                ---"
    foreach ($database_name in $list_db) {
      if($database_name -in $include_db) { 
        $Backup_name = $database_name + '_backup_' + ($today.ToString("yyyyMMdd_HHmmss_ffffff")) + '.bak'
        try {
          Backup-SqlDatabase -ServerInstance $srv_name -Database $database_name -BackupFile $tmp_backup_dir\$Backup_name -CompressionOption on
          write-host "INFO: Архивирование базы данных $($database_name) в файл $($tmp_backup_dir)\$($Backup_name)"
        } catch {
          $err_message  = $err_message + "`n$($PSItem.Exception.Message)"
          write-host "ERRO: Ошибка архивирования базы данных $($database_name) в файл $($tmp_backup_dir)\$($Backup_name)"
        }
      } else {
        write-host "INFO: Пропуск архивирования базы данных $($database_name)"
      }
    }
  }

  return $err_message
}

#--------------------------------------------
# Функции удаления "устаревших" архивов
#--------------------------------------------
function Delete-DBArchive-in-Dir {
  [CmdletBinding()]
  param(
    [Parameter()]
    [string] $vwork_dir,
    [string] $vdok
  )

  $err_message = ""

  write-host "---                Удаление устаревших файлов (старше $($vdok)) из папки $($vwork_dir)                 ---"
  try {
    Get-ChildItem "$vwork_dir" | where { $_.LastAccessTime -lt ((Get-Date).AddDays(-$vdok)) } | %{ 
      try {
        Remove-Item "$($vwork_dir)\$($_)" -Force
        write-host "INFO: Удаление файла $($_)"
      } catch {
        $err_message  = "`n$($PSItem.Exception.Message)"
        write-host "ERRO: Ошибка удаления файла $($_)"
      }
    }
  } catch {
    $err_message  = "`n$($PSItem.Exception.Message)"
    write-host "ERRO: Ошибка удаления файлов из каталога $($vwork_dir)"
  }

  return $err_message
}

function Delete-DBArchive-in-Dir-All {
  $err_message = ""
  $err_message = (Delete-DBArchive-in-Dir "$($net_backup_dir)\$($srv_name)\Daily" $dokdc)

  if ($today.Day -eq $lastDay) {
    # Последний в месяце
    $err_message = $err_message + (Delete-DBArchive-in-Dir "$($net_backup_dir)\$($srv_name)\Monthly" $dokmc)

    if ($today.Month -eq 12) {
      # Последний в году
    }
  }

  return $err_message
}

#--------------------------------------------
# Функция копирования архивов на сетевое хранилище
#--------------------------------------------
function Copy-DBArchive-to-NAT {
  [CmdletBinding()]
  param(
    [Parameter()]  
    [string] $vsrc_dir,
    [string] $vdst_dir,
    [string] $vdok
  )

  $err_message = ""

  if (-not (Test-Path -Path "$vdst_dir")) { 
    try {
      New-Item -Path "$vdst_dir" -ItemType Directory
    } catch {
      $err_message  = "`n$($PSItem.Exception.Message)"
      write-host "ERRO: Ошибка создания каталога $($vdst_dir)"
    }
  }

  write-host "---                Копирование файлов в сететевую папку $($vdst_dir)                 ---"
  Get-ChildItem $vsrc_dir | where { $_.LastAccessTime -ge ((Get-Date).AddDays(-$vdok)) } | %{ 
    try {
      Copy-Item "$($vsrc_dir)\$($_)" -Destination "$vdst_dir" -Exclude (Get-ChildItem "$vdst_dir") –Force
      write-host "INFO: Копирование файла $($_)"
    } catch {
      $err_message  = "`n$($PSItem.Exception.Message)"
      write-host "ERRO: Ошибка копирования файла $($_)"
    }
  }

  return $err_message
}

function Copy-DBArchive-to-NAT-All {
  $err_message = ""
  $err_message = (Copy-DBArchive-to-NAT "$tmp_backup_dir" "$($net_backup_dir)\$($srv_name)\Daily" $dokdc)

  if ($today.Day -eq $lastDay) {
    # Последний в месяце
    $err_message = $err_message + (Copy-DBArchive-to-NAT "$tmp_backup_dir" "$($net_backup_dir)\$($srv_name)\Monthly" $dokmc)

    if ($today.Month -eq 12) {
      # Последний в году
      $err_message = $err_message + (Copy-DBArchive-to-NAT "$tmp_backup_dir" "$($net_backup_dir)\$($srv_name)\Yearly" $dokmc)
    }  
  }

  return $err_message
}
#--------------------------------------------
# Функция копирования архивов на FTP
#--------------------------------------------
function Copy-DBArchive-to-FTP {
  [CmdletBinding()]
  param(
    [Parameter()]  
    [string] $vsrc_dir,
    [string] $vftp_conf_dir
  )

  $ftp_srv_comf_file      = "$vftp_conf_dir\server.conf"
  $include_db_to_ftp_file = "$vftp_conf_dir\include_DB.conf"
  $exclude_db_to_ftp_file = "$vftp_conf_dir\exclude_DB.conf"

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
    if ($include_db_to_ftp.Count -eq 0) {
      write-host "---                Копирование файлов на $($ftp_url) (`"Черный список`")                ---"
      foreach ($database_name in $list_db) {
        if (-not ($database_name -in $exclude_db_to_ftp)) { 
          write-host "INFO: Копирование базы данных $($database_name)"
          Get-ChildItem -File -Path $vsrc_dir -Name "*$database_name*" | %{ 
            try {
#              [System.Net.FtpWebRequest]$WR = [System.Net.WebRequest]::Create("$($ftp_url)/$($_)") 
#              $WR.Method = [System.Net.WebRequestMethods+FTP]::UploadFile ;
#              $WR.Credentials = New-Object System.Net.NetworkCredential($ftp_username, $ftp_password) ;
#              $WR.UseBinary = $true
#              $WR.UsePassive = $true

#              $fileStream = [System.IO.File]::OpenRead("$($vsrc_dir)/$($_)")
#              $ftpRequestStream = $WR.GetRequestStream()

#              $fileStream.CopyTo($ftpRequestStream)

#              $ftpRequestStream.Close()
#              $fileStream.Close()

              $webclient = New-Object System.Net.WebClient
              $webclient.Credentials = New-Object System.Net.NetworkCredential("$ftp_username", "$ftp_password")
              $webclient.UploadFile("$($ftp_url)/$($_)", "$($vsrc_dir)\$($_)")
              
              $webclient.Dispose()

              write-host "INFO: Копирование файла $($_)"
            } catch {
              $err_message  = $err_message + "$($PSItem.Exception.Message)`n"
              write-host "ERRO: Ошибка копирования файла $($_)"
            }
          } 
        } else {
          write-host "INFO: Пропуск копирования базы данных $($database_name) на ftp"
        }
      }
    } else {
      write-host "---                Копирование файлов на ftp $($ftp_url) (`"Белый список`")                ---"
      foreach ($database_name in $list_db) {
        if($database_name -in $include_db_to_ftp) { 
          write-host "INFO: Копирование базы данных $($database_name)"
          Get-ChildItem -File -Path $vsrc_dir -Name "*$database_name*" | %{ 
            try {
#              [System.Net.FtpWebRequest]$WR = [System.Net.WebRequest]::Create("$($ftp_url)/$($_)") 
#              $WR.Method = [System.Net.WebRequestMethods+FTP]::UploadFile ;
#              $WR.Credentials = New-Object System.Net.NetworkCredential($ftp_username, $ftp_password) ;
#              $WR.UseBinary = $true
#              $WR.UsePassive = $true

#              $fileStream = [System.IO.File]::OpenRead("$($vsrc_dir)/$($_)")
#              $ftpRequestStream = $WR.GetRequestStream()

#              $fileStream.CopyTo($ftpRequestStream)

#              $ftpRequestStream.Close()
#              $fileStream.Close()

              $webclient = New-Object System.Net.WebClient
              $webclient.Credentials = New-Object System.Net.NetworkCredential("$ftp_username", "$ftp_password")
              $webclient.UploadFile("$($ftp_url)/$($_)", "$($vsrc_dir)\$($_)")

#write-host $ftp_username
#write-host $ftp_password
#write-host $uri
#write-host $tFile
#write-host "$($ftp_url)/$($_)"
#write-host "$($vsrc_dir)\$($_)"
              
              $webclient.Dispose()

              write-host "INFO: Копирование файла $($_)"
            } catch {
              $err_message  = $err_message + "$($PSItem.Exception.Message)`n"
              write-host "ERRO: Ошибка копирования файла $($_)"
            }
          } 
        } else {
          write-host "INFO: Пропуск копирования базы данных $($database_name)"
        }
      }
    }

    return $err_message
  }
}

function Copy-DBArchive-to-FTP-All {
  if (-not (Test-Path -Path "$conf_dir\ftp.conf")) { 
    New-Item -Path "$conf_dir\ftp.conf" -ItemType Directory
  }

  foreach ($ftp_name in Get-ChildItem "$conf_dir\ftp.conf") {
    $err_message = $err_message + (Copy-DBArchive-to-FTP "$tmp_backup_dir" "$conf_dir\ftp.conf\$ftp_name")
    if ($err_message -eq "") {
      $message  = $message + "Копирование файлов на ftp <b>" + $ftp_url + "</b>завершено успешно."
    } else {
      $message  = $message + "Копирование файлов на ftp <b>" + $ftp_url + "</b> завершено с ошибками:`n"
    }
  }

  return $err_message
}

#============================================
# Основное тело скрипта
#============================================
# Создание архивов во временной локальной дитектории
$message  = "<b>" + $srv_name + "</b>"
$err_message = (Create-DBArchive)

if ($err_message -eq "") {
  $message  = $message + "`nСоздание архивов БД завершено успешно."
} else {
  $message  = $message + "`nСоздание архивов БД завершено с ошибками:"
}
$Response = (Send-Telegram $tg_token $tg_chat_id $message $err_message)

# Удаление "устаревших" архивов
$message  = "<b>" + $srv_name + "</b>"
$err_message = (Delete-DBArchive-in-Dir-All)

if ($err_message -eq "") {
  $message  = $message + "`nУдаление устаревших файлов завершено успешно."
} else {
  $message  = $message + "`nУдаление устаревших файлов завершено с ошибками:"
}

$Response = (Send-Telegram $tg_token $tg_chat_id $message $err_message)

# Копирование архивов на сетевое хранилище
$message  = "<b>" + $srv_name + "</b>"
$err_message = (Copy-DBArchive-to-NAT-All)

if ($err_message -eq "") {
  $message = $message + "`nКопирование файлов завершено успешно."
} else {
  $message = $message + "`nКопирование файлов  завершено с ошибками:"
}

$Response = (Send-Telegram $tg_token $tg_chat_id $message $err_message)

# Копирование архивов на FTP
$message  = "<b>" + $srv_name + "</b>"
$err_message = Copy-DBArchive-to-FTP-All

if ($err_message -eq "") {
  $message  = $message + "`nКопирование файлов на ftp завершено успешно."
} else {
  $message  = $message + "`nКопирование файлов на ftp завершено с ошибками:"
}

$Response = (Send-Telegram $tg_token $tg_chat_id $message $err_message)
#============================================
# Завершение работы
#============================================

Stop-Transcript
Pop-Location
#Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Force
exit