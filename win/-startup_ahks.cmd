@echo off

setlocal

set AHK_SRC=%USERHOME%\Local\Source\autohotkey

start "" autohotkeyu64 "%USERHOME%\Share\projs\scripts\win\user.ahk"
timeout /t 1 /nobreak >nul

start "" autohotkeyu64 "%AHK_SRC%\Vis2\Vis2.ahk"

endlocal