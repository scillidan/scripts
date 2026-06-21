#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

uv run "$SCRIPT_DIR/lib/llm_translate.py" \
    --host "http://127.0.0.1:8010" \
    --model "gemma-3-4b-it-qat" \
    --auto-mode all2zh-cn \
    --auto-mode zh-cn2en \
    --prompt quick \
    "$@"
