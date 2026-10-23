@echo off
rem --------------------------------------------------------------------------
rem transform-query helper for fzf-ripgrep.cmd.
rem fzf calls this when switching between ripgrep mode (r) and fzf filter
rem mode (f): the new mode's query is saved to a temp file, and the other
rem mode's last query is printed back to fzf.
rem --------------------------------------------------------------------------
setlocal
set "NEW=%~1"
if /i "%NEW%"=="f" (set "OLD=r") else (set "OLD=f")

rem fzf caret-quotes {q} for cmd, so %~2 normally already yields the bare
rem query.  Other {q} styles (raw "", backslash \"\", or '' for non-cmd
rem shells) leave literal quotes behind; strip one matching outer pair.
rem Detection uses quote-removal (%X%) because literal """ sequences in
rem if-comparisons break cmd's parser.
set "Q=%~2"
if defined Q call :strip

rem Leading redirect so a query ending in a digit can't be read as a handle.
> "%TEMP%\fzf-ripgrep_%OLD%.tmp" echo(%Q%

rem Print the other mode's last query (first line of its temp file).
set "PREV="
if exist "%TEMP%\fzf-ripgrep_%NEW%.tmp" set /p "PREV=" <"%TEMP%\fzf-ripgrep_%NEW%.tmp"
if defined PREV set "Q=%PREV%"
if defined PREV call :strip
if defined PREV set "PREV=%Q%"
echo(%PREV%
endlocal
goto :eof

:strip
rem shortcut: only ONE outer pair is removed; a query with interior quotes
rem keeps them (and any backslashes in front of them).
set "X=%Q:~0,2%"
set "Y=%Q:~-2%"
set X=%X:"=%
set Y=%Y:"=%
if not "%X%"=="%Y%" goto :eof
if "%X%"=="" set "Q=%Q:~2,-2%"
if "%X%"=="\" set "Q=%Q:~2,-2%"
if "%X%"=="'" set "Q=%Q:~2,-2%"
goto :eof
