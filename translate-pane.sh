#!/bin/bash
# Translate a Zellij pane into a new pane next to it.
#
#   translate-pane [right|down] [pane-id]
#
#   right    new pane to the right (default), original stays on the left
#   down     new pane below
#   pane-id  terminal_<n> of the pane to translate; defaults to the focused pane
#
# Reads the pane with `zellij action dump-screen --full`, drops blank runs, and
# pipes the tail through llm-translate.sh --stdin. Line structure is kept so the
# two panes can be read side by side.

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

if [ -n "${pane_id}" ]; then
	zellij action dump-screen --full --pane-id "${pane_id}" --path "$work/pane.txt"
else
	zellij action dump-screen --full --path "$work/pane.txt"
fi

# Keep the reading order: drop runs of blank lines, keep the last 60 lines.
sed -e 's/\r$//' "$work/pane.txt" |
	awk 'BEGIN { blank = 0 } /^[[:space:]]*$/ { blank++; next } { if (blank > 0) print ""; blank = 0; print }' |
	tail -n 60 >"$work/text.txt"

if ! grep -q '[^[:space:]]' "$work/text.txt"; then
	echo "translate-pane: the pane has no text" >&2
	exit 1
fi

# The result replaces this pane's content, so the caller sees two panes: source
# and translation.
bash "$script_dir/llm-translate.sh" --stdin <"$work/text.txt"
exec "${SHELL:-bash}"
