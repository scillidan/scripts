#!/bin/sh
# Generate thumbnails (screenshots) from video files
#
# Usage:
#   Windows:
#     Create a .lnk shortcut to this script in the SendTo folder, then:
#     Select files > Right-click > Send To > mtn_vids
#
#   Linux (Thunar):
#     Edit > Configure custom actions > Add action with command: /path/to/script.sh %F
#
#   Command line:
#     ./script.sh <vid1> <vid2> ...

if [ $# -eq 0 ]; then
    echo "Error: No files selected"
    echo "Press Enter to exit..."
    read
    exit 1
fi

error=0

for file in "$@"; do
    if ! mtn -c 4 -r 4 -w 1920 -g 8 -k ffffff -b 0.80 -D 12 -i -t -j 90 -o _thumb.jpg -Z -P "$file"; then
        echo "Error: Failed to generate thumbnails for $file"
        error=1
    fi
done

if [ $error -ne 0 ]; then
    echo "Press Enter to exit..."
    read
fi
