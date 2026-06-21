#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

uv run "$SCRIPT_DIR/lib/llm_abbreviate.py" \
    --host "http://127.0.0.1:8010" \
    --model "gemma-3-4b-it-qat" \
    --save-cache \
    --include "$USERHOME/Share/scripts/lib/data/abbreviation.cht" \
    "$@"
