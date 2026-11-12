#!/bin/bash
# Open a translation of the pane you are looking at beside it.
#
#   translate-pane.sh [right|down]   default: right
#
# Bound to Alt-t. Zellij's `Run` starts this inside a fresh runner pane, which is
# wasteful: the runner only exists to launch the translation pane. So we replace
# it and hand the source pane id to translate-now.sh, because by the time that
# runs, focus has moved to the new pane and a plain dump would read itself.
#
# `--in-place` cannot be combined with `--direction`; the replacement lands where
# the runner already was, which is where the key was pressed.

set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source_id="$(zellij action list-panes -j 2>/dev/null |
	tr ',' '\n' | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)"

if [ -z "${source_id}" ]; then
	echo "translate-pane: could not find the source pane id" >&2
	read -r -p "--- enter to close ---" _ || true
	exit 1
fi

exec zellij action new-pane --in-place --close-replaced-pane \
	-- bash "${here}/translate-now.sh" "${source_id}"
