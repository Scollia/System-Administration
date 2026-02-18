@echo off
set logdir=\\corp.dskvrn.ru\sharedpo\log\Scripts\%~nx0
set logfiles=%logdir%\%computername%.log
md %logdir%

setlocal enabledelayedexpansion

Netsh interface ipv4 set winsservers ethernet static 10.18.0.10
Netsh interface ipv4 add winsservers ethernet 10.18.0.11

Netsh interface ipv4 set winsservers ethernet0 static 10.18.0.10
Netsh interface ipv4 add winsservers ethernet0 10.18.0.11

echo %date%	%time%	%username%	Set >> %logfiles%