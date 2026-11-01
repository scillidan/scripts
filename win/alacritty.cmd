@echo off
setlocal
if /i "%~1"=="migrate" goto :cli
if /i "%~1"=="help" goto :cli
if "%~1"=="-h" goto :cli
if "%~1"=="--help" goto :cli
if "%~1"=="-V" goto :cli
if "%~1"=="--version" goto :cli
goto :launch

:cli
alacritty.exe %*
exit /b %ERRORLEVEL%

:launch
if not defined USERHOME set "USERHOME=%USERPROFILE%"
set "CONFIG=%USERHOME%\Share\dotfiles\.config\alacritty\alacritty.toml"

if not exist "%CONFIG%" (
    echo alacritty.cmd: missing %CONFIG% >&2
    exit /b 1
)
alacritty-theme --config-file "%CONFIG%" --working-directory "%USERHOME%\Downloads" %* --command cmd.exe /k "%USERHOME%\Share\dotfiles.win\Scoop\clink\init.cmd"
