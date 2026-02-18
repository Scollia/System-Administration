@echo off
set logdir=\\corp.dskvrn.ru\sharedpo\log\Scripts\%~nx0
set logfiles=%logdir%\%computername%.log
md %logdir%

rem net start w32time
w32tm /config /syncfromflags:DOMHIER /update
net stop w32time
net start w32time

w32tm /resync /rediscover

echo %date%	%time%	%username%	Sync >> %logfiles%