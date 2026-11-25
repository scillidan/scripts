#!/usr/bin/env bash
set -euo pipefail

# Force UTF-8 for stdin/stdout pipes; otherwise Windows CP936 breaks on "ö" etc.
export PYTHONUTF8=1

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOKMARK_DIR="${BOOKMARK_DIR:-${USERHOME}/Share/files/bookmarks}"
OPENER="${BROWSER:-${BROSER:-}}"

args=(
  "$SCRIPT_DIR/lib/fzf_bookmarks.py"
  --multi
)

# Only supply the default -d when the caller did not specify their own inputs.
has_input=0
for arg in "$@"; do
  case "$arg" in
    -f|--file|-d|--directory|--file=*|--directory=*) has_input=1 ;;
  esac
done
if (( ! has_input )); then
  args+=( -d "$BOOKMARK_DIR" )
fi

[[ -n "$OPENER" ]] && args+=( --opener "$OPENER" )

# Forward every user argument; placed last so an explicit --opener/-d can override.
args+=( "$@" )

exec uv run "${args[@]}"
