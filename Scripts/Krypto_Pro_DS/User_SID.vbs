'включаем обработку ошибок
On Error Resume Next

' Директория для файлов с SID-ами, относительно текущей
DataSubDir    = "UserSID"
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
  Set vScriptFullName = objFSO.GetFile(Wscript.ScriptFullName)

  if not objFSO.FolderExists(strDataDir) then
    ind_razd = InStrRev(strDataDir, "\", len(strDataDir), vbTextCompare)
    if not ind_razd = 0 then
      call Create_Dir(Left(strDataDir, ind_razd - 1))
    end if
    objFSO.CreateFolder(strDataDir)
  end if
end Sub
'====================================================================
Sub Save_SID(getSID, strUsername, strDataDir)
  Set objFSO          = CreateObject("Scripting.FileSystemObject")
  Set vScriptFullName = objFSO.GetFile(Wscript.ScriptFullName)

  call Create_Dir(strDataDir)

  if IsInteractive = "true" then
    MsgBox("SID пользователя "  + strUsername + " сохранен в файл:" + vbCrLf + strDataDir + "\" + strUsername + "_SID.txt")
  end if

  Set objFile = objFSO.OpenTextFile(strDataDir + "\" + strUsername + "_SID.txt", 2, true, -1)
  objFile.WriteLine(getSID)
  objFile.Close
End Sub
'====================================================================

Set objNetwork = CreateObject("Wscript.Network")

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
  strInFullUserName   = InputBox("Введите имя пользователя, чей SID пытаемся определить", "Ввод имени пользователя", strInFullUserName)
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


getSID = get_SID(strUsername, strInUserDomain)
if IsInteractive = "true" then
  MsgBox(getSID)
end if
call Save_SID(getSID, strUsername, DataSubDir + "\" + strInUserDomain)

WScript.Quit 0