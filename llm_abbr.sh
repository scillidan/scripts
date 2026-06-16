#!/bin/bash

INPUT="${1:-<input>}"

uv run "$HOME/Share/scripts/lib/llm_abbr.py" \
    --host "http://127.0.0.1:8010" \
    --model "gemma-3-4b-it-qat" \
    --save-cache "$INPUT"