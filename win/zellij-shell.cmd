@echo off
if not defined USERHOME set "USERHOME=%USERPROFILE%"
python "%USERHOME%\Share\scripts\lib\zellij_shell.py" %*
