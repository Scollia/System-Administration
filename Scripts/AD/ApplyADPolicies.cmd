@echo off
set logdir=\\corp.dskvrn.ru\sharedpo\log\Scripts\%~nx0
set logfiles=%logdir%\%computername%.log
md %logdir%

echo %date%	%time%	%username%	Apply	%1 >> %logfiles%
