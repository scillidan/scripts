#!/bin/sh
# Convert m4b audiobooks to mp3 with chapter support
#
# Usage:
#   Windows:
#     Create a .lnk shortcut to this script in the SendTo folder, then:
#     Select files > Right-click > Send To > m4b_to_mp3
#
#   Linux (Thunar):
#     Edit > Configure custom actions > Add action with command: /path/to/script.sh %F
#
#   Command line:
#     ./script.sh <file1.m4b> <file2.m4b> ...

SCRIPT_DIR=$(dirname "$(readlink -f "$0" 2>/dev/null || echo "$0")")
PY_SCRIPT="$SCRIPT_DIR/lib/m4b_to_mp3.py"

if [ $# -eq 0 ]; then
	echo "Error: No files selected"
	echo "Press Enter to exit..."
	read
	exit 1
fi

run_py() {
	if command -v uv >/dev/null 2>&1; then
		uv run "$@"
	else
		python "$@"
	fi
}

error=0

for file in "$@"; do
	if [ ! -f "$file" ]; then
		echo "Error: Not a file: $file"
		error=1
		continue
	fi

	if ! run_py "$PY_SCRIPT" "$file"; then
		echo "Error: Failed to convert $file"
		error=1
	fi
done

if [ $error -ne 0 ]; then
	echo "Press Enter to exit..."
	read
fi

exit $error
