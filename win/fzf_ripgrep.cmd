@echo off
rem --------------------------------------------------------------------------
rem Interactive grep launcher: fzf + ripgrep + bat.
rem Merges clink-gizmos' fzf_rg.lua (empty-query reload guard, rg<->fzf mode
rem switching via fzf_ripgrep_tq.cmd) with the local fzf_files.cmd habits
rem (style flags, preview position toggle, editor binds).
rem Dependences: rg, fzf, bat.  Optional: subl, nvim.
rem --------------------------------------------------------------------------
setlocal

rem -- rg flags (2>&1 surfaces option errors inside fzf).
set "RG=rg.exe --hidden --follow --glob "!.git" --column --line-number --no-heading --color=always --smart-case 2>&1"

rem -- Reload guard: an empty query echoes as "" (2 chars), findstr needs 3+,
rem    so rg only runs on a non-empty query.  "|| ver >nul" clears errorlevel
rem    so fzf does not report a failed reload.
set "RELOAD=echo {q}| findstr ... >nul && %RG% {q} || ver >nul"

rem -- bat preview with the matched line highlighted.
set PREVIEW=bat.exe --force-colorization --style=numbers --highlight-line {2} {1}
set PREVIEW_WINDOW=--preview-window "right,60%%,wrap,+{2}+3/3,~2"

rem -- fzf flags (style shared with fzf_files.cmd).
set FLAGS=--ansi --disabled --delimiter : --height 99%% --layout=reverse --border none --preview-border none --no-scrollbar --no-separator --inline-info

rem -- Mode switching: CTRL-R = ripgrep, CTRL-F = fzf filter; the tq helper
rem    remembers each mode's query.  fzf mode starts with an empty query.
set TQ=%~dp0fzf_ripgrep_tq.cmd
del "%TEMP%\fzf_ripgrep_f.tmp" 2>nul
set BIND_START=--bind "start:reload(%RELOAD%)+unbind(ctrl-r)"
set BIND_CHANGE=--bind "change:reload(%RELOAD%)"
set BIND_FZF=--bind "ctrl-f:unbind(change,ctrl-f)+change-prompt(fzf> )+enable-search+rebind(ctrl-r)+transform-query(%TQ% f {q})"
set BIND_RG=--bind "ctrl-r:unbind(ctrl-r)+change-prompt(rg> )+disable-search+rebind(change,ctrl-f)+transform-query(%TQ% r {q})+reload(%RELOAD%)"

rem -- Editor binds: ENTER edits via subl and keeps fzf open; ALT-ENTER edits
rem    and closes; CTRL-O / ALT-N open Neovim at the matched line.
set BIND_ENTER=--bind "enter:execute(subl -a {1}:{2})"
set BIND_ALTENTER=--bind "alt-enter:execute(subl -a {1}:{2})+abort"
set BIND_NVIM=--bind "ctrl-o:execute(nvim +{2} {1})+abort,alt-n:execute(nvim +{2} {1})"

rem -- Preview binds (fzf_files.cmd habits).
set BIND_PREVIEW=--bind "ctrl-k:preview-up,ctrl-j:preview-down,ctrl-h:preview-page-up,ctrl-l:preview-page-down,ctrl-\:change-preview-window(up,60%%,border-bottom,+{2}+3/3,~2|right,60%%,wrap,+{2}+3/3,~2)"

rem -- Extra query text from the command line.
set QUERY=
if not "%*"=="" set QUERY=--query "%*"

fzf.exe %FLAGS% --prompt "rg> " %BIND_START% %BIND_CHANGE% %BIND_FZF% %BIND_RG% %BIND_ENTER% %BIND_ALTENTER% %BIND_NVIM% %BIND_PREVIEW% --preview "%PREVIEW%" %PREVIEW_WINDOW% %QUERY%

endlocal
