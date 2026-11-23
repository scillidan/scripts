@echo off

SET "TereEXE=tere.exe"
SET "OUTPUT="

rem Clear ENABLE_VIRTUAL_TERMINAL_INPUT if a previous program (e.g. a killed
rem bash) left it on the shared console -- otherwise arrow keys show up as
rem literal "[D" characters inside tere.
powershell -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "%~dp0tere-fixmode.ps1"

rem Run tere and capture the selected directory.
FOR /F "delims=" %%a in ('%TereEXE% %*') do SET "OUTPUT=%%a"

rem tere was cancelled or did not return a directory.
IF NOT DEFINED OUTPUT goto :EOF

rem /d also handles switching to another drive.
cd /d "%OUTPUT%" || goto :EOF

rem Record the successfully selected directory in zoxide.
rem %CD% is expanded here, after cd, so it contains the new absolute path.
zoxide add "%CD%"

goto :EOF