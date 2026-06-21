@echo off
REM Convert Ahk scripts to EXEs
REM
REM Usage:
REM   Windows (SendTo):
REM     Create a .lnk shortcut to this script in the SendTo folder, then:
REM     Select files > Right-click > Send To > ahks_to_exes.cmd
REM
REM   Command line:
REM     script.cmd <file1> <file2> ...

setlocal enabledelayedexpansion

set ERROR=0

:loop
if "%~1"=="" goto :end

echo Converting: %~1

ahk2exe /in "%~1" /out "%~n1.exe"

if errorlevel 1 (
    echo Error: Failed to convert %~1
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