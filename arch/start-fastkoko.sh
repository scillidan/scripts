#!/bin/bash

set -e

cleanup() {
	unset BASE_DIR
	unset VENV_ACT
	unset PYTHONUTF8
	unset PROJECT_ROOT
	unset USE_GPU
	unset USE_ONNX
	unset PYTHONPATH
	unset MODEL_DIR
	unset VOICES_DIR
	unset WEB_PLAYER_PATH
	trap - EXIT
}
trap cleanup EXIT

BASE_DIR="$HOME"
VENV_ACT=".venv/bin/activate"

pushd "$BASE_DIR/Local/OptAud/Kokoro-FastAPI" || exit 1

if [ -f "$VENV_ACT" ]; then
	source "$VENV_ACT"
else
	echo "Virtual environment not found at: $VENV_ACT"
	exit 1
fi

export PYTHONUTF8=1
export PROJECT_ROOT=$(pwd)
export USE_GPU=true
export USE_ONNX=false
export PYTHONPATH=$PROJECT_ROOT:$PROJECT_ROOT/api
export MODEL_DIR=src/models
export VOICES_DIR=src/voices/v1_0
export WEB_PLAYER_PATH=$PROJECT_ROOT/web
uv run python docker/scripts/download_model.py --output api/src/models/v1_0
uv run uvicorn api.src.main:app --host 127.0.0.1 --port 8880

popd || exit 1
