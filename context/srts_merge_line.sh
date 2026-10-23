#!/bin/sh
# Convert multi-line subtitle content to single line
#
# Usage:
#   Windows:
#     Create a .lnk shortcut to this script in the SendTo folder, then:
#     Select files/folders > Right-click > Send To > srts_merge_lines
#
#   Linux (Thunar):
#     Edit > Configure custom actions > Add action with command: /path/to/script.sh %F
#
#   Command line:
#     ./script.sh <srt1> <srt2> ... <dir1> <dir2> ...

SCRIPT_DIR=$(dirname "$(readlink -f "$0" 2>/dev/null || echo "$0")")
PY_SCRIPT="$SCRIPT_DIR/lib/srts_merge_line.py"

if [ $# -eq 0 ]; then
	echo "Error: No files or folders selected"
	echo "Press Enter to exit..."
	read
	exit 1
fi

error=0

process_file() {
	file="$1"
	if ! python "$PY_SCRIPT" "$file"; then
		echo "Error: Failed to process $file"
		error=1
	fi
}

for arg in "$@"; do
	if [ -d "$arg" ]; then
		for file in "$arg"/*.srt; do
			if [ -f "$file" ]; then
				process_file "$file"
			fi
		done
	elif [ -f "$arg" ]; then
		process_file "$arg"
	else
		echo "Error: Not found: $arg"
		error=1
	fi
done

if [ $error -ne 0 ]; then
	echo "Press Enter to exit..."
	read
fi
