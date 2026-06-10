@echo off
REM Open files with lessmsi
REM
REM Usage:
REM   Windows:
REM     Create a .lnk shortcut to this script in the SendTo folder, then:
REM     Select files > Right-click > Send To > win_lessmsi_msis.cmd
REM
REM   Command line:
REM     win_lessmsi_msis.cmd <file1> <file2> ...

setlocal EnableDelayedExpansion

set ERROR=0

:loop
if "%~1"=="" goto :end

echo Opening: %~1

lessmsi o "%~1"

if errorlevel 1 (
    echo Error: Failed to open %~1
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