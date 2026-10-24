#!/usr/bin/env bash
# Start stable-diffusion-webui (Linux + Windows git bash).

set -e

USERHOME="${USERHOME:-$HOME}"
cd "$USERHOME/Local/OptImg/stable-diffusion-webui" || exit 1

case "$(uname -s)" in
MINGW* | MSYS* | CYGWIN*) exec start webui-user.bat ;;
*) exec ./webui-user.sh ;;
esac
