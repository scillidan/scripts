#!/bin/sh
# Convert SRT files to VTT format
#
# Usage:
#   Windows:
#     Create a .lnk shortcut to this script in the SendTo folder, then:
#     Select files > Right-click > Send To > srts_to_vtts
#
#   Linux (Thunar):
#     Edit > Configure custom actions > Add action with command: /path/to/script.sh %F
#
#   Command line:
#     ./script.sh <srt1> <srt2> ...

SCRIPT_DIR=$(dirname "$(readlink -f "$0" 2>/dev/null || echo "$0")")
PY_SCRIPT="$$SCRIPT_DIR/lib/srt_to_vtt.py"

error=0

python "$SCRIPT"

for file in "$@"; do
    output="${file%.*}.vtt"
    if ! python "$SCRIPT" -i "$file" -o "$output"; then
        echo "Error: Failed to convert $file"
        error=1
    fi
done

if [ $error -ne 0 ]; then
    echo "Press Enter to exit..."
    read
fi
