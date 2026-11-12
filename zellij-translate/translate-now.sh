#!/bin/bash
# Print a translation of the pane you came from, then wait for Enter.
#
#   translate-now.sh <source-pane-id>
#
# Keeps the source layout: dump-screen yields plain text with original line
# breaks and columns, only CRLF and trailing spaces are stripped before the LLM
# sees it. Viewport only (no --full), so scrollback is left out.

set -uo pipefail

pane_id="${1:-}"
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
tmp="${TMPDIR:-/tmp}"
dump="${tmp}/zellij-translate-dump.txt"
log="${tmp}/zellij-translate-init.log"

fail() {
	echo "translate-pane: $*" >&2
	echo "translate-pane: init log ${log}" >&2
	read -r -p "--- enter to close ---" _ || true
	exit 1
}

[ -n "${pane_id}" ] || fail "source pane id missing"

zellij action dump-screen --pane-id "${pane_id}" --path "${dump}" ||
	fail "dump-screen --pane-id ${pane_id} failed"

grep -q '[^[:space:]]' "${dump}" 2>/dev/null ||
	fail "pane ${pane_id} is empty (dump at ${dump})"

sed -e 's/\r$//' -e 's/[[:space:]]*$//' "${dump}" >"${dump}.txt"

bash "${here}/../llm-translate.sh" --stdin <"${dump}.txt" ||
	echo "translate-pane: llm-translate failed (is 127.0.0.1:8010 serving?)" >&2

echo
read -r -p "--- enter to close ---" _ || true
