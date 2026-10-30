@echo off
REM scoop-home.cmd - open an app's homepage in %BROWSER% instead of the system
REM default browser (scoop's own `home` ignores %BROWSER%). See scoop-home-browser.ps1.
if "%~1"=="" (echo usage: scoop-home ^<app^>& exit /b 1)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scoop-home-browser.ps1" "%~1"
exit /b %errorlevel%
