#!/usr/bin/env bash
set -euo pipefail

export PYTHONUTF8=1
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PY="$SCRIPT_DIR/lib/fzf_txt.py"
BASE="${USERHOME:-$HOME}/Share/files"

DIR_BOOKMARKS="$BASE/bookmarks"
DIR_CHEATSHEETS="$BASE/cheatsheets"
DIR_COMMANDS="$BASE/commands"
DIR_SHORTCUTS="$BASE/shortcuts"

ARGS=( --multi --exclude '_cache' --exclude '_temp' )

usage() {
  printf 'Usage: %s {bookmarks|cheatsheets|commands|shortcuts} [args...]\n' "${0##*/}"
}

case "${1:-}" in
  bookmarks)   fmt=bookmarks;   dir="$DIR_BOOKMARKS" ;;
  cheatsheets) fmt=cheatsheets; dir="$DIR_CHEATSHEETS" ;;
  commands)    fmt=commands;    dir="$DIR_COMMANDS" ;;
  shortcuts)   fmt=shortcuts;   dir="$DIR_SHORTCUTS" ;;
  -h|--help|--list-formats) exec uv run --script "$PY" "$@" ;;
  "")          usage >&2; exit 2 ;;
  *)           printf 'Unknown category: %s\n' "$1" >&2; usage >&2; exit 2 ;;
esac
shift

inject_dir=1
for arg in "$@"; do
  case "$arg" in
    -f|--file|-d|--directory|-f=*|--file=*|-d=*|--directory=*) inject_dir=0; break ;;
  esac
done

if (( inject_dir )); then
  exec uv run --script "$PY" "$fmt" -d "$dir" "${ARGS[@]}" "$@"
else
  exec uv run --script "$PY" "$fmt" "${ARGS[@]}" "$@"
fi
