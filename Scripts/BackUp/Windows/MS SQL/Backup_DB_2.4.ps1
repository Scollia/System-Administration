# ===================================
# Версия 2.4
# От 22.07.2025
# Добавление отправки сообщения в несколько чатов
# Добавление отправки на Yandex
# От 20.07.2025
# Искенение состава и назначения основных переменных
# Добавлены комманды создания директорий
# От 02.07.2025
# Оформление отдельных этапов в виде функций
# От 01.07.2025
# Добавлена процедура копирвание на FTP по структуре конфигурационных каталогов
# ===================================

#============================================
# Подключение дополнительных модулей
#============================================
import-module sqlps -DisableNameChecking

#============================================
# Задание рабочих переменных
#============================================
# Задание параметров для Telegram бота
$tg_token    = "7961752155:AAF-nbKRclWy_mbjN-EhEzEsubE-EO-hkPE"
$tg_chats_id = ("-1002548730791_229", "-1002692695855")

# Yandex токен
$yandex_token = "y0__xDlk7wNGOWKOSD87LHwEzdJrK44_tFG58aDFWGaP3zTHAo6"

# Путь для хранения настроек
$conf_dir = "D:\Backups_SQL.conf"

# Место хранения логов
$tmp_log_dir    = "D:\Backups_SQL.log"
$tmp_backup_dir = "D:\Backups_SQL"
$net_backup_dir = "Microsoft.Powershell.Core\FileSystem::\\SRV-01\1c_Arch" 

# Количество дней хранения временных копий
$doktc = 1
# Количество дней хранения ежедневных копий
$dokdc = 14
# Количество дней хранения месячных копий
$dokmc = 365

# Сохранять на сетевом хранилище
$is_save_nat    = $true
# Сохранять на FTP
$is_save_ftp    = $false
# Сохранять на Yandex
$is_save_yandex = $false
#============================================
# Вычисляемые переменные
#============================================
# Имя сервера (компьютера)
$srv_name = $env:computername

# Текущая дата 
$today   = get-date
$lastDay = [DateTime]::DaysInMonth($today.Year, $today.Month)
$datelog = $today.ToString("yyyyMMdd")

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
    [string] $vMessage,
    [string] $vErr_Message
  )
  
  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

  $url_chat  = "https://api.telegram.org/bot$($tg_token)/"

  $Message = $vMessage
  if ($vErr_Message.Length -ge 600) {
    $Message = $Message + "<pre>" + $vErr_Message.Substring(0, 600) + "</pre>"
  } else {
    if ($vErr_Message.Length -gt 0) {
      $Message = $Message + "<pre>" + $vErr_Message + "</pre>"
    }
  }

  foreach ($vtg_chat_id in $tg_chats_id) {
    if ($vtg_chat_id.IndexOf("_") -gt 0) {
      $tg_chat_id           = $vtg_chat_id.Substring(0, $vtg_chat_id.IndexOf("_"))
      $tg_message_thread_id = $vtg_chat_id.Substring($vtg_chat_id.IndexOf("_") + 1)
    } else {
      $tg_chat_id           = $vtg_chat_id
      $tg_message_thread_id = ""
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
  $err_message = (Delete-DBArchive-in-Dir "$tmp_backup_dir" $doktc)

  $err_message = $err_message + (Delete-DBArchive-in-Dir "$($net_backup_dir)\$($srv_name)\Daily" $dokdc)


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
  Get-ChildItem "$tmp_backup_dir" | where { $_.LastAccessTime -ge ((Get-Date).AddDays(-$vdok)) } | %{ 
    try {
      Copy-Item "$($tmp_backup_dir)\$($_)" -Destination "$vdst_dir" -Exclude (Get-ChildItem "$vdst_dir") –Force
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
  $err_message = (Copy-DBArchive-to-NAT "$($net_backup_dir)\$($srv_name)\Daily" $dokdc)

  if ($today.Day -eq $lastDay) {
    # Последний в месяце
    $err_message = $err_message + (Copy-DBArchive-to-NAT "$($net_backup_dir)\$($srv_name)\Monthly" $dokmc)

    if ($today.Month -eq 12) {
      # Последний в году
      $err_message = $err_message + (Copy-DBArchive-to-NAT "$($net_backup_dir)\$($srv_name)\Yearly" $dokmc)
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
          Get-ChildItem -File -Path "$tmp_backup_dir" -Name "*$database_name*" | %{ 
            try {
              $webclient = New-Object System.Net.WebClient
              $webclient.Credentials = New-Object System.Net.NetworkCredential("$ftp_username", "$ftp_password")
              $webclient.UploadFile("$($ftp_url)/$($_)", "$($tmp_backup_dir)\$($_)")
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
          Get-ChildItem -File -Path "$tmp_backup_dir" -Name "*$database_name*" | %{ 
            try {
              $webclient = New-Object System.Net.WebClient
              $webclient.Credentials = New-Object System.Net.NetworkCredential("$ftp_username", "$ftp_password")
              $webclient.UploadFile("$($ftp_url)/$($_)", "$($tmp_backup_dir)\$($_)")
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
    $err_message = $err_message + (Copy-DBArchive-to-FTP "$conf_dir\ftp.conf\$ftp_name")
    if ($err_message -eq "") {
      $message  = $message + "Копирование файлов на ftp <b>" + $ftp_url + "</b>завершено успешно."
    } else {
      $message  = $message + "Копирование файлов на ftp <b>" + $ftp_url + "</b> завершено с ошибками:`n"
    }
  }

  return $err_message
}

#--------------------------------------------
# Функция копирования архивов на Yandex
#--------------------------------------------
function Copy-DBArchive-to-Yandex {
  $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
  $headers.Add("Authorization" ,"OAuth $($yandex_token)")
  $headers.Add("Content-Type","application/json")

  $err_message = ""

#  if (-not (Test-Path -Path "$vdst_dir")) { 
#    try {
#      New-Item -Path "$vdst_dir" -ItemType Directory
#    } catch {
#      $err_message  = "`n$($PSItem.Exception.Message)"
#      write-host "ERRO: Ошибка создания каталога $($vdst_dir)"
#    }
#  }

  write-host "---                Копирование файлов на Yandex диск                  ---"
  Get-ChildItem "$tmp_backup_dir" | where { $_.LastAccessTime -ge ((Get-Date).AddDays(-1)) } | %{ 
    try {
      #получаем от Яндекса URL для загрузки файла
      $UploadUrl= (Invoke-RestMethod -method GET -URI ("https://cloud-api.yandex.net:443/v1/disk/resources/upload?path=$($_)") -Headers $headers).href
write-host $UploadUrl
      #загружаем сам файл
      Invoke-WebRequest -uri $UploadUrl -Method Put -Infile "$($tmp_backup_dir)\$($_)" -ContentType 'application/zip'
#      Copy-Item "$($tmp_backup_dir)\$($_)" -Destination "$vdst_dir" -Exclude (Get-ChildItem "$vdst_dir") –Force

      write-host "INFO: Копирование файла $($_)"
    } catch {
      $err_message  = "`n$($PSItem.Exception.Message)"
      write-host "ERRO: Ошибка копирования файла $($_)"
    }
  }

  return $err_message
#---------------------------
  #путь к файлу
  $filepath = "D:\backup.zip"
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
$Response = (Send-Telegram $message $err_message)

# Удаление "устаревших" архивов
$message  = "<b>" + $srv_name + "</b>"
$err_message = (Delete-DBArchive-in-Dir-All)

if ($err_message -eq "") {
  $message  = $message + "`nУдаление устаревших файлов завершено успешно."
} else {
  $message  = $message + "`nУдаление устаревших файлов завершено с ошибками:"
}

$Response = (Send-Telegram $message $err_message)

if ($is_save_nat) {
  # Копирование архивов на сетевое хранилище
  $message  = "<b>" + $srv_name + "</b>"
  $err_message = (Copy-DBArchive-to-NAT-All)

  if ($err_message -eq "") {
    $message = $message + "`nКопирование файлов в сететевую папку завершено успешно."
  } else {
    $message = $message + "`nКопирование файлов в сететевую папку завершено с ошибками:"
  }

  $Response = (Send-Telegram $message $err_message)
}

if ($is_save_ftp) {
  # Копирование архивов на FTP
  $message  = "<b>" + $srv_name + "</b>"
  $err_message = (Copy-DBArchive-to-FTP-All)

  if ($err_message -eq "") {
    $message  = $message + "`nКопирование файлов на ftp завершено успешно."
  } else {
    $message  = $message + "`nКопирование файлов на ftp завершено с ошибками:"
  }

  $Response = (Send-Telegram $message $err_message)
}

if ($is_save_yandex) {
  # Копирование архивов на FTP
  $message  = "<b>" + $srv_name + "</b>"
  $err_message = (Copy-DBArchive-to-Yandex)

  if ($err_message -eq "") {
    $message  = $message + "`nКопирование файлов на Yandex диск завершено успешно."
  } else {
    $message  = $message + "`nКопирование файлов на Yandex диск завершено с ошибками:"
  }

  $Response = (Send-Telegram $message $err_message)
}
#============================================
# Завершение работы
#============================================

Stop-Transcript
Pop-Location
#Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Force
exit