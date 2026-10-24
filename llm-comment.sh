#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

uv run "$SCRIPT_DIR/lib/llm_comment.py" \
    --host "http://127.0.0.1:8010" \
    --model "mistral-7b-instruct-v0.3" \
    "$@"
