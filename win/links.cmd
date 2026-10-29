@echo off
REM links resolves relative paths against its own home page (Downloads), not the
REM caller's cwd. Rewrite every argument that names an existing path to an
REM absolute path, and leave options/URLs alone.
setlocal EnableDelayedExpansion
if "%~1"=="" (
    links.exe
    exit /b
)
set "ARGS="
REM shortcut: paths containing "!" are mangled by delayed expansion; rename them.
for %%A in (%*) do (
    if exist "%%~A" (
        set "ARGS=!ARGS! "%%~fA""
    ) else (
        set "ARGS=!ARGS! "%%~A""
    )
)
links.exe !ARGS!
