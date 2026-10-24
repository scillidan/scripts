@echo off
REM scoop wrapper: makes sure the SCOOP_MENU_DIR patch is present in scoop's
REM shortcuts.ps1 (scoop update reverts it), then delegates to the real shim.
REM Put this folder (E:\Share\scripts\win) BEFORE E:\Scoop\shims in PATH.
findstr /c:"SCOOP_MENU_DIR" "E:\Scoop\apps\scoop\current\lib\shortcuts.ps1" >nul 2>&1
if errorlevel 1 powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scoop-shortcuts-patch.ps1" >nul
"E:\Scoop\shims\scoop.cmd" %*
