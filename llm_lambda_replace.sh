#!/bin/bash

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)

uv run "$SCRIPT_DIR/lib/llm_lambda_replace.py" \
    --host "http://127.0.0.1:8010" \
    --model "gemma-3-4b-it-qat" \
    "$@"
