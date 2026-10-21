@echo off

SET TereEXE=tere.exe

rem clear ENABLE_VIRTUAL_TERMINAL_INPUT if a previous program (e.g. a killed
rem bash) left it on the shared console -- otherwise arrow keys show up as
rem literal "[D" characters inside tere
powershell -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "%~dp0tere-fixmode.ps1"

FOR /F "tokens=*" %%a in ('%TereEXE% %*') do SET OUTPUT=%%a
IF ["%OUTPUT%"] == [""] goto :EOF
cd %OUTPUT%