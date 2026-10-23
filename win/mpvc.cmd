@echo off
rem Thin cmd wrapper: the real script is the cross-platform mpvc.sh at the repo root.
bash "%~dp0..\mpvc.sh" %*
