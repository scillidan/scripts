#!/bin/sh

# Convert LRC files to SRT format
#
# Usage:
#   Windows:
#     Create a .lnk shortcut to this script in the SendTo folder, then:
#     Select files > Right-click > Send To > lrcs_to_srts
#
#   Linux (Thunar):
#     Edit > Configure custom actions > Add action with command: /path/to/script.sh %F
#
#   Command line:
#     ./script.sh <lrc1> <lrc2> ...

SCRIPT_DIR=$(dirname "$(readlink -f "$0" 2>/dev/null || echo "$0")")
PY_SCRIPT="$SCRIPT_DIR/lib/lrc_to_srt.py"

error=0

python "$SCRIPT"

for file in "$@"; do
    output="${file%.*}.srt"
    if ! python "$PY_SCRIPT" "$file" "$output"; then
        echo "Error: Failed to convert $file"
        error=1
    fi
done

if [ $error -ne 0 ]; then
    echo "Press Enter to exit..."
    read
fi
