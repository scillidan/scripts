@echo off

pushd %USERHOME%\Local\OptImg\ComfyUI

call .venv\Scripts\activate.bat
python main.py

deactivate

popd