@echo off
REM Open a single MSI file with lessmsi
REM
REM Usage:
REM   Windows:
REM     Create a .lnk shortcut to this script in the SendTo folder, then:
REM     Select one .msi file > Right-click > Send To > msis_lessmsi
REM
REM   Command line:
REM     script.cmd <file.msi>

setlocal EnableDelayedExpansion

if "%~1"=="" (
    echo Error: No file selected
    goto :error_exit
)

if not "%~2"=="" (
    echo Error: Select only one file at a time
    goto :error_exit
)

echo Opening: %~1

lessmsi o "%~1"

if errorlevel 1 (
    echo Error: Failed to open %~1
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
