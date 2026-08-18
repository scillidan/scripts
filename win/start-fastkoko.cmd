@echo off
setlocal

set "BASE_DIR=%USERPROFILE%"
set "VENV_ACT=.venv\Scripts\activate"

pushd "%BASE_DIR%\Local\OptAud\Kokoro-FastAPI" || exit /b 1

if exist "%VENV_ACT%" (
    call "%VENV_ACT%"
) else (
    echo Virtual environment not found at: %VENV_ACT%
    exit /b 1
)

set "PYTHONUTF8=1"
set "PROJECT_ROOT=%CD%"
set "USE_GPU=true"
set "USE_ONNX=false"
set "PYTHONPATH=%PROJECT_ROOT%;%PROJECT_ROOT%\api"
set "MODEL_DIR=src/models"
set "VOICES_DIR=src/voices/v1_0"
set "WEB_PLAYER_PATH=%PROJECT_ROOT%\web"

uv run python docker/scripts/download_model.py --output api/src/models/v1_0
uv run uvicorn api.src.main:app --host 127.0.0.1 --port 8880

popd
endlocal
