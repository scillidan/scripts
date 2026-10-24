#!/usr/bin/env bash
# Start Kokoro-FastAPI (Linux + Windows git bash).

set -e

USERHOME="${USERHOME:-$HOME}"
VENV_ACT=".venv/bin/activate"

# Windows python needs Windows-style paths and PYTHONPATH separator.
case "$(uname -s)" in
MINGW* | MSYS* | CYGWIN*)
	WIN=1
	PSEP=";"
	[[ -f $VENV_ACT ]] || VENV_ACT=".venv/Scripts/activate"
	;;
*)
	PSEP=":"
	;;
esac

cd "$USERHOME/Local/OptAud/Kokoro-FastAPI" || exit 1

if [[ -f "$VENV_ACT" ]]; then
	source "$VENV_ACT"
else
	echo "Virtual environment not found at: $VENV_ACT"
	exit 1
fi

export PYTHONUTF8=1
PROJECT_ROOT="$(pwd)"
[[ ${WIN:-} ]] && PROJECT_ROOT="$(cygpath -w "$PROJECT_ROOT")"
export PROJECT_ROOT
export USE_GPU=true
export USE_ONNX=false
export PYTHONPATH="$PROJECT_ROOT$PSEP$PROJECT_ROOT/api"
export MODEL_DIR=src/models
export VOICES_DIR=src/voices/v1_0
export WEB_PLAYER_PATH="$PROJECT_ROOT/web"
uv run python docker/scripts/download_model.py --output api/src/models/v1_0
uv run uvicorn api.src.main:app --host 127.0.0.1 --port 8880
