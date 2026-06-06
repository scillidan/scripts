#!/bin/bash
# Activate Python virtual environment and run PyLanguageTool.
# Dependencies: pylanguagetool
# Usage:
# (bash) ./file.sh

cleanup() {
    unset BASE_DIR
    unset VENV_DIR
    unset VENV_ACT
    unset VENV_CMD
    trap - EXIT
}
trap cleanup EXIT

VENV_DIR=".pylanguagetool"
VENV_CMD="pylanguagetool --input-type html --lang en-US -c"

case "$OSTYPE" in
    linux-gnu*)
        # Fill the path
        BASE_DIR="$HOME/Usr/Shell/$VENV_DIR"
        VENV_ACT="./bin/activate"
        ;;
    msys|cygwin)
        # Fill the path
        BASE_DIR="/c/Users/$USERNAME/Usr/Shell/$VENV_DIR"
        VENV_ACT="./Scripts/activate"
        ;;
    *)
        echo "Unsupported OS: $OSTYPE"
        exit 1
        ;;
esac

pushd "$BASE_DIR" || exit 1

if [ -f "$VENV_ACT" ]; then
    source "$VENV_ACT"
else
    echo "Virtual environment not found at: $VENV_ACT"
    exit 1
fi

# Read text from the systems clipboard
$VENV_CMD $*

popd || exit 1

read -p "Press any key to continue..."