@echo off
REM Open and install Inno Setup packages silently
REM
REM Usage:
REM   Windows (SendTo):
REM     Create a .lnk shortcut to this script in the SendTo folder, then:
REM     Select files > Right-click > Send To > installer-exe_dir.cmd
REM
REM   Command line:
REM     install_inno.cmd <file1> <file2> ...

setlocal enabledelayedexpansion

set ERROR=0

:loop
if "%~1"=="" goto :end

echo Installing: %~1

"%~1" ^
  /VERYSILENT ^
  /SUPPRESSMSGBOXES ^
  /NORESTART ^
  /DIR="%USERPROFILE%\Downloads\%~n1"

if errorlevel 1 (
    echo Error: Failed to install %~1
    set ERROR=1
)

shift
goto :loop

:end
if %ERROR% neq 0 (
    echo.
    echo Press Enter to exit...
    pause >nul
)

endlocal