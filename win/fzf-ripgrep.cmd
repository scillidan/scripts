@echo off
rem --------------------------------------------------------------------------
rem Interactive grep launcher: fzf + ripgrep (+ bat preview).
rem Merges clink-gizmos' fzf_rg.lua (empty-query reload guard, rg<->fzf mode
rem switching via fzf-ripgrep-tq.cmd) with the local fzf_files.cmd habits
rem (style flags, preview toggles, editor binds).
rem Preview defaults to the vertical (bottom) layout; CTRL-\ rotates to right.
rem Dependences: rg, fzf, bat.  Optional: subl, nvim.
rem --------------------------------------------------------------------------
setlocal

rem -- rg flags (2>&1 surfaces option errors inside fzf).
rem    Optional extra filters via env, e.g.  set FZF_RG_EXTRA=-g *.py -g "!**/dist/**"
rem    (globs only; & | > < in the value would break cmd parsing).
set "RG=rg.exe --hidden --follow --glob "!.git" --column --line-number --no-heading --color=always --smart-case 2>&1"
if defined FZF_RG_EXTRA set "RG=%RG% %FZF_RG_EXTRA%"

rem -- Reload guard: echo {q}| is exactly 2 chars when empty; findstr needs 3+.
rem    Skip rg on empty query, and "|| ver >nul" clears errorlevel so fzf
rem    doesn't report a failed reload.
set "RELOAD=echo {q}| findstr ... >nul && %RG% {q} || ver >nul"

rem -- bat preview, highlight the matched line.
set "PREVIEW=bat.exe --force-colorization --style=numbers --highlight-line {2} {1}"
set "PVWIN=up,60%%,border-bottom,+{2}+3/3,~2"

rem -- fzf flags.  NOTE: no & | > < in here; unquoted %VAR% expansion goes
rem    live on the command line, so every option with such chars is written
rem    inline and source-quoted below instead of via variables.
set "FLAGS=--ansi --disabled --delimiter : --height 99%% --layout=reverse --border none --preview-border none --no-scrollbar --no-separator --inline-info"

rem -- Mode switching (CTRL-F = fzf filter, CTRL-R = ripgrep); the tq helper
rem    remembers each mode's query.  fzf mode starts with an empty query.
set "TQ=%~dp0fzf-ripgrep-tq.cmd"
del "%TEMP%\fzf-ripgrep_f.tmp" 2>nul

fzf.exe %FLAGS% --prompt "rg> " --query "%*" --preview "%PREVIEW%" --preview-window "%PVWIN%" --bind "start:reload(%RELOAD%)+unbind(ctrl-r)" --bind "change:reload(%RELOAD%)" --bind "ctrl-f:unbind(change,ctrl-f)+change-prompt(fzf> )+enable-search+rebind(ctrl-r)+transform-query(%TQ% f {q})" --bind "ctrl-r:unbind(ctrl-r)+change-prompt(rg> )+disable-search+rebind(change,ctrl-f)+transform-query(%TQ% r {q})+reload(%RELOAD%)" --bind "enter:execute(subl -a {1}:{2})" --bind "alt-enter:execute(subl -a {1}:{2})+abort" --bind "ctrl-o:execute(nvim +{2} {1})+abort,alt-n:execute(nvim +{2} {1})" --bind "ctrl-k:preview-up,ctrl-j:preview-down,ctrl-h:preview-page-up,ctrl-l:preview-page-down,ctrl-\:change-preview-window(right,60%%,wrap,+{2}+3/3,~2|%PVWIN%)"

endlocal
