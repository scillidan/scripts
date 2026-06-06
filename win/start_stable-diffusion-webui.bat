@echo off

setlocal

cd %USERHOME%\Local\OptImg\stable-diffusion-webui && start webui-user.bat
start webui-user.bat

endlocal

pause