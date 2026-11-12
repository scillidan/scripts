#!/bin/bash
# Open a translation of the pane you are looking at beside it.
#
#   translate-pane.sh
#
# Bound to Alt-t. Zellij's `Run` starts this in a throwaway pane; we replace that
# pane with the translation, so the screen ends up with two panes only.
#
# Why the pane id is resolved here: once a new pane opens it takes focus, and
# `dump-screen` without `--pane-id` would dump that new pane instead of the one
# the key was pressed in.
#
# No `--direction`: Zellij rejects it together with `--in-place`, and the
# replacement pane lands where the runner already was.

set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# zellij action list-panes prints the focused pane's id in its JSON; grab the
# whole table so the exact field can be inspected when it changes.
table="$(zellij action list-panes -j -s 2>&1 || true)"

focused="$(printf '%s' "${table}" | grep -o '"is_focused"[[:space:]]*:[[:space:]]*true[^}]*' | grep -o '"id"[[:space:]]*:[[:space:]]*"[^"]*"' | cut -d'"' -f4 | head -1)"

# Fallbacks for a table without is_focused: first pane id, or the last one.
if [ -z "${focused}" ]; then
	focused="$(printf '%s' "${table}" | grep -o '"id"[[:space:]]*:[[:space:]]*"[^"]*"' | cut -d'"' -f4 | head -1)"
fi

if [ -z "${focused}" ]; then
	echo "translate-pane: could not read the pane list" >&2
	echo "${table}" | head -20 >&2
	read -r -p "--- enter to close ---" _ || true
	exit 1
fi

exec zellij action new-pane --in-place --close-replaced-pane \
	-- bash "${here}/translate-now.sh" "${focused}"
