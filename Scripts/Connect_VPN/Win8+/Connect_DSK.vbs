strUserName = InputBox("¬ведите им€ пользовател€", "¬вод имени пользовател€", strInFullUserName)
strUserPwd  = InputBox("¬ведите пароль", "¬вод парол€ пользовател€", strInFullUserName)

Set objShell = CreateObject("Wscript.Shell")
objShell.Run("powershell.exe .\Connect_DSK.ps1 " & strUserName & " " & strUserPwd)
