@echo off
REM scoop-shortcut.cmd - (re)apply the SCOOP_MENU_DIR patch to scoop's
REM shortcuts.ps1. `scoop update` reverts it; run this after updating scoop
REM (scoop-shortcuts-unpatch.ps1 reverts it on purpose).
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scoop-shortcuts-patch.ps1"
exit /b %errorlevel%
