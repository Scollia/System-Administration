'включаем обработку ошибок
On Error Resume Next

' Директория для файлов с контейнерами и сертификатами, относительно текущей
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
  Set objFSO = CreateObject("Scripting.FileSystemObject")

  if not objFSO.FolderExists(strDataDir) then
    ind_razd = InStrRev(strDataDir, "\", len(strDataDir), vbTextCompare)
    if not ind_razd = 0 then
      call Create_Dir(Left(strDataDir, ind_razd - 1))
    end if
    objFSO.CreateFolder(strDataDir)
  end if
end Sub
'====================================================================
Sub Export_DS(strUsrSID, strDataDir)
  On Error Resume Next

  ' Задаем  константы
  'const HKEY_CURRENT_USER  = &H80000001
  const HKEY_LOCAL_MACHINE = &H80000002

  Set WshShell   = CreateObject("WScript.Shell")
  Set objFSO     = CreateObject("Scripting.FileSystemObject")
  Set objNetwork = CreateObject("Wscript.Network")
  Set objReg     = GetObject("winmgmts:{impersonationLevel=impersonate}!\\" & objNetwork.ComputerName & "\root\default:StdRegProv")

  ' Ключ реестра из которого импортировать контейнеры электронных подписей
  strRegKeyDS    = "SOFTWARE\Wow6432Node\Crypto Pro\Settings\Users\" + strUsrSID + "\Keys"

  intRes = objReg.EnumKey(HKEY_LOCAL_MACHINE, strRegKeyDS, sNames)
  If intRes <> 0 Then
    if IsInteractive = "true" then
      MsgBox("Контейнеров в реестре с электронными подписями у пользователя не найдено")
    end if
    WScript.Quit 3
  end If
    
  If IsArray(sNames) Then
    DSCount = 0
    DSList  = ""
    ' Для каждого контейнера сохраняем ключ реестра 
    For Each strDSName In sNames
      DSCount = DSCount + 1
      DSList  = DSList & vbCrLf & strDSName
      call Create_Dir(strDataDir + "\" + strDSName)

      WshShell.Run "reg.exe export ""HKLM\" + strRegKeyDS + "\" + strDSName + """ """ + strDataDir + "\" + strDSName + "\DS.orig"" /y", 0, true

      Set objFile = objFSO.OpenTextFile(strDataDir + "\" + strDSName + "\DS.orig", 1, false , -1)
      strText = objFile.ReadAll
      objFile.Close
     
      strNewText = Replace(strText, strUsrSID, "__SID_HERE__")

      Set objFile = objFSO.OpenTextFile(strDataDir + "\" + strDSName + "\DS.orig", 2, true, -1)
      objFile.WriteLine(strNewText)
      objFile.Close
    next
    if IsInteractive = "true" then
      MsgBox("Экспортировано " & DSCount & " контейнер(а/ов):" & DSList)
    end if
  end if
end Sub
'====================================================================
Sub Export_WinCertKey(strAppData, strDataDir)
  Set WshShell = CreateObject("WScript.Shell")
  Set objFSO   = CreateObject("Scripting.FileSystemObject")

  if objFSO.FolderExists(strAppData & "\Microsoft\SystemCertificates\My\Certificates") then
   WshShell.Run "xcopy.exe """ + strAppData + "\Microsoft\SystemCertificates\My\Certificates\*.*" + """ """ +  strDataDir + "\Certificates\"" /E /C /I /H /R /Y /Z"
  end if

  if objFSO.FolderExists(strAppData + "\Microsoft\SystemCertificates\My\Keys") then
    WshShell.Run "xcopy.exe """ + strAppData + "\Microsoft\SystemCertificates\My\Keys\*.*" + """ """ +  strDataDir + "\Keys\"" /E /C /I /H /R /Y /Z"
  end if

  if IsInteractive = "true" then
    MsgBox("Экспорт сертификатов и ключей завершен")
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
  strInFullUserName = InputBox("Введите имя пользователя, у кого экспортируем ЭЦП", "Ввод имени пользователя", strInFullUserName)
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

call Export_DS(strUsrSID, DataSubDir + "\" + strUsername + "\Container")
call Export_WinCertKey(strAppData, DataSubDir + "\" + strUsername + "\SystemCertificates")

WScript.Quit 0