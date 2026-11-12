#!/bin/bash
# Print a translation of this pane's neighbour, then wait for Enter.
#
#   translate-now.sh [source-pane-id]
#
# Phase 3 of the Alt-t flow: translate-pane.sh opened this pane with --in-place
# and --close-replaced-pane, so the runner pane is gone and only this one and the
# source remain. With two panes, "the neighbour" is the only other terminal pane.
#
# Keeping the result on screen (read) instead of exec'ing a shell means the pane
# can be closed with Enter and never leaves a prompt behind.

set -euo pipefail

pane_id="${1:-}"
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
work="${TMPDIR:-/tmp}/zellij-translate-$$"
mkdir -p "$work"
trap 'rm -rf "$work"' EXIT

dump_args=(--full --path "$work/pane.txt")
[ -n "${pane_id}" ] && dump_args+=(--pane-id "${pane_id}")

if ! zellij action dump-screen "${dump_args[@]}"; then
	echo "translate-pane: dump-screen failed" >&2
	read -r -p "enter to close" _ || true
	exit 1
fi

sed -e 's/\r$//' "$work/pane.txt" |
	awk 'BEGIN { blank = 0 } /^[[:space:]]*$/ { blank++; next } { if (blank > 0) print ""; blank = 0; print }' |
	tail -n 60 >"$work/text.txt"

if ! grep -q '[^[:space:]]' "$work/text.txt"; then
	echo "translate-pane: the neighbour pane has no text" >&2
	cp "$work/pane.txt" "${TMPDIR:-/tmp}/zellij-translate-last.txt"
	echo "translate-pane: dump kept at ${TMPDIR:-/tmp}/zellij-translate-last.txt" >&2
	read -r -p "enter to close" _ || true
	exit 1
fi

if ! bash "${here}/../llm-translate.sh" --stdin <"$work/text.txt"; then
	echo "translate-pane: llm-translate failed (is 127.0.0.1:8010 serving?)" >&2
fi

echo
read -r -p "--- enter to close ---" _ || true
