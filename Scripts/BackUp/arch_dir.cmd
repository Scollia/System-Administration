@echo off
Set arch_name=%~1
Set src_dir=%~2
if not '%~3'=='' (
 Set log_file=%~3
) else (
 Set log_file=nul
)

"c:\arch\rar.exe" a -cl -ed -ep1 -hpitgroup01 -m5 -mt10 -r -rr10%% -s -y "%arch_name%" "%src_dir%\*.*" > "%log_file%"