#!/usr/bin/env bash
set -euo pipefail

export PYTHONUTF8=1

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHEATSHEET_DIR="${CHEATSHEET_DIR:-${USERHOME}/Share/files/cheatsheets}"

args=(
  "$SCRIPT_DIR/lib/fzf_cheatsheets.py"
  --multi
)

has_input=0
for arg in "$@"; do
  case "$arg" in
    -f|--file|-d|--directory|--file=*|--directory=*) has_input=1 ;;
  esac
done
if (( ! has_input )); then
  args+=( -d "$CHEATSHEET_DIR" )
fi

args+=( "$@" )

exec uv run "${args[@]}"
