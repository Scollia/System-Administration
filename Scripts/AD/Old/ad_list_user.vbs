' Скрипт опрашивает компьютеры домена на предмет того, какой пользователь
' залогинен в данный момент на каждом компьютере
On Error Resume Next
Const ADS_SCOPE_SUBTREE = 2
Set objRoot = GetObject("LDAP://RootDSE")
strDomainName = objRoot.Get("DefaultNamingContext")
Set objRoot = Nothing
strComputer = ""
Dim fso
Dim file
Set fso = CreateObject("Scripting.FileSystemObject")
Set file = fso.OpenTextFile ("logged_user_list.txt", 2, True)
Set objShell = CreateObject("WScript.Shell")
Set objConnection = CreateObject("ADODB.Connection")
Set objCommand = CreateObject("ADODB.Command")
objConnection.Provider = "ADsDSOObject"
objConnection.Open "Active Directory Provider"
Set objCommand.ActiveConnection = objConnection
objCommand.CommandText = "Select Name, Location from 'LDAP://" & strDomainName & "'" _
& "Where objectClass ='computer'"
objCommand.Properties("Page Size") = 1000
objCommand.Properties("Searchscope") = ADS_SCOPE_SUBTREE
Set objRecordSet = objCommand.Execute
'**********************************************************************************
objRecordSet.MoveFirst
Wscript.Echo "Processing information. This might take several minutes."
Do Until objRecordSet.EOF
    strComputer = objRecordSet.Fields("Name").Value
' Проверяем доступность компьютера с помощью команды PING
' и анализа выходного потока
    Set objScriptExec = objShell.Exec("%comspec% /c ping.exe -n 1 " & strComputer)
    strPingResults = LCase(objScriptExec.StdOut.ReadAll)
'    Если компьютер отвечает, подключаемся к его WMI
    If InStr(strPingResults, "ttl=") Then
     Set objWMIService = GetObject("winmgmts:" _
    & "{impersonationLevel=impersonate}!\\" & strComputer & "\root\cimv2")

        Set colComputer = objWMIService.ExecQuery _
    ("Select * from Win32_ComputerSystem")

' Выводим список залогиненных пользователей в файл и на экран
        For Each objComputer in colComputer
'             Wscript.Echo "Logged-on " &strComputer & " user: " & objComputer.UserName
             file.WriteLine("Logged-on " &strComputer & " user: " & objComputer.UserName)
        Next
        objRecordSet.MoveNext

' Если компьютер не отвечает - выводим сообщение и перемещаемся к следующему
    Else
'     WScript.Echo(strComputer & ": Не отвечает...")
        objRecordSet.MoveNext
    End If
Loop