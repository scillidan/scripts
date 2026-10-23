@echo off
rem Fix: OLD/Q must live inside the same setlocal scope; endlocal discarded OLD.
setlocal
set "NEW=%~1"
if /i "%NEW%"=="f" (set "OLD=r") else (set "OLD=f")
set "Q=%~2"
rem Leading redirect so a query ending in a digit can't be read as a handle.
> "%TEMP%\fzf_ripgrep_%OLD%.tmp" echo(%Q%
type "%TEMP%\fzf_ripgrep_%NEW%.tmp" 2>nul
endlocal
