#!/usr/bin/env bash
# Start ComfyUI (Linux + Windows git bash).

set -e

USERHOME="${USERHOME:-$HOME}"
VENV_ACT=".venv/bin/activate"
case "$(uname -s)" in
MINGW* | MSYS* | CYGWIN*)
	[[ -f $VENV_ACT ]] || VENV_ACT=".venv/Scripts/activate"
	;;
esac

cd "$USERHOME/Local/OptImg/ComfyUI" || exit 1

if [[ -f "$VENV_ACT" ]]; then
	source "$VENV_ACT"
else
	echo "Virtual environment not found at: $VENV_ACT"
	exit 1
fi

exec python main.py
