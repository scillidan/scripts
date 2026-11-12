#!/bin/bash
# Open a translation of the pane you are looking at beside it.
#
#   translate-pane.sh
#
# Bound to Alt-t. Zellij's `Run` starts this in a throwaway pane; we replace that
# pane with the translation, so only the source and the translation remain.
#
# Diagnostics go to zellij-translate-init.log in TMPDIR because the runner pane
# is replaced and any output printed here would be lost.

set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
log="${TMPDIR:-/tmp}/zellij-translate-init.log"

hold() {
	echo "translate-pane: $*" >&2
	echo "translate-pane: see ${log}" >&2
	read -r -p "--- enter to close ---" _ || true
	exit 1
}

table="$(zellij action list-panes -j -s 2>&1)"
rc=$?

{
	echo "rc=${rc}"
	echo "ZELLIJ=${ZELLIJ:-<unset>}"
	printf '%s\n' "${table}"
} >"${log}"

focused="$(printf '%s' "${table}" | grep -o '"is_focused"[[:space:]]*:[[:space:]]*true[^}]*' |
	grep -o '"id"[[:space:]]*:[[:space:]]*"[^"]*"' | cut -d'"' -f4 | head -1)"

if [ -z "${focused}" ]; then
	# Fall back to the first pane id if the table has no focus marker.
	focused="$(printf '%s' "${table}" | grep -o '"id"[[:space:]]*:[[:space:]]*"[^"]*"' |
		cut -d'"' -f4 | head -1)"
fi

[ -n "${focused}" ] || hold "no pane id in list-panes (rc=${rc})"

exec zellij action new-pane --in-place --close-replaced-pane \
	-- bash "${here}/translate-now.sh" "${focused}"
