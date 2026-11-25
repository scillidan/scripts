#!/bin/sh
#
# Usage:
#   ./script.sh [op] [text]     (no text: clipboard; no op: menu)
#
# op: alphabetical, length, reverse
# Runs on Linux and on Windows via git bash. The result is printed and also
# copied to the clipboard when one is available.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PY_SCRIPT="$SCRIPT_DIR/lib/puzz_sort.py"

OPS='
alphabetical:sort lines alphabetically
length:sort lines by length
reverse:reverse line order
'

is_op() { # 1: name -> succeeds if it is a known op
	printf '%s\n' "$OPS" | cut -d: -f1 | grep -qx -- "$1"
}

select_op() {
	while :; do
		echo "Sort lines:"
		printf '%s\n' "$OPS" | while IFS=: read -r name desc; do
			[ -n "$name" ] && printf '  %-16s %s\n' "$name" "$desc"
		done
		printf "Choice: "
		read -r choice
		is_op "$choice" && op=$choice && return
		echo "Invalid choice"
	done
}

case "$1" in
-h | --help)
	echo "Usage: $(basename "$0") [alphabetical|length|reverse] [text]"
	exit 0
	;;
*)
	if is_op "$1"; then
		op=$1
		shift
	else
		select_op
	fi
	;;
esac

uv run "$PY_SCRIPT" "$op" "$@"
error=$?

if [ $error -ne 0 ]; then
	echo "Error: sort failed"
	echo "Press Enter to exit..."
	read -r
fi

exit $error
