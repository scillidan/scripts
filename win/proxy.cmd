@echo off
rem Minimal local http/https proxy switcher for Windows cmd.
rem Use with `call` so the env vars stick in the current session:
rem   call proxy.cmd on [port]
rem   call proxy.cmd off

if "%PROXY_HOST%"=="" set "PROXY_HOST=127.0.0.1"
if "%PROXY_PORT%"=="" set "PROXY_PORT=7890"

set "_arg1=%~1"
set "_arg2=%~2"

if "%_arg1%"=="on" goto :do_on
if "%_arg1%"=="off" goto :do_off
if "%_arg1%"=="status" goto :do_status
goto :do_help

:do_on
set "_port=%_arg2%"
if "%_port%"=="" set "_port=%PROXY_PORT%"
set "_url=http://%PROXY_HOST%:%_port%"
set "http_proxy=%_url%"
set "https_proxy=%_url%"
set "HTTP_PROXY=%_url%"
set "HTTPS_PROXY=%_url%"
echo proxy: on (%_url%)
goto :cleanup

:do_off
set "http_proxy="
set "https_proxy="
set "HTTP_PROXY="
set "HTTPS_PROXY="
echo proxy: off
goto :cleanup

:do_status
if defined http_proxy (echo http_proxy  = %http_proxy%) else echo http_proxy  = ^<unset^>
if defined https_proxy (echo https_proxy = %https_proxy%) else echo https_proxy = ^<unset^>
if defined HTTP_PROXY (echo HTTP_PROXY  = %HTTP_PROXY%) else echo HTTP_PROXY  = ^<unset^>
if defined HTTPS_PROXY (echo HTTPS_PROXY = %HTTPS_PROXY%) else echo HTTPS_PROXY = ^<unset^>
goto :cleanup

:do_help
echo Usage:
echo   proxy.cmd on [port]        enable proxy in current cmd session ^(default 7890^)
echo   proxy.cmd off              disable proxy in current cmd session
echo   proxy.cmd status           show proxy env vars
echo.
echo Note:
echo   Use `call proxy.cmd ...` when calling from another batch file.
echo.
echo Environment:
echo   PROXY_HOST   default 127.0.0.1
echo   PROXY_PORT   default 7890

:cleanup
set "_arg1="
set "_arg2="
set "_port="
set "_url="
