@echo off

setlocal enableextensions

set "TERM="
set "WORKDIR=%cd%"

bash --login -i -c "cd \"$(cygpath -u '%WORKDIR%')\"; exec bash"