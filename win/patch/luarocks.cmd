@echo off
set "BASE=%SCOOP%\apps\msys2\current\ucrt64"
set "PATH=%BASE%\bin;%PATH%"
set "LIBRARY_PATH=%BASE%\lib;%BASE%\x86_64-w64-mingw32\lib"
set "C_INCLUDE_PATH=%BASE%\include"
"C:\Lua\5.4.8\bin\luarocks.exe" %*
