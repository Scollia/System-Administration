on error resume next

Set obj_fs = CreateObject("Scripting.FileSystemObject")
Set obj_app = CreateObject("Shell.Application")
'Set obj_shell = CreateObject("WScript.Shell")

'-----------------------------------------------------------------
' Установка констант среды
'-----------------------------------------------------------------
' Удаление исходных файлов - src_delete=true/false
Const src_delete   = true
' Типы резервных копий, кототые будет делать скрипт
' ежедневная
Const arch_daily   = true
' еженедельная
Const arch_weekly  = false
' ежемесячная
Const arch_monthly = true
' ежегодная
Const arch_yearly  = true
' Временная директория (локальная) в которую помещать исходные файлы
Const temp_folder  = "d:\temp\Backup\tsrc"
' Временная директория (локальная) в которую помещать создаваемые архивы
Const arch_folder  = "d:\temp\Backup\arch"
' Временная директория (локальная) в которую помещать файлы журналов
'Const log_folder   = "d:\temp\Backup\log"
Const log_folder   = "d:\temp\Backup\log"
' Базовая директория (на сервере) для хранения резервных копий
Const bkp_folder   = "\\10.0.0.1\Backup"
' Базовая директория (на сервере) для хранения резервных копий
Const srv_username = "user"
' Базовая директория (на сервере) для хранения резервных копий
Const srv_passwd   = "passwd"
' Директория-идентификатор (обычно IP-адрес компьютера, на котором происходит архивация)
Const bkp_postfix  = "prefix"

' Список источников для копирования с параметрами
'   Const src_delete=false
' Список источников и правил для копирования данных
'   Array ( _
'     Директория источник,_
'     Просматривать директории рекурсивно true/false,_
'     Маски файлов для отбора через " ",_
'     "Возраст" файлов в днях,_
'     Перенос вместо копирования true/false,_
'     Идентификатор (префикс)_
'     Архивировать или нет true/false _
'   ), _
src_data = Array ( _
    Array ( _
     "E:\BACKUP", _
     true, _
     "*.DT", _
     7, _
     true, _
     "dt", _
     false _
    ), _
    Array ( _
     "D:\temp\Backup\SQL", _
     true, _
     "*.bckup", _
     7, _
     true, _
     "SQL", _
     false _
    ) _
  )

'-----------------------------------------------------------------
'Установка переменных среды
'-----------------------------------------------------------------
' Таймкод создаваемых журналов
' Имя файла логов
'arch_timecode = DateAdd("d", -1 , date())
arch_timecode = Year(DateAdd("d", -1 , date())) & right("0" & FormatNumber(Month(DateAdd("d", -1 , date())),0), 2) & right("0" & FormatNumber(Day(DateAdd("d", -1 , date())),0), 2)
'log_file = log_folder & "\" & Left(WScript.ScriptName, InStrRev(WScript.ScriptName, ".") - 1) & "_" & Replace(CStr(arch_timecode), ".", "-") & ".log"
log_file = log_folder & "\" & Left(WScript.ScriptName, InStrRev(WScript.ScriptName, ".") - 1) & "_" & arch_timecode & ".log"


'-----------------------------------------------------------------
' Основное тело
'-----------------------------------------------------------------
For Each src_dat In src_data
  SrcFolder   = src_dat(0)
  IsRecursive = src_dat(1)
  SrcFilter   = Split(LCase(src_dat(2)), " ")
  DiffDate    = src_dat(3)
  IsMove      = src_dat(4)
  TmpFolder   = temp_folder & "\" & src_dat(5)
  ArchFolder  = arch_folder & "\" & src_dat(5)
  BkpPostfix  = bkp_postfix & "\" & src_dat(5)
  IsArchive   = src_dat(6)

' Подключаемсся к серверному ресурсу директории-источника
'  if left(SrcFolder, 2)="\\" then
'    call ToLogFile(log_file, "Подключаемсся к серверному ресурсу " & SrcFolder, 0)
'    call ConnectToServer(SrcFolder, srv_username, srv_passwd)
'  end if

  If obj_fs.FolderExists(SrcFolder) Then
    if not obj_fs.FolderExists(TmpFolder) then
      call ToLogFile(log_file, "Создаем директорию: " & TmpFolder, 1)
      call CreateFolder(TmpFolder)
    else
      call ToLogFile(log_file, "Запущено удаление старых (" & cstr(CDate(date())) & " д.) файлов в директории " & TmpFolder, 0)
      call ClearFolder(TmpFolder, 0, SrcFilter)
      call ToLogFile(log_file, "Завершено удаление старых файлов", 0)
    end if

    call ToLogFile(log_file, "Запущено копирование/перенос файлов из " & SrcFolder & "\ во временную папку " & TmpFolder, 0)
    call CopyFile(SrcFolder, IsRecursive, SrcFilter, DiffDate, IsMove, TmpFolder)
    call ToLogFile(log_file, "Завершено копирование/перенос файлов", 0)

    if IsArchive then
      if not obj_fs.FolderExists(ArchFolder) then
        call ToLogFile(log_file, "Создаем директорию: " & ArchFolder, 1)
        call CreateFolder(ArchFolder)
      else
        call ToLogFile(log_file, "Запущено удаление старых (" & cstr(CDate(date())) & " д.) файлов в директории " & ArchFolder, 0)
        call ClearFolder(ArchFolder, 0, Split(LCase("*.rar"), " "))
        call ToLogFile(log_file, "Завершено удаление старых файлов", 0)
      end if

      call ToLogFile(log_file, "Запущено архивирование директории " & TmpFolder, 0)
      call DoArch(TmpFolder, ArchFolder, src_dat(5))
      call ToLogFile(log_file, "Завершено архивирование директории " & TmpFolder, 0)

      call ToLogFile(log_file, "Запущено перенос файлов из " & ArchFolder & "\ в хранилище " & bkp_folder, 0)
      call CopyToStorage(ArchFolder, Split(LCase("*.rar"), " "))
      call ToLogFile(log_file, "Завершено перенос файлов", 0)

      call ToLogFile(log_file, "Запущено удаление старых (" & cstr(CDate(date())) & " д.) файлов в директории " & TmpFolder, 0)
      call ClearFolder(TmpFolder, 0, SrcFilter)
      call ToLogFile(log_file, "Завершено удаление старых файлов", 0)
    else
      call ToLogFile(log_file, "Запущено перенос файлов из " & TmpFolder & "\ в хранилище " & bkp_folder, 0)
      call CopyToStorage(TmpFolder, SrcFilter)
      call ToLogFile(log_file, "Завершено перенос файлов", 0)
    end if
  else
    call ToLogFile(log_file, "Не существует директория-источник: " & SrcFolder, 0)
  end if
next

'obj_shell = nothing
'obj_app   = nothing
'obj_fs    = nothing

WScript.Quit
'-----------------------------------------------------------------
' Дополнительные процедуры и функции
'-----------------------------------------------------------------
' Процедура записи в файл журнала
Sub ToLogFile(ByVal str_logfile, ByVal str_Text, ByVal LogLevel)
  str_LogLevel = ""
  for i=1 to LogLevel * 2
    str_LogLevel = str_LogLevel & " "
  next
  str_LogFolder = Left(str_logfile, InStrRev(str_logfile, "\"))

'   Проверяем существование директории
  If not obj_fs.FolderExists(log_folder) Then
    obj_app.NameSpace(Left(str_Folder, InStr(str_Folder, ":"))).NewFolder(str_NewFolder)
  End If

  If obj_fs.FolderExists(str_LogFolder) Then
    Set obj_mlf = obj_fs.OpenTextFile(str_logfile, 8, True)
    obj_mlf.WriteLine(Cstr(date) & " " & CStr(time()) & " " & str_LogLevel & str_Text)
    obj_mlf.Close
  end if
End Sub

'-----------------------------------------------------------------
' Процедура подключения сетевого диска
Sub ConnectToServer(ByVal str_Folder, ByVal str_username, ByVal str_passwd)
  if left(str_Folder, 2)="\\" then
    Set NetworkObject = CreateObject("WScript.Network")

    if InStr(InStr(3, bkp_folder, "\") + 1, bkp_folder, "\") = 0 then
      str_ServerRecerch = str_Folder
    else
      str_ServerRecerch = Left(str_Folder, InStr(InStr(3, str_Folder, "\") + 1, str_Folder, "\") - 1)
    end if

    Set oDrives = NetworkObject.EnumNetworkDrives
    For i = 0 to oDrives.Count - 1 Step 2
       if Left(str_ServerRecerch, InStr(3, str_ServerRecerch, "\") - 1) = Left(oDrives.Item(i+1), InStr(3, oDrives.Item(i+1), "\") - 1) then
         call ToLogFile(log_file, "Отключаем серверный ресурсу " & oDrives.Item(i+1), 1)
         NetworkObject.RemoveNetworkDrive oDrives.Item(i+1)
       end if
    Next

    call ToLogFile(log_file, "Подключаемся к серверному ресурсу " & str_ServerRecerch, 1)
    NetworkObject.MapNetworkDrive "", str_ServerRecerch, False, str_username, str_passwd

    set NetworkObject = nothing
  End If
End Sub

'-----------------------------------------------------------------
' Процедура очистки директории от старых файлов
' DeathLine - максимальный "возраст" файлов которые оставлять в днях. 0 - удалять все
Sub ClearFolder(ByVal pSrcFolder, ByVal pDiffDate, ByVal pSrcFilter)
  Set obj_ShlApp = CreateObject("Shell.Application")

  if pDiffDate <= 0 then
    DeathLine = now
  else
    DeathLine = DateAdd("d", -pDiffDate, now)
  end if

  If obj_fs.FolderExists(pSrcFolder) Then
    Set obj_FolderItems = obj_ShlApp.NameSpace(pSrcFolder).Items

    obj_FolderItems.Filter 32 + 128, "*"
    If obj_FolderItems.Count<>0 then
      For Each obj_FolderItem In obj_FolderItems
        call ClearFolder(obj_FolderItem.Path, pDiffDate, pSrcFilter)
        if obj_ShlApp.NameSpace(obj_FolderItem.Path).Items().Count = 0 then
          call ToLogFile(log_file, "Удаляем папку: " & obj_FolderItem.Path, 1)
          obj_fs.DeleteFolder(obj_FolderItem.Path)
        end if
      next
    end if

    For i = LBound(pSrcFilter) To UBound(pSrcFilter)
      obj_FolderItems.Filter 64 + 128, pSrcFilter(i)
      If obj_FolderItems.Count<>0 then
        For Each obj_FolderItem In obj_FolderItems
          If obj_FolderItem.ModifyDate < DeathLine Then
            call ToLogFile(log_file, "Удаляем файл: " & obj_FolderItem.Path, 1)
            obj_fs.GetFile(obj_FolderItem.Path).Delete True
          End If
        next
      end if
    Next

    Set obj_FolderItems = Nothing
  end if

  Set obj_ShlApp = Nothing
end Sub

'-----------------------------------------------------------------
' Процедура копирования архивов в место хранения
'   pSrcFolder   - Директория источник
'   SrcFilter    - Просматривать директории рекурсивно true/false
'   pSrcFilter   - Маски файлов для отбора (массив)
'   pControlDate - Минимальная дата модификации файлов
'   pIsMove      - Перенос вместо копирования true/false
'   pDstFolder   - Директория приемник
Sub CopyFile (ByVal pSrcFolder, ByVal pIsRecursive, ByVal pSrcFilter, ByVal pDiffDate, ByVal pIsMove, ByVal pDstFolder)
  If obj_fs.FolderExists(pSrcFolder) Then
    if pDiffDate <= 0 then
      pControlDate = cdate(dateserial(0,0,0) + TimeSerial(0,0,0))
    else
      pControlDate = DateAdd("d", -pDiffDate, now)
    end if

    Set obj_FolderItems = CreateObject("Shell.Application").NameSpace(pSrcFolder).Items
    For i = LBound(pSrcFilter) To UBound(pSrcFilter)
      obj_FolderItems.Filter 64 + 128, pSrcFilter(i)
      If obj_FolderItems.Count<>0 then
        For Each obj_FolderItem In obj_FolderItems
          If obj_FolderItem.ModifyDate > pControlDate Then
            If not obj_fs.FolderExists(pDstFolder) Then
              call ToLogFile(log_file, "Создаем директорию: " & pDstFolder, 1)
              call CreateFolder(pDstFolder)
            end if

            if pIsMove then
              call ToLogFile(log_file, "Переносим файл: " & obj_FolderItem.Path, 1)
              obj_fs.CopyFile obj_FolderItem.Path, pDstFolder & "\", true
              obj_fs.DeleteFile obj_FolderItem.Path, true
              call ToLogFile(log_file, "Готово", 2)
            else
              call ToLogFile(log_file, "Копируем файл: " & obj_FolderItem.Path, 1)
              obj_fs.CopyFile obj_FolderItem.Path, pDstFolder & "\", true
              call ToLogFile(log_file, "Готово", 2)
            end if
          End If
        next
      end if
    Next

    if pIsRecursive then
      obj_FolderItems.Filter 32 + 128, "*"

      If obj_FolderItems.Count<>0 then
        For Each obj_FolderItem In obj_FolderItems
          call CopyFile(obj_FolderItem.Path, pIsRecursive, pSrcFilter, pDiffDate, pIsMove, pDstFolder & "\" & obj_FolderItem.name)
        next
      end if
    end if

    Set obj_FolderItems = Nothing
  end if
End Sub

'-----------------------------------------------------------------
' Процедура создания директории (дерева директорий)
Sub CreateFolder(ByVal str_Folder)
  Set obj_app = CreateObject("Shell.Application")
  ' Проверяем существование директории
  If not obj_fs.FolderExists(str_Folder) Then
    ' Проверяем где создается новая директория (в сети илина локальном компьютере)
    if left(str_Folder, 2)="\\" then
      str_NameSpace = Left(str_Folder, InStr(InStr(3, str_Folder, "\") + 1, str_Folder, "\") - 1)
      str_NewFolder = Right(str_Folder, len(str_Folder) - InStr(InStr(3, str_Folder, "\") + 1, str_Folder, "\"))
    else
      str_NameSpace = Left(str_Folder, InStr(str_Folder, ":"))
      str_NewFolder = Right(str_Folder, len(str_Folder) - 1 - InStr(str_Folder, ":"))
    end if
    obj_app.NameSpace(str_NameSpace).NewFolder(str_NewFolder)
  End If
'  obj_app = nothing
End Sub

'-----------------------------------------------------------------
' Процедура архивирования
Sub DoArch (ByVal src_folder, ByVal dst_folder, ByVal arch_prefix)
  Set obj_app = CreateObject("Shell.Application")
  Set obj_shell = CreateObject("WScript.Shell")
  ' Проверяем существование директории источника
  If not obj_fs.FolderExists(src_folder) then
    call ToLogFile(log_file, "Неверно указана директория-источник " & src_folder, 1)
  else
    if not obj_fs.FolderExists(dst_folder) then
      call ToLogFile(log_file, "Неверно указана директория-приемник " & ArchFolder, 1)
    else
      arch_name = arch_prefix + "_" + Replace(CStr(arch_timecode), ".", "-") + ".rar"
      call ToLogFile(log_file, "Создается архив: " & ArchFolder & "\" & arch_name, 1)
      obj_shell.run obj_shell.CurrentDirectory & "\arch_dir.cmd """ + ArchFolder + "\" + arch_name + """ """ + src_folder + """ """ + log_folder + "\" + arch_name + ".log""", 0, true
      If obj_fs.FileExists(ArchFolder + "\" + arch_name) then
        call ToLogFile(log_file, "Успешно создан архив", 1)
      else
        call ToLogFile(log_file, "Ошибка создания архива", 1)
      end if
    end if
  end if
End Sub

'-----------------------------------------------------------------
' Процедура Копирования в хранилище
Sub CopyToStorage (ByVal pSrcFolder, ByVal pSrcFilter)
  If not obj_fs.FolderExists(pSrcFolder) Then
    call ToLogFile(log_file, "Не существует директория-источник " & pSrcFolder, 0)
  Else

    if left(bkp_folder, 2)="\\" then
      if InStr(InStr(3, bkp_folder, "\") + 1, bkp_folder, "\") = 0 then
        str_NameSpace =bkp_folder
      else
        str_NameSpace = Left(bkp_folder, InStr(InStr(3, bkp_folder, "\") + 1, bkp_folder, "\") - 1)
      end if
      call ConnectToServer(str_NameSpace, srv_username, srv_passwd)
    end if


    if arch_daily then
      call ToLogFile(log_file, "Создание ежедневной копии", 0)
      If not obj_fs.FolderExists(bkp_folder + "\daily\" + BkpPostfix) Then
        call CreateFolder(bkp_folder + "\daily\" + BkpPostfix)
      else
        call ClearFolder(bkp_folder + "\daily\" + BkpPostfix, 30, pSrcFilter)
      end if
      call CopyFile(pSrcFolder, true, pSrcFilter, 0, false, bkp_folder + "\daily\" + BkpPostfix)
    end if

    if arch_weekly and Weekday(arch_timecode, vbMonday) = 7 then
      call ToLogFile(log_file, "Создание еженедельной копии", 0)
      If not obj_fs.FolderExists(bkp_folder + "\weekly\" + BkpPostfix) Then
        call CreateFolder((bkp_folder + "\weekly\" + BkpPostfix))
      else
        call ClearFolder(bkp_folder + "\weekly\" + BkpPostfix, 181, pSrcFilter)
      end if
      call CopyFile(pSrcFolder, true, pSrcFilter, 0, false, bkp_folder + "\weekly\" + BkpPostfix)
    end if

    if arch_monthly and Weekday(arch_timecode, vbMonday) = 7 and Day(DateSerial(Year(arch_timecode),Month(arch_timecode)+1,0)) - Day(arch_timecode) < 7 then
      call ToLogFile(log_file, "Создание ежемесячной копии", 0)
      If not obj_fs.FolderExists(bkp_folder + "\monthly\" + BkpPostfix) Then
        call CreateFolder(bkp_folder + "\monthly\" + BkpPostfix)
      else
        call ClearFolder(bkp_folder + "\monthly\" + BkpPostfix, 366, pSrcFilter)
      end if
      call CopyFile(pSrcFolder, true, pSrcFilter, 0, false, bkp_folder + "\monthly\" + BkpPostfix)
    end if

    if arch_monthly and Weekday(arch_timecode, vbMonday) = 7 and Day(DateSerial(Year(arch_timecode),Month(arch_timecode)+1,0)) - Day(arch_timecode) < 7 and Month(arch_timecode) = 12 then
      call ToLogFile(log_file, "Создание ежегодной копии", 0)
      If not obj_fs.FolderExists(bkp_folder + "\yearly\" + BkpPostfix) Then
        call CreateFolder(bkp_folder + "\yearly\" + BkpPostfix)
      end if
      call CopyFile(pSrcFolder, true, pSrcFilter, 0, false, bkp_folder + "\yearly\" + BkpPostfix)
    end if
  End If
end sub