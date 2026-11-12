#!/bin/bash
# Translate the pane you came from, then wait for Enter.
#
#   translate-now.sh [source-pane-id]
#
# Called from translate-pane.sh, which puts this in a new tab. The source id is
# optional here because when this pane is the only one that ever calls
# dump-screen, `--pane-id` can be given as an argument; without it, the pane
# spec is resolved by the caller and this file does not guess.
#
# Keeps the source layout: dump-screen gives plain text with original line breaks
# and columns; only CRLF and trailing spaces are stripped. `--full` is omitted,
# so scrollback stays out.

set -uo pipefail

pane_id="${1:-}"
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
tmp="${TMPDIR:-/tmp}"
dump="${tmp}/zellij-translate-dump.txt"

fail() {
	echo "translate-pane: $*" >&2
	echo "translate-pane: dump kept at ${dump}" >&2
	read -r -p "--- enter to close ---" _ || true
	exit 1
}

[ -n "${pane_id}" ] || fail "source pane id missing"

dump_args=(--path "${dump}" --pane-id "${pane_id}")
zellij action dump-screen "${dump_args[@]}" || fail "dump-screen ${pane_id} failed"

grep -q '[^[:space:]]' "${dump}" 2>/dev/null || fail "pane ${pane_id} is empty"

sed -e 's/\r$//' -e 's/[[:space:]]*$//' "${dump}" >"${dump}.txt"

bash "${here}/../llm-translate.sh" --stdin <"${dump}.txt" ||
	echo "translate-pane: llm-translate failed (is 127.0.0.1:8010 serving?)" >&2

echo
read -r -p "--- enter to close ---" _ || true
