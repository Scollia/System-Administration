'включаем обработку ошибок
On Error Resume Next

' Директория файлов с контейнерами и сертификатами, относительно текущей
DataSubDir    = "UserDS"
' Интерактивный ввод/вывод
IsInteractive = "true"

'====================================================================
Function get_SID(strUsername, strInUserDomain)
  On Error Resume Next
  ' Считываем данные аккаунта рабочего пользователя
  Set objWMIService = GetObject("winmgmts:\\.\root\cimv2")

  Err.Clear
  Set objAccount = objWMIService.Get("Win32_UserAccount.Name='" & strUsername & "',Domain='" & strInUserDomain & "'")

  If Err.Number <> 0 Then
    if IsInteractive = "true" then
      MsgBox("Пользователь не найден")
    end if
    WScript.Quit 2
  end if

  ' Возвращаем SID рабочего пользователя
  get_SID = objAccount.SID
End Function
'====================================================================
Sub Create_Dir(strDataDir)
  Set objFSO          = CreateObject("Scripting.FileSystemObject")

  if not objFSO.FolderExists(strDataDir) then
    ind_razd = InStrRev(strDataDir, "\", len(strDataDir), vbTextCompare)
    if not ind_razd = len(strDataDir) then
      if not ind_razd = 0 then
        call Create_Dir(Left(strDataDir, ind_razd - 1))
      end if
    end if
    objFSO.CreateFolder(strDataDir)
  end if
end Sub

'====================================================================

Sub Import_DS(strUsrSID, strUsername, strDataDir)
  Set WshShell = CreateObject("WScript.Shell")
  Set objFSO   = CreateObject("Scripting.FileSystemObject")

  DSCount = 0
  DSList  = ""

  For Each objFolder_DS In objFSO.GetFolder(strDataDir).SubFolders
    if objFSO.FileExists(objFolder_DS.Path + "\DS.orig") then
      call Create_Dir(objFolder_DS.Path + "\_installed_\")
      if not objFSO.FileExists(objFolder_DS.Path + "\_installed_\" + strUsername + ".reg") then
        Set objFile = objFSO.OpenTextFile(objFolder_DS.Path + "\DS.orig", 1, false , -1)

        strText = objFile.ReadAll
        objFile.Close
        strNewText = Replace(strText, "__SID_HERE__", strUsrSID)

        Set objFile = objFSO.OpenTextFile(objFolder_DS.Path + "\_installed_\" + strUsername + ".reg", 2, true, -1)
        objFile.WriteLine(strNewText)
        objFile.Close
      end if
      DSCount = DSCount + 1
      DSList  = DSList & vbCrLf & objFolder_DS.Name

      WshShell.Run "reg.exe import """ + objFolder_DS.Path + "\_installed_\" + strUsername + ".reg"""
    end if
  next

  if IsInteractive = "true" then
    if not DSCount = 0 then
      MsgBox("Экспортировано " & DSCount & " контейнер(а/ов):" & DSList)
    end if
  end if
end Sub
'====================================================================

Sub Import_WinCertKey(strAppData, strDataDir)
  Set WshShell = CreateObject("WScript.Shell")
  Set objFSO   = CreateObject("Scripting.FileSystemObject")

  if objFSO.FolderExists(strDataDir + "\Certificates") then
    WshShell.Run "xcopy.exe """ + strDataDir + "\Certificates\*.*" + """ """ + strAppData + "\Microsoft\SystemCertificates\My\Certificates\"" /E /C /I /H /R /Y /Z"
  end if

  if objFSO.FolderExists(strDataDir + "\Keys") then
    WshShell.Run "xcopy.exe """ + strDataDir + "\Keys\*.*" + """ """ + strAppData + "\Microsoft\SystemCertificates\My\Keys\"" /E /C /I /H /R /Y /Z"
  end if

  if IsInteractive = "true" then
    MsgBox("Импорт сертификатов и ключей завершен")
  end if
end Sub
'====================================================================

Set WshShell    = CreateObject("WScript.Shell")
Set WshEnvirVol = WshShell.Environment("VOLATILE")
Set objNetwork  = CreateObject("Wscript.Network")

' Имя пользователя у которого экспортируем ЭЦП
' Устанавливаем в имя текущего пользователя
strInUsername   = objNetwork.UserName
' Имя домена пользователя
' Устанавлиаем в имя домена текущего пользователя
strInUserDomain = objNetwork.UserDomain


' Составляем полное имя пользователя, включая домен, если компьютер в домене
if strInUserDomain = "" then
  strInFullUserName = strInUsername
else
  strInFullUserName = strInUserDomain + "\" + strInUsername
end if

' Выводим запрос на ввод имени пользователя
if IsInteractive = "true" then
  strInFullUserName = InputBox("Введите имя пользователя, кому импортируем ЭЦП", "Ввод имени пользователя", strInFullUserName)
end if

' Проверяем присудствует в имени пользователя имя домена
ind_razd = InStr(1, strInFullUserName, "\", vbTextCompare)
' В зависимости от результата устанавливаем рабочие имя пользователя и домен
if not ind_razd = 0 then
  strUsername     = Right(strInFullUserName, len(strInFullUserName) - ind_razd)
  strInUserDomain = Left(strInFullUserName, ind_razd - 1)
else
  strUsername     = strInFullUserName
  strInUserDomain = objNetwork.ComputerName
end if

if strUsername = "" then
  if IsInteractive = "true" then
    MsgBox("Отсутствует имя пользователя")
  end if
  WScript.Quit 1
end if

' Путь к профилю пользователя у которого экспортируем ЭЦП
if strUsername = strInUsername then
  strAppData = WshEnvirVol("AppData")
else
  strAppData = WshEnvirVol("HOMEDRIVE") + "\Users\" + strUsername + "\AppData\Roaming\"
end if

strUsrSID = get_SID(strUsername, strInUserDomain)
if IsInteractive = "true" then
  MsgBox(strUsrSID)
end if

Set objFSO   = CreateObject("Scripting.FileSystemObject")
For Each objFolder In objFSO.GetFolder(DataSubDir).SubFolders
  isImportiny = MsgBox("Импортировать данные пользователя:" & vbCrLf & objFolder.Name, vbYesNo, "Подтвердить импортирование")
  if isImportiny = vbYes then
    call Import_DS(strUsrSID, strUsername, DataSubDir + "\" + objFolder.Name + "\Container")
    call Import_WinCertKey(strAppData, DataSubDir + "\" + objFolder.Name + "\SystemCertificates")
  end if
next

WScript.Quit 0