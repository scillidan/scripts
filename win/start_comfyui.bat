@echo off

pushd %USERHOME%\Usr\OptImg\ComfyUI

call .venv\Scripts\activate.bat
python main.py

deactivate

popd