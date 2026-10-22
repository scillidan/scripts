@echo off
REM Install a single Inno Setup package silently
REM
REM Usage:
REM   Windows (SendTo):
REM     Create a .lnk shortcut to this script in the SendTo folder, then:
REM     Select one .exe installer > Right-click > Send To > installerexe_silent_install
REM
REM   Command line:
REM     script.cmd <installer.exe>

setlocal enabledelayedexpansion

if "%~1"=="" (
    echo Error: No file selected
    goto :error_exit
)

if not "%~2"=="" (
    echo Error: Select only one installer at a time
    goto :error_exit
)

echo Installing: %~1

"%~1" ^
  /VERYSILENT ^
  /SUPPRESSMSGBOXES ^
  /NORESTART ^
  /DIR="%USERPROFILE%\Downloads\%~n1"

if errorlevel 1 (
    echo Error: Failed to install %~1
    goto :error_exit
)

endlocal
exit /b 0

:error_exit
echo.
echo Press Enter to exit...
pause >nul
endlocal
exit /b 1
