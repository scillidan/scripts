#!/bin/sh
#
# Usage:
#   ./script.sh [option] [text]     (no text: clipboard; no option: menu)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PY_SCRIPT="$SCRIPT_DIR/lib/puzz_sort.py"

SORTS='
alphabetical:sort lines alphabetically
length:sort lines by length
reverse:reverse line order
'

is_op() { # 1: option -> succeeds if it is a known op
	printf '%s\n' "$SORTS" | cut -d: -f1 | grep -qx -- "$1"
}

select_op() {
	while :; do
		echo "Sort lines:"
		printf '%s\n' "$SORTS" | while IFS=: read -r option desc; do
			[ -n "$option" ] && printf '  %-16s %s\n' "$option" "$desc"
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
