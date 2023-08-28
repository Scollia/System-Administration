set /p usr_name="User name: "
set /p usr_pwd="User password: "
net use X: \\corp.dskvrn.ru\UserData\HomeDir\%usr_name% /USER:corp\%usr_name% %usr_pwd% /PERSISTENT:YES
net use W: \\corp.dskvrn.ru\workdata /USER:corp\%usr_name% %usr_pwd% /PERSISTENT:YES

pause
