#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

uv run "$SCRIPT_DIR/fzf_bookmarks.py" \
  -d "$USERHOME/Share/files/bookmarks" \
  --opener "$BROSER" \
  --fzf-arg=--multi \
  --fzf-arg=--height=80%