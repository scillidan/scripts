@echo off

SET "MSYS2_ENVS=msys2 mingw mingw32 mingw64 clang64 clangarm64 ucrt64"

IF "%1"=="" (
    echo Usage:
    echo   setpath ^<env^> [--mini]
    echo.
    echo Available environments:
    for %%e in (%MSYS2_ENVS%) do (
        echo   %%e
    )
    exit /b 1
)

SET MSYS2_ENV=%1
SET MINI_MODE=0

IF /I "%2"=="--mini" SET MINI_MODE=1

SET MSYS2_ROOT=%SCOOP%\apps\msys2\current\home

IF %MINI_MODE%==1 (
    SET "PATH=%SystemRoot%\System32"
    SET "PATH=%PATH%;%SystemRoot%\System32\Wbem"
    SET "PATH=%PATH%;%SystemRoot%\System32\WindowsPowerShell\v1.0\"
) ELSE (
    REM keep existing PATH
)

SET "PATH=%MSYS2_ROOT%\usr\bin;%PATH%"
SET "PATH=%PATH%;%MSYS2_ROOT%\usr\local\bin"

REM Toolchains
SET "PATH=%PATH%;%MSYS2_ROOT%\mingw64\bin"
rem SET "PATH=%PATH%;%MSYS2_ROOT%\usr\bin\site_perl"
rem SET "PATH=%PATH%;%MSYS2_ROOT%\usr\bin\vendor_perl"

"%MSYS2_ROOT%\msys2_shell.cmd" ^
  -%MSYS2_ENV% ^
  -defterm ^
  -here ^
  -full-path ^
  -no-start