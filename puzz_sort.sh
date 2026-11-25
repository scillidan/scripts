#!/bin/sh
#
# Usage:
#   Windows:
#     Create a .lnk shortcut to this script in the SendTo folder, then:
#     Run it, or drop text on it: the text is chosen in the menu.
#
#   Command line:
#     ./script.sh [1|2|3] [text]     (no text: clipboard; no op: menu)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PY_SCRIPT="$SCRIPT_DIR/lib/puzz_sort.py"

select_op() {
	while :; do
		echo "Sort lines: 1) alphabetical 2) by length 3) reverse"
		printf "Choice [1]: "
		read choice
		case "$choice" in
		2 | length) op=length && return ;;
		3 | reverse) op=reverse && return ;;
		"" | 1 | alphabetical) op=alphabetical && return ;;
		*) echo "Invalid choice" ;;
		esac
	done
}

case "$1" in
1 | alphabetical) op=alphabetical && shift ;;
2 | length) op=length && shift ;;
3 | reverse) op=reverse && shift ;;
-h | --help)
	echo "Usage: $(basename "$0") [1|2|3] [text]"
	exit 0
	;;
*) select_op ;;
esac

if [ $# -gt 0 ]; then
	uv run "$PY_SCRIPT" "$op" "$@"
else
	uv run "$PY_SCRIPT" "$op"
fi
error=$?

if [ $error -ne 0 ]; then
	echo "Error: sort failed"
	echo "Press Enter to exit..."
	read
fi

exit $error
