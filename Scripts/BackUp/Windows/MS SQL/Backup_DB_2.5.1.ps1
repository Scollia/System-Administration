# ===================================
# ������ 2.5.2
# 
# �� 06.08.2025
# ��������� ��������� ��������� ������� ��� ���������� �� NAS
# �� 26.07.2025
# ������������ ��� ���������, ��������� � ������������
# �� 22.07.2025
# ���������� �������� ��������� � ��������� �����
# ���������� �������� �� Yandex
# �� 20.07.2025
# ��������� ������� � ���������� �������� ����������
# ��������� �������� �������� ����������
# �� 02.07.2025
# ���������� ��������� ������ � ���� �������
# �� 01.07.2025
# ��������� ��������� ���������� �� FTP �� ��������� ���������������� ���������
# ===================================

#============================================
# ����������� �������������� �������
#============================================
import-module sqlps -DisableNameChecking

#============================================
# ������� ������� ����������
#============================================
$tg_bots      = New-Object 'System.Collections.Generic.List[System.Object]'
$nas_servers  = New-Object 'System.Collections.Generic.List[System.Object]'
$ftp_servers  = New-Object 'System.Collections.Generic.List[System.Object]'
$yandex_disks = New-Object 'System.Collections.Generic.List[System.Object]'

# ���� ��� �������� ��������
$conf_dir       = "D:\Backups_SQL.conf"
# ����� �������� �����
$tmp_log_dir    = "D:\Backups_SQL.log"
# ����� �������� ������� ������� (��������� �����)
$tmp_backup_dir = "D:\Backups_SQL"

# ���������� ���� �������� ��������� �����
$doktc = 1

# ���������� ��������� � Telegram
$is_send_telegram  = $true
# ��������� �� ������� ��������� NAS
$is_save_nas       = $true
# ��������� �� FTP ������
$is_save_ftp       = $false
# ��������� �� Yandex ����
$is_save_yandex    = $false
#============================================
# ����������� ����������
#============================================
# ��� ������� (����������)
$srv_name = $env:computername

# ������� ���� 
$today   = get-date
$lastDay = [DateTime]::DaysInMonth($today.Year, $today.Month)
$datelog = $today.ToString("yyyyMMdd")

#============================================
# ���������� ���������
#============================================
# ������ ���������������� � ��� ����
Push-Location C:
Start-Transcript -Append -Path "$tmp_log_dir\$datelog_.log"

if (-not (Test-Path -Path "$conf_dir")) { 
  New-Item -Path "$conf_dir" -ItemType Directory
}

# ������������� �������� ��������� ��� �������� ��������� � Telegram
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

#============================================
# �������� ���������� ������������
#============================================
#--------------------------------------------
# ������ ������ �������� ��� �� ��������� ��� ������
#--------------------------------------------
[System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMO') | out-null
$s       = New-Object ('Microsoft.SqlServer.Management.Smo.Server')
$dbs     = $s.Databases
$list_db = (New-Object ('Microsoft.SqlServer.Management.Smo.Server')).Databases | SELECT Name | Select-Object -ExpandProperty Name

# ���������� ������ �������� ��� � ����
Set-Content -Path "$conf_dir\list_DB" -Value $list_db

#--------------------------------------------
# ������ "������" � "�����" ������� ��� ������
#--------------------------------------------
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

#--------------------------------------------
# ������ ���������� ��� Telegram ����
#--------------------------------------------
if (-not (Test-Path -Path "$conf_dir")) { 
  New-Item -Path "$conf_dir\tg.conf" -ItemType Directory
}

foreach ($tg_conf_file in Get-ChildItem "$conf_dir\tg.conf") {
  $tg_conf = (Get-Content -path "$conf_dir\tg.conf\$tg_conf_file" | ? {$_.trim() -ne "" })
  
  $tg_bots.add( @{tg_token = $tg_conf[0]; chats_id = ($tg_conf[1].split("[, ]", [StringSplitOptions]::RemoveEmptyEntries))})
}

#--------------------------------------------
# ������ ���������� ��� ���������� �� ����� nas
#--------------------------------------------
if (-not (Test-Path -Path "$conf_dir\nas.conf")) { 
  New-Item -Path "$conf_dir\nas.conf" -ItemType Directory
}

foreach ($nas_disk_conf_dir in Get-ChildItem "$conf_dir\nas.conf") {
  $nas_srv_conf_file      = "$conf_dir\nas.conf\$nas_disk_conf_dir\server.conf"
  $include_db_to_nas_file = "$conf_dir\nas.conf\$nas_disk_conf_dir\include_DB.conf"
  $exclude_db_to_nas_file = "$conf_dir\nas.conf\$nas_disk_conf_dir\exclude_DB.conf"

  if (Test-Path -Path $nas_srv_conf_file -PathType Leaf) { 
    $nas_srv_conf = (Get-Content -path "$nas_srv_conf_file" | ? {$_.trim() -ne "" })
  
    if (Test-Path -Path $include_db_to_nas_file -PathType Leaf) { 
      $include_db_to_nas = (Get-Content -path $include_db_to_nas_file | ? {$_.trim() -ne "" })
    } else {
      $include_db_to_nas = ""
      Set-Content -Path $include_db_to_nas_file -Value ""  
    }

    if (Test-Path -Path $exclude_db_to_nas_file -PathType Leaf) { 
      $exclude_db_to_nas = (Get-Content -path $exclude_db_to_nas_file | ? {$_.trim() -ne "" })
    } else {
      $exclude_db_to_nas = ""
      Set-Content -Path $exclude_db_to_nas_file -Value ""
    }
    $nas_servers.add( @{net_backup_dir = "$($nas_srv_conf[0])"; dokdc = $nas_srv_conf[1]; dokwc = $nas_srv_conf[2]; dokmc = $nas_srv_conf[3]; include_db_to = $include_db_to_nas; exclude_db_to = $exclude_db_to_nas})
  } else {
    $nas_srv_conf = ""
    Set-Content -Path $nas_srv_conf_file -Value ""  
  }
}

#--------------------------------------------
# ������ ���������� ��� ���������� �� ����� ftp
#--------------------------------------------
if (-not (Test-Path -Path "$conf_dir\ftp.conf")) { 
  New-Item -Path "$conf_dir\ftp.conf" -ItemType Directory
}

foreach ($ftp_disk_conf_dir in Get-ChildItem "$conf_dir\ftp.conf") {
  $ftp_srv_conf_file      = "$conf_dir\ftp.conf\$ftp_disk_conf_dir\server.conf"
  $include_db_to_ftp_file = "$conf_dir\ftp.conf\$ftp_disk_conf_dir\include_DB.conf"
  $exclude_db_to_ftp_file = "$conf_dir\ftp.conf\$ftp_disk_conf_dir\exclude_DB.conf"

  if (Test-Path -Path $ftp_srv_conf_file -PathType Leaf) { 
    $ftp_srv_conf = (Get-Content -path "$ftp_srv_conf_file" | ? {$_.trim() -ne "" })
  
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

    $ftp_servers.add( @{ftp_url = $ftp_srv_conf[0]; ftp_username = $ftp_srv_conf[1]; ftp_password = $ftp_srv_conf[2]; include_db_to = $include_db_to_ftp; exclude_db_to = $exclude_db_to_ftp})
  } else {
    $ftp_srv_conf = ""
    Set-Content -Path $ftp_srv_conf_file -Value ""  
  }
}

#--------------------------------------------
# ������ ���������� ��� ���������� �� ����� Yandex
#--------------------------------------------
if (-not (Test-Path -Path "$conf_dir\yandex.conf")) { 
  New-Item -Path "$conf_dir\yandex.conf" -ItemType Directory
}

foreach ($yandex_disk_conf_dir in Get-ChildItem "$conf_dir\yandex.conf") {
  $yandex_srv_conf_file      = "$conf_dir\yandex.conf\$yandex_disk_conf_dir\server.conf"
  $include_db_to_yandex_file = "$conf_dir\yandex.conf\$yandex_disk_conf_dir\include_DB.conf"
  $exclude_db_to_yandex_file = "$conf_dir\yandex.conf\$yandex_disk_conf_dir\exclude_DB.conf"

  if (Test-Path -Path $yandex_srv_conf_file -PathType Leaf) { 
    $yandex_srv_conf = (Get-Content -path "$yandex_srv_conf_file" | ? {$_.trim() -ne "" })
  
    if (Test-Path -Path $include_db_to_yandex_file -PathType Leaf) { 
      $include_db_to_yandex = (Get-Content -path $include_db_to_yandex_file | ? {$_.trim() -ne "" })
    } else {
      $include_db_to_yandex = ""
      Set-Content -Path $include_db_to_yandex_file -Value ""  
    }

    if (Test-Path -Path $exclude_db_to_yandex_file -PathType Leaf) { 
      $exclude_db_to_yandex = (Get-Content -path $exclude_db_to_yandex_file | ? {$_.trim() -ne "" })
    } else {
      $exclude_db_to_yandex = ""
      Set-Content -Path $exclude_db_to_yandex_file -Value ""
    }

    $yandex_disks.add( @{yandex_token = $yandex_srv_conf[0]; path = $yandex_srv_conf[1]; include_db_to = $include_db_to_yandex; exclude_db_to = $exclude_db_to_yandex})
  } else {
    $yandex_srv_conf = ""
    Set-Content -Path $yandex_srv_conf_file -Value ""  
  }
}

#============================================
# �������������� �������
#============================================
#--------------------------------------------
# ������� �������� ��������� � Telegram ���
#--------------------------------------------
function Send-Telegram {
  [CmdletBinding()]
  param(
    [Parameter()]  
    [string] $vMessage,
    [string] $vErr_Message
  )
  
  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

  $Message = $vMessage
  if ($vErr_Message.Length -ge 600) {
    $Message = $Message + "<pre>" + $vErr_Message.Substring(0, 600) + "</pre>"
  } else {
    if ($vErr_Message.Length -gt 0) {
      $Message = $Message + "<pre>" + $vErr_Message + "</pre>"
    }
  }

  foreach ($tg_bot in $tg_bots) {
    $url_chat  = "https://api.telegram.org/bot$($tg_bot.tg_token)/"

    foreach ($vtg_chat_id in $tg_bot.chats_id) {
      if ($vtg_chat_id.IndexOf("_") -gt 0) {
        $tg_chat_id           = $vtg_chat_id.Substring(0, $vtg_chat_id.IndexOf("_"))
        $tg_message_thread_id = $vtg_chat_id.Substring($vtg_chat_id.IndexOf("_") + 1)
      } else {
        $tg_chat_id           = $vtg_chat_id
        $tg_message_thread_id = ""
      }

      $Response = Invoke-RestMethod -Uri "$($url_chat)sendMessage?chat_id=$($tg_chat_id)&message_thread_id=$($tg_message_thread_id)&text=$($Message)&parse_mode=html"
    }
  }

  return $Response
}

#--------------------------------------------
# ������� �������� ������� �� ��������� ��������� ����������
#--------------------------------------------
function Create-DBArchive {
  $message  = "<b>" + $srv_name + "</b>"
  $err_message = ""

  if (-not (Test-Path -Path "$tmp_backup_dir")) { 
    New-Item -Path "$tmp_backup_dir" -ItemType Directory
  }

  if ($include_db.Count -eq 0) {
    write-host "---                ������������� ��� ������ (`"������ ������`")                ---"
    foreach ($database_name in $list_db) {
      if (-not ($database_name -in $exclude_db)) { 
        $Backup_name = $database_name + '_backup_' + ($today.ToString("yyyyMMdd_HHmmss_ffffff")) + '.bak'
        try {
          Backup-SqlDatabase -ServerInstance $srv_name -Database $database_name -BackupFile $tmp_backup_dir\$Backup_name -CompressionOption on
          write-host "INFO: ������������� ���� ������ $($database_name) � ���� $($tmp_backup_dir)\$($Backup_name)"
        } catch {
          $err_message = $err_message + "`n$($PSItem.Exception.Message)"
          write-host "ERRO: ������ ������������� ���� ������ $($database_name) � ���� $($tmp_backup_dir)\$($Backup_name)"
        }
      } else {
        write-host "INFO: ������� ������������� ���� ������ $($database_name)"
      }
    }
  } else {
    write-host "---                ������������� ��� ������ (`"����� ������`")                ---"
    foreach ($database_name in $list_db) {
      if($database_name -in $include_db) { 
        $Backup_name = $database_name + '_backup_' + ($today.ToString("yyyyMMdd_HHmmss_ffffff")) + '.bak'
        try {
          Backup-SqlDatabase -ServerInstance $srv_name -Database $database_name -BackupFile $tmp_backup_dir\$Backup_name -CompressionOption on
          write-host "INFO: ������������� ���� ������ $($database_name) � ���� $($tmp_backup_dir)\$($Backup_name)"
        } catch {
          $err_message  = $err_message + "`n$($PSItem.Exception.Message)"
          write-host "ERRO: ������ ������������� ���� ������ $($database_name) � ���� $($tmp_backup_dir)\$($Backup_name)"
        }
      } else {
        write-host "INFO: ������� ������������� ���� ������ $($database_name)"
      }
    }
  }

  if ($err_message -eq "") {
    $message  = $message + "`n�������� ������� �� ��������� �������."
  } else {
    $message  = $message + "`n�������� ������� �� ��������� � ��������:"
  }

  $Response = (Send-Telegram $message $err_message)
}

#--------------------------------------------
# ������� �������� "����������" �������
#--------------------------------------------
function Delete-DBArchive-in-Dir {
  [CmdletBinding()]
  param(
    [Parameter()]
    [string] $pWork_Dir,
    [string] $pdok
  )

  $err_message = ""

  write-host "---                �������� ���������� ������ (������ $($pdok)) �� ����� $($pWork_Dir)                 ---"
  try {
    Get-ChildItem "$pWork_Dir" | where { $_.LastAccessTime -lt ((Get-Date).AddDays(-$pdok)) } | %{ 
      try {
        Remove-Item "$($pWork_Dir)\$($_)" -Force
        write-host "INFO: �������� ����� $($_)"
      } catch {
        $err_message  = "`n$($PSItem.Exception.Message)"
        write-host "ERRO: ������ �������� ����� $($_)"
      }
    }
  } catch {
    $err_message  = "`n$($PSItem.Exception.Message)"
    write-host "ERRO: ������ �������� ������ �� �������� $(pWork_Dir)"
  }

  return $err_message
}

function Delete-DBArchive-in-Dir-All {
  $message  = "<b>" + $srv_name + "</b>"
  $err_message_all = ""

  $err_message = ""
  $err_message = (Delete-DBArchive-in-Dir "$($tmp_backup_dir)" $doktc)

  if ($err_message -eq "") {
    $message = $message + "`n�������� ������ �� ����� $($tmp_backup_dir) ��������� �������."
  } else {
    $message = $message + "`n�������� ������ �� ����� $($tmp_backup_dir) ��������� � ��������:"
    $err_message_all = $err_message_all + $err_message
  }

  if ($is_save_nas) {
    foreach ($nas_server in $nas_servers) {
      $tnet_backup_dir = "Microsoft.Powershell.Core\FileSystem::$($nas_server.net_backup_dir)\$($srv_name)"
      $err_message = ""
      
      $err_message =  $err_message +  (Delete-DBArchive-in-Dir "$($tnet_backup_dir)\Daily" $nas_server.dokdc)

      # ��������� �� ������
      if ((([int] ($today).DayOfWeek) -eq 0) -and ($nas_server.dokwc -gt 0)) {
        $err_message = $err_message + (Delete-DBArchive-in-Dir "$($tnet_backup_dir)\Weekly" $nas_server.dokwc)
      }

      if ($today.Day -eq $lastDay) {
        # ��������� � ������
        $err_message = $err_message + (Delete-DBArchive-in-Dir "$($tnet_backup_dir)\Monthly" $nas_server.dokmc)
   
        if ($today.Month -eq 12) {
          # ��������� � ����
        }
      }
    }

    if ($err_message -eq "") {
      $message = $message + "`n�������� ������ c NAS $($nas_server.net_backup_dir) ��������� �������."
    } else {
      $message = $message + "`n�������� ������ c NAS $($nas_server.net_backup_dir) ��������� � ��������:"
      $err_message_all = $err_message_all + $err_message
    }
  }

  if ($is_save_yandex) {
# curl -s -H "Authorization: OAuth TOKEN" -X "DELETE" https://cloud-api.yandex.net/v1/disk/trash/resources/?path=
# Invoke-WebRequest -Uri https://cloud-api.yandex.net/v1/disk/trash/resources/?path= -Headers @{Authorization = "OAuth TOKEN"} -Method DELETE
#    if ($err_message_all -eq "") {
#      $message  = $message + "`n�������� ���������� ������ � Yandex ����� ��������� �������."
#    } else {
#      $message  = $message + "`n�������� ���������� ������ � Yandex ����� ��������� � ��������:"
#      $err_message_all = $err_message_all + $err_message
#    }
  }

  $Response = (Send-Telegram $message $err_message_all)

  return $err_message
}

#--------------------------------------------
# ������� ����������� ������� �� ������� ���������
#--------------------------------------------
function Copy-DBArchive-to-NAS {
  [CmdletBinding()]
  param(
    [Parameter()]  
    [string] $pSrc_File,
    [string] $pDst_Dir
  )

  $err_message = ""

  if (-not (Test-Path -Path "$pDst_Dir")) { 
    try {
      New-Item -Path "$pDst_Dir" -ItemType Directory
      write-host "INFO: �������� �������� $($pSrc_File)"
    } catch {
      $err_message  = "`n$($PSItem.Exception.Message)"
      write-host "ERRO: ������ �������� �������� $($pDst_Dir)"
    }
  }

  try {
    Copy-Item "$($tmp_backup_dir)\$($pSrc_File)" -Destination "$pDst_Dir" -Exclude (Get-ChildItem "$pDst_Dir") �Force
    write-host "INFO: ����������� ����� � $($pDst_Dir)\$($pSrc_File)"
  } catch {
    $err_message  = "`n$($PSItem.Exception.Message)"
    write-host "ERRO: ������ ����������� ����� � $($pDst_Dir)\$($pSrc_File)"
  }

  return $err_message
}

function Copy-DBArchive-to-NAS-All {
# $nas_server.net_backup_dir
# $nas_server.dokdc
# $nas_server.dokwc
# $nas_server.dokmc
# $nas_server.include_db_to
# $nas_server.exclude_db_to

  if ($is_save_nas) {
    $message  = "<b>" + $srv_name + "</b>"
    $err_message_all = ""

    foreach ($nas_server in $nas_servers) {
      $err_message = ""
      $dst_path = "Microsoft.Powershell.Core\FileSystem::$($nas_server.net_backup_dir)\$($srv_name)"

      if ($nas_server.include_db_to.Count -eq 0) {
        write-host "---                ����������� ������ �� NAS $($nas_server.net_backup_dir) (`"������ ������`")                ---"

        foreach ($file_name in Get-ChildItem "$tmp_backup_dir") {
          if (-not ($($file_name | %{ if ($_ -match "^(.+)_backup_") { $Matches[1]}}) -in $nas_server.exclude_db_to)) {
#            if ($file_name.LastAccessTime -ge ((Get-Date).AddDays(-$nas_server.dokdc))) {
            if ($file_name.LastAccessTime -ge ((Get-Date).AddDays(-1))) {
              $err_message = $err_message + (Copy-DBArchive-to-NAS "$file_name" "$($dst_path)\Daily")
            }

            # ��������� �� ������
            if ((([int] ($today).DayOfWeek) -eq 0) -and ($nas_server.dokwc -gt 0)){
              if ($file_name.LastAccessTime -ge ((Get-Date).AddDays(-1))) {
                $err_message = $err_message + (Copy-DBArchive-to-NAS "$file_name" "$($dst_path)\Weekly")
              }
            }

            if ($today.Day -eq $lastDay) {
              # ��������� � ������
#              if ($file_name.LastAccessTime -ge ((Get-Date).AddDays(-$nas_server.dokdc))) {
              if ($file_name.LastAccessTime -ge ((Get-Date).AddDays(-1))) {
                $err_message = $err_message + (Copy-DBArchive-to-NAS "$file_name" "$($dst_path)\Monthly")
              }
              if ($today.Month -eq 12) {
                # ��������� � ����
                if ($file_name.LastAccessTime -ge ((Get-Date).AddDays(-1))) {
                  $err_message = $err_message + (Copy-DBArchive-to-NAS "$file_name" "$($dst_path)\Yearly")
                }
              }  
            }
          }
        }
      } else {
        write-host "---                ����������� ������ �� NAS $($nas_server.net_backup_dir) (`"����� ������`")                ---"

        foreach ($file_name in Get-ChildItem "$tmp_backup_dir") {
          if ($($file_name | %{ if ($_ -match "^(.+)_backup_") { $Matches[1]}}) -in $nas_server.include_db_to) {
#            if ($file_name.LastAccessTime -ge ((Get-Date).AddDays(-$nas_server.dokdc))) {
            if ($file_name.LastAccessTime -ge ((Get-Date).AddDays(-1))) {
              $err_message = $err_message + (Copy-DBArchive-to-NAS "$file_name" "$($dst_path)\Daily")
            }

            # ��������� �� ������
            if ((([int] ($today).DayOfWeek) -eq 0) -and ($nas_server.dokwc -gt 0)){
              if ($file_name.LastAccessTime -ge ((Get-Date).AddDays(-1))) {
                $err_message = $err_message + (Copy-DBArchive-to-NAS "$file_name" "$($dst_path)\Weekly")
              }
            }

            if ($today.Day -eq $lastDay) {
              # ��������� � ������
#              if ($file_name.LastAccessTime -ge ((Get-Date).AddDays(-$nas_server.dokdc))) {
              if ($file_name.LastAccessTime -ge ((Get-Date).AddDays(-1))) {
                $err_message = $err_message + (Copy-DBArchive-to-NAS "$file_name" "$($dst_path)\Monthly")
              }
              if ($today.Month -eq 12) {
                # ��������� � ����
                $err_message = $err_message + (Copy-DBArchive-to-NAS "$file_name" "$($dst_path)\Yearly")
              }  
            }
          }
        }
      }

      if ($err_message -eq "") {
        $message = $message + "`n����������� ������ �� NAS $($nas_server.net_backup_dir) ��������� �������."
      } else {
        $message = $message + "`n����������� ������ �� NAS $($nas_server.net_backup_dir) ��������� � ��������:"
        $err_message_all = $err_message_all + $err_message
      }
    }

    $Response = (Send-Telegram $message $err_message_all)
  }
}
#--------------------------------------------
# ������� ����������� ������� �� FTP
#--------------------------------------------
function Copy-DBArchive-to-FTP {
  [CmdletBinding()]
  param(
    [Parameter()]  
    [string] $pSrc_File,
    [string] $pftp_url,
    [string] $pftp_username,
    [string] $pftp_password
  )

  $err_message = ""

  try {
    $webclient = New-Object System.Net.WebClient
    $webclient.Credentials = New-Object System.Net.NetworkCredential("$pftp_username", "$pftp_password")
    $webclient.UploadFile("$($pftp_url)/$($pSrc_File)", "$($tmp_backup_dir)\$($pSrc_File)")
    $webclient.Dispose()

    write-host "INFO: ����������� ����� $($pSrc_File)"
  } catch {
    $err_message  = $err_message + "$($PSItem.Exception.Message)`n"
    write-host "ERRO: ������ ����������� ����� $($pSrc_File)"
  }

  return $err_message
}

function Copy-DBArchive-to-FTP-All {
# $ftp_server.ftp_url
# $ftp_server.ftp_username
# $ftp_server.ftp_password
# $ftp_server.include_db_to
# $ftp_server.exclude_db_to

  if ($is_save_ftp) {
    $message  = "<b>" + $srv_name + "</b>"
    $err_message_all = ""

    foreach ($ftp_server in $ftp_servers) {
      $err_message = ""

      if ($ftp_server.include_db_to.Count -eq 0) {
        write-host "---                ����������� ������ �� FTP $($ftp_server.ftp_url) (`"������ ������`")                ---"

        foreach ($file_name in Get-ChildItem "$tmp_backup_dir") {
          if (-not ($($file_name | %{ if ($_ -match "^(.+)_backup_") { $Matches[1]}}) -in $ftp_server.exclude_db_to)) {
            $err_message = $err_message + (Copy-DBArchive-to-FTP "$file_name" "$ftp_server.ftp_url" "$ftp_server.ftp_username" "$ftp_server.ftp_password")
          }
        }
      } else {
        write-host "---                ����������� ������ �� FTP $($ftp_server.ftp_url) (`"����� ������`")                ---"

        foreach ($file_name in Get-ChildItem "$tmp_backup_dir") {
          if ($($file_name | %{ if ($_ -match "^(.+)_backup_") { $Matches[1]}}) -in $ftp_server.include_db_to) {
            $err_message = $err_message + (Copy-DBArchive-to-FTP "$file_name" "$ftp_server.ftp_url" "$ftp_server.ftp_username" "$ftp_server.ftp_password")
          }
        }
      }

      if ($err_message -eq "") {
        $message = $message + "`n����������� ������ �� FTP $($ftp_server.ftp_url) ��������� �������."
      } else {
        $message = $message + "`n����������� ������ �� FTP $($ftp_server.ftp_url) ��������� � ��������:"
        $err_message_all = $err_message_all + $err_message
      }
    }

    $Response = (Send-Telegram $message $err_message_all)
  }
}

#--------------------------------------------
# ������� ����������� ������� �� Yandex
#--------------------------------------------
function Copy-DBArchive-to-Yandex {
  [CmdletBinding()]
  param(
    [Parameter()]  
    [string] $pYandex_token,
    [string] $pSrc_File,
    [string] $pUpload_Url
  )
  
  $err_message = ""

  try { 
    # ������ ��������� ������� �������� 
    $pinfo = New-Object System.Diagnostics.ProcessStartInfo 
    $pinfo.FileName = "curl" 
    $pinfo.Arguments = "-s", "-T `"$($tmp_backup_dir)\$($pSrc_File)`"", "-H `"Authorization: OAuth $pYandex_token`"", "$pUpload_Url" 
    $pinfo.UseShellExecute = $false 
    $pinfo.CreateNoWindow = $true 
    $pinfo.RedirectStandardOutput = $true 
    $pinfo.RedirectStandardError = $true

    # ������� ������ ��������, ��������� �������� ���������
    $process = New-Object System.Diagnostics.Process 
    $process.StartInfo = $pinfo
 
    # ��������� ������� � ���� ��� ����������
    $process.Start() | Out-Null
    $process.WaitForExit()

    # �������� � ��������� ���������� ����������� ����� � ������
    $exitCode = $process.ExitCode
    $stderr = $process.StandardError.ReadToEnd()
    $stdout = $process.StandardOutput.ReadToEnd() 
    
    if ($exitCode -ne 0) {
      throw "$($stderr.Trim())"
    }
    write-host "INFO: ����������� ����� $($pSrc_File)"
  } catch {
    $err_message = "`n$($PSItem.Exception.Message)"
    write-host "ERRO: ������ ����������� ����� $($pSrc_File)"
  }

  return $err_message
}

function Copy-DBArchive-to-Yandex-All {
# $yandex_disk.yandex_token
# $yandex_disk.path
# $yandex_disk.include_db_to
# $yandex_disk.exclude_db_to

  if ($is_save_yandex) {
    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $headers.Add("Authorization" ,"OAuth $($yandex_disks.yandex_token)")
    $headers.Add("UserAgent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64)")
    $headers.Add("Accept-Encoding", "gzip,deflate,sdch")
    $headers.Add("Content-Type","application/json")

    $message  = "<b>" + $srv_name + "</b>"
    $err_message_all = ""

    foreach ($yandex_disk in $yandex_disks) {
      try {
        $err = (Invoke-RestMethod -Headers $headers -method put -URI "https://cloud-api.yandex.net/v1/disk/resources?path=$($yandex_disk.path)")
      } catch {
#        $err_message  = "`n$($PSItem.Exception.Message)"
        write-host "ERRO: ������ �������� �������� $($yandex_backup_path)"
      }

      $err_message = ""

      if ($yandex_disk.include_db_to.Count -eq 0) {
        write-host "---                ����������� ������ �� Yandex (`"������ ������`")                ---"

        foreach ($file_name in Get-ChildItem "$tmp_backup_dir") {
          if (-not ($($file_name | %{ if ($_ -match "^(.+)_backup_") { $Matches[1]}}) -in $yandex_disk.exclude_db_to)) {
            try {
              #�������� �� ������� URL ��� �������� �����
              $UploadUrl= (Invoke-RestMethod -method GET -URI ("https://cloud-api.yandex.net:443/v1/disk/resources/upload?path=$($yandex_disk.path)%2F$($file_name)&overwrite=true") -Headers $headers).href
              $err_message  = $err_message + (Copy-DBArchive-to-Yandex "$($yandex_disk.yandex_token)" "$file_name" "$UploadUrl")
            } catch {
              $err_message  = $err_message + "`n$($PSItem.Exception.Message)"
            }
          }
        }
      } else {
        write-host "---                ����������� ������ �� Yandex (`"����� ������`")                ---"

        foreach ($file_name in Get-ChildItem "$tmp_backup_dir") {
          if ($($file_name | %{ if ($_ -match "^(.+)_backup_") { $Matches[1]}}) -in $yandex_disk.include_db_to) {
            try {
              #�������� �� ������� URL ��� �������� �����
              $UploadUrl= (Invoke-RestMethod -method GET -URI ("https://cloud-api.yandex.net:443/v1/disk/resources/upload?path=$($yandex_backup_path)%2F$($_)&overwrite=true") -Headers $headers).href
              $err_message  = $err_message + (Copy-DBArchive-to-Yandex "$($yandex_disk.yandex_token)" "$file_name" "$UploadUrl")
            } catch {
              $err_message  = $err_message + "`n$($PSItem.Exception.Message)"
            }
          }
        }
      }

      if ($err_message -eq "") {
        $message = $message + "`n����������� ������ �� Yandex ���� ��������� �������."
      } else {
        $message = $message + "`n����������� ������ �� Yandex ���� ��������� � ��������:"
        $err_message_all = $err_message_all + $err_message
      }
    }

    $Response = (Send-Telegram $message $err_message_all)
  }
}

#============================================
# �������� ���� �������
#============================================
# �������� ������� �� ��������� ��������� ����������
$err_message = (Create-DBArchive)

# �������� "����������" �������
$err_message = (Delete-DBArchive-in-Dir-All)

# ����������� ������� �� ������� ���������
$err_message = (Copy-DBArchive-to-NAS-All)

# ����������� ������� �� FTP
$err_message = (Copy-DBArchive-to-FTP-All)

# ����������� ������� �� Yandex
$err_message = (Copy-DBArchive-to-Yandex-All)
#============================================
# ���������� ������
#============================================

Stop-Transcript
Pop-Location
#Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Force
exit