#!/bin/sh

# Convert multi-line subtitle content to single line
#
# Usage:
#   Windows:
#     Create a .lnk shortcut to this script in the SendTo folder, then:
#     Select files > Right-click > Send To > srts_merge_lines
#
#   Linux (Thunar):
#     Edit > Configure custom actions > Add action with command: /path/to/script.sh %F
#
#   Command line:
#     ./script.sh <srt1> <srt2> ...

SCRIPT_DIR=$(dirname "$(readlink -f "$0" 2>/dev/null || echo "$0")")
PY_SCRIPT="$SCRIPT_DIR/lib/srt_merge_lines.py"

if [ $# -eq 0 ]; then
    echo "Error: No files selected"
    echo "Press Enter to exit..."
    read
    exit 1
fi

error=0

for file in "$@"; do
    if ! python "$PY_SCRIPT" "$file"; then
        echo "Error: Failed to process $file"
        error=1
    fi
done

if [ $error -ne 0 ]; then
    echo "Press Enter to exit..."
    read
fi
