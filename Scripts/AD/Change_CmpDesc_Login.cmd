@echo off
set logdir=\\corp.dskvrn.ru\sharedpo\log\Scripts\%~nx0\%1
set logfiles=%logdir%\%computername%_%username%.log
md %logdir%

dir \\corp.dskvrn.ru\sharedpo\Scripts\ > %logfiles%