#!/bin/bash
# Print a translation of the pane you came from, then wait for Enter.
#
#   translate-now.sh <source-pane-id>
#
# The id comes from translate-pane.sh, which lists panes before replacing its
# runner. Without it, focus is on this pane and dump-screen would read itself.

set -euo pipefail

pane_id="${1:-}"
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
work="${TMPDIR:-/tmp}/zellij-translate-$$"
mkdir -p "$work"
trap 'rm -rf "$work"' EXIT

fail() {
	echo "translate-pane: $*" >&2
	read -r -p "--- enter to close ---" _ || true
	exit 1
}

dump_args=(--full --path "$work/pane.txt")
[ -n "${pane_id}" ] && dump_args+=(--pane-id "${pane_id}")
zellij action dump-screen "${dump_args[@]}" || fail "dump-screen failed"

sed -e 's/\r$//' "$work/pane.txt" |
	awk 'BEGIN { blank = 0 } /^[[:space:]]*$/ { blank++; next } { if (blank > 0) print ""; blank = 0; print }' |
	tail -n 60 >"$work/text.txt"

if ! grep -q '[^[:space:]]' "$work/text.txt"; then
	cp "$work/pane.txt" "${TMPDIR:-/tmp}/zellij-translate-last.txt"
	fail "pane ${pane_id:-<focused>} has no text (dump kept at ${TMPDIR:-/tmp}/zellij-translate-last.txt)"
fi

if ! bash "${here}/../llm-translate.sh" --stdin <"$work/text.txt"; then
	echo
	echo "translate-pane: llm-translate failed (is 127.0.0.1:8010 serving?)" >&2
fi

echo
read -r -p "--- enter to close ---" _ || true
