@echo off
REM scoop wrapper. This folder must precede %Scoop%\shims in PATH, otherwise
REM the real shim shadows it and none of this runs.
REM   scoop update ...  -> scoop-update-auto.ps1: if scoop fails with "still
REM                          running", ask, close the app, and retry.
REM   anything else     -> re-apply the SCOOP_MENU_DIR patch to scoop's
REM                          shortcuts.ps1 (scoop update reverts it), then
REM                          delegate to the real shim.
setlocal
set "SCOOP_ROOT=%SCOOP%"
if not defined SCOOP_ROOT set "SCOOP_ROOT=%USERPROFILE%\Scoop"

if /i "%~1"=="update" (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scoop-update-auto.ps1" %*
    exit /b %errorlevel%
)

findstr /c:"SCOOP_MENU_DIR" "%SCOOP_ROOT%\apps\scoop\current\lib\shortcuts.ps1" >nul 2>&1
if errorlevel 1 powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scoop-shortcuts-patch.ps1" >nul
"%SCOOP_ROOT%\shims\scoop.cmd" %*
