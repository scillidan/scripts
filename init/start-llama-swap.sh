#!/usr/bin/env bash
# Start llama-swap (Linux + Windows git bash).  Foreground; the old .vbs
# hidden-window launcher has no bash equivalent.

set -e

USERHOME="${USERHOME:-$HOME}"
CONFIG="$USERHOME/Share/dotfiles/.config/llama-swap/config.yaml"

case "$(uname -s)" in
MINGW* | MSYS* | CYGWIN*) CONFIG="$(cygpath -w "$CONFIG")" ;;
esac

exec llama-swap -config "$CONFIG" -listen 127.0.0.1:8010
