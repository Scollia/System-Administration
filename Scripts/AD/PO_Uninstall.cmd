@echo off
set logdir=\\corp.dskvrn.ru\sharedpo\log\Scripts\%~nx0
set logfiles=%logdir%\%computername%.log
md %logdir%

rem wmic product where name="Kerio VPN Client" call uninstall /nointeractive >> %logfiles%
echo "wmic product where name="Kerio VPN Client" call uninstall /nointeractive" >> %logfiles%
rem wmic product where name="Kaspersky 365 1/4 Beta" call uninstall /nointeractive >> %logfiles%
echo "wmic product where name="Kaspersky 365 1/4 Beta" call uninstall /nointeractive" >> %logfiles%
rem wmic product where name="" call uninstall /nointeractive