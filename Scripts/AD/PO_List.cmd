@echo off
set logdir=\\corp.dskvrn.ru\sharedpo\log\Scripts\%~nx0
set logfiles=%logdir%\%computername%.log
md %logdir%

wmic product get name > %logfiles%
rem wmic product name > %logfiles%