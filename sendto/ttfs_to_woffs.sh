#!/bin/sh
# Convert TTF to WOFF and WOFF2 format
#
# Usage:
#   Windows:
#     Create a .lnk shortcut to this script in the SendTo folder, then:
#     Select files > Right-click > Send To > ttfs_to_woffs
#
#   Linux (Thunar):
#     Edit > Configure custom actions > Add action with command: /path/to/script.sh %F
#
#   Command line:
#     ./script.sh <ttf1> <ttf2> ...

error=0

for file in "$@"; do
    if [ -f "$file" ]; then
        woff="${file%.*}.woff"
        woff2="${file%.*}.woff2"

        if ! webify --no-eot --no-svg "$file"; then
            echo "Error: Failed to convert $file to WOFF"
            error=1
            continue
        fi

        if ! cat "$woff" | ttf2woff2 > "$woff2"; then
            echo "Error: Failed to convert $file to WOFF2"
            error=1
        fi
    fi
done

if [ $error -ne 0 ]; then
    echo "Press Enter to exit..."
    read
fi
