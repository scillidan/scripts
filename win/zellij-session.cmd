@echo off
rem zellij-session (Windows): thin entry for lib/zellij_session.py.
rem Usage (pass the directory unquoted; cmd keeps quotes and Python then sees no dir):
rem     cd /d C:\path && zellij-session .            session named after the directory
rem     zellij-session                            session "session"
rem     zellij-session NAME                       named session
rem Must be run from an interactive terminal: creating a session needs a real console.
setlocal
set "PY=python"
where /q python3 >nul 2>&1 && set "PY=python3"
"%PY%" "%~dp0..\lib\zellij_session.py" %*
