#!/usr/bin/env bash
# zellij-shell (Linux + Windows git bash).

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
case "$(uname -s)" in
MINGW* | MSYS* | CYGWIN*) SCRIPT_DIR="$(cygpath -w "$SCRIPT_DIR")" ;;
esac

PY=python3
command -v "$PY" >/dev/null 2>&1 || PY=python

exec "$PY" "$SCRIPT_DIR/lib/zellij_shell.py" "$@"
