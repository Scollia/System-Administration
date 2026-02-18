rem gp_cmpusr_Import_AllCert
rem start
c:\Windows\System32\certmgr.msc /add /all /c \\corp.dskvrn.ru\sharedpo\Certificates\root\*.cer /s /r root
rem start
c:\Windows\System32\certmgr.msc /add /all /c \\corp.dskvrn.ru\sharedpo\Certificates\my\*.cer /s /r my
                            	