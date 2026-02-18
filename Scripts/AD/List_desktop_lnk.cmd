@echo off
set logdir=\\corp.dskvrn.ru\sharedpo\log\Scripts\%~nx0
set logfiles=%logdir%\%computername%_%username%.log
md %logdir%

dir /b %appdata%\..\..\Desktop\*.lnk > %logfiles%

set oldfiles=%logdir%\_old_\%computername%_%username%
md %oldfiles%
xcopy %appdata%\..\..\Desktop\*.lnk %oldfiles%\