#!/bin/bash
# Translate a Zellij pane into a pane next to it.
#
#   translate-pane [right|down] [pane-id]
#
#   right    new pane on the right (default)
#   down     new pane below
#   pane-id  terminal_<n> of the pane to translate; defaults to the focused pane
#
# Reads the pane with `zellij action dump-screen --full --path`, collapses blank
# runs, and pipes the tail through llm-translate.sh --stdin. Line structure is
# kept so the translation can be compared with the source side by side.

set -euo pipefail

direction="${1:-right}"
pane_id="${2:-}"
case "${direction}" in
right | down) ;;
*)
	echo "usage: translate-pane [right|down] [pane-id]" >&2
	exit 2
	;;
esac

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
work="${TMPDIR:-/tmp}/zellij-translate-$$"
mkdir -p "$work"
trap 'rm -rf "$work"' EXIT

dump_args=(--full)
[ -n "${pane_id}" ] && dump_args+=(--pane-id "${pane_id}")
if ! zellij action dump-screen "${dump_args[@]}" --path "$work/pane.txt"; then
	echo "translate-pane: dump-screen failed" >&2
	exit 1
fi

# Drop runs of blank lines; keep the last 60 lines of real content.
sed -e 's/\r$//' "$work/pane.txt" |
	awk 'BEGIN { blank = 0 } /^[[:space:]]*$/ { blank++; next } { if (blank > 0) print ""; blank = 0; print }' |
	tail -n 60 >"$work/text.txt"

if ! grep -q '[^[:space:]]' "$work/text.txt"; then
	echo "translate-pane: pane ${pane_id:-<focused>} has no text" >&2
	echo "translate-pane: dump written to ${work}/pane.txt" >&2
	exit 1
fi

if ! bash "$script_dir/llm-translate.sh" --stdin <"$work/text.txt"; then
	echo "translate-pane: llm-translate failed (is 127.0.0.1:8010 serving?)" >&2
fi

# Leave the result on screen under a shell that can scroll it. bash --norc keeps
# .bashrc's `bind` calls from printing "line editing not enabled" over the text.
exec "${SHELL:-bash}" --norc --noprofile
