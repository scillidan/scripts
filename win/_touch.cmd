@echo off
if "%~1"=="" exit /b 1
for %%F in ("%~1") do (
    if not "%%~dpF"=="" md "%%~dpF" >nul 2>&1
)
type nul > "%~1"