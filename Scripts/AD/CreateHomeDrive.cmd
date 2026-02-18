@echo off
set logdir=\\corp.dskvrn.ru\sharedpo\log\Scripts\%~nx0
set logfiles=%logdir%\%username%.log
md %logdir%

echo %date%	%time%	%computername%	\\corp.dskvrn.ru\SharedFiles\HomeDir\%UserName% >> %logdir%\%username%.log

md \\corp.dskvrn.ru\SharedFiles\HomeDir\%UserName% >> %logdir%\%username%.log
if %errorlevel%==0 (
  echo %date%	%time%	%computername%	Not Exist >> %logdir%\%username%.log
) else (
  echo %date%	%time%	%computername%	Exists >> %logdir%\%username%.log
)