@echo off
REM scoop-update.cmd - `scoop update` with "still running" handling: lists the
REM offending processes, asks, closes them and retries. See scoop-update-auto.ps1.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scoop-update-auto.ps1" update %*
exit /b %errorlevel%
