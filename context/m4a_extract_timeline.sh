#!/bin/sh
# Extract chapter timeline from m4a/m4b audio files
#
# Usage:
#   Windows:
#     Create a .lnk shortcut to this script in the SendTo folder, then:
#     Select files > Right-click > Send To > m4a_extract_timeline
#
#   Linux (Thunar):
#     Edit > Configure custom actions > Add action with command: /path/to/script.sh %F
#
#   Command line:
#     ./script.sh <file1> <file2> ...

SCRIPT_DIR=$(dirname "$(readlink -f "$0" 2>/dev/null || echo "$0")")
PY_SCRIPT="$SCRIPT_DIR/lib/m4a_extract_timeline.py"

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
		echo "Error: Failed to extract timeline from $file"
		error=1
	fi
done

if [ $error -ne 0 ]; then
	echo "Press Enter to exit..."
	read
fi

exit $error
