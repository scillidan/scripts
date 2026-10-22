@echo off
REM Create SendTo shortcuts for executable files
REM
REM Notes:
REM   - Supports .sh, .bat, .cmd, .ps1, .exe and other executable files
REM   - Existing shortcuts will be overwritten without warning
REM   - .bat, .cmd files will use sendto.ico
REM   - .sh files will use sendto_outline.ico
REM   - .ps1 files will use sendto.ico
REM   - .exe files use their own embedded icon
REM   - Requires PowerShell on Windows

setlocal EnableDelayedExpansion

set "SENDTO_DIR=%APPDATA%\Microsoft\Windows\SendTo"
set "SCRIPT_DIR=%~dp0"
set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"
set "SENDTO_ICON=%SCRIPT_DIR%\share\sendto.ico"
set "SENDTO_OUTLINE_ICON=%SCRIPT_DIR%\share\sendto_outline.ico"

set ERROR=0

if not exist "%SENDTO_DIR%\" (
    echo Error: SendTo folder not found. This script only works on Windows.
    goto :error_exit
)

:loop
if "%~1"=="" goto :end

call :create_shortcut "%~1" || set ERROR=1
shift
goto :loop

:create_shortcut
set "script_path=%~f1"
set "base_name=%~n1"
set "ext=%~x1"
set "lnk_path=%SENDTO_DIR%\%base_name%.lnk"

if not exist "%script_path%" (
    echo Error: File not found: %script_path%
    exit /b 1
)

set "icon="
set "target="
set "args="

if /i "%ext%"==".bat" set "icon=%SENDTO_ICON%"
if /i "%ext%"==".cmd" set "icon=%SENDTO_ICON%"
if /i "%ext%"==".sh" set "icon=%SENDTO_OUTLINE_ICON%"
if /i "%ext%"==".ps1" (
    set "icon=%SENDTO_ICON%"
    set "target=powershell.exe"
    set "args=-NoProfile -ExecutionPolicy Bypass -File \"%script_path%\""
)

if not defined target set "target=%script_path%"

powershell -NoProfile -Command ^
 "$ws=New-Object -ComObject WScript.Shell;"^
 "$s=$ws.CreateShortcut('%lnk_path%');"^
 "$s.TargetPath='%target%';"^
 "if ('%args%' -ne '') { $s.Arguments='%args%' };"^
 "if ('%icon%' -ne '') { $s.IconLocation='%icon%' };"^
 "$s.Save()"

if errorlevel 1 (
    echo Error: Failed to create shortcut for: %script_path%
    exit /b 1
)

echo Created: %lnk_path%
exit /b 0

:error_exit
echo.
echo Press Enter to exit...
pause >nul
exit /b 1

:end
if %ERROR% neq 0 (
    echo.
    echo Press Enter to exit...
    pause >nul
)

endlocal