#!/bin/bash
# Translate clipboard text via llm-translate.sh (Linux + Windows git bash).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

case "$(uname -s)" in
MINGW* | MSYS* | CYGWIN*)
	clip() {
		if command -v pwsh >/dev/null 2>&1; then
			pwsh -c "Get-Clipboard"
		else
			powershell.exe -command "Get-Clipboard"
		fi
	}
	;;
*)
	if command -v xclip >/dev/null 2>&1; then
		clip() { xclip -selection clipboard -o; }
	else
		clip() { xsel --clipboard --output; }
	fi
	;;
esac

clip | bash "$SCRIPT_DIR/llm-translate.sh" --stdin
