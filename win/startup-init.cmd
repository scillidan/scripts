@echo off

cd /d "%~dp0"

pwsh -ExecutionPolicy Bypass -File "init_startup.ps1"

pause