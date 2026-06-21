#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

uv run "$SCRIPT_DIR/lib/llm_grammar.py" \
    --host "http://127.0.0.1:8010" \
    --model "gemma_2b_coedit" \
    "$@"
