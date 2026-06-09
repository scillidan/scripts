#!/bin/sh

# Generate animated video contact sheets
#
# Usage:
#   Windows:
#     Create a .lnk shortcut to this script in the SendTo folder, then:
#     Select files > Right-click > Send To > vimg_files
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
    if ! vimg vcs -c4 -n16 -H270 --avif-fps=20 "$file"; then
        echo "Error: Failed to process $file"
        error=1
    fi
done

if [ $error -ne 0 ]; then
    echo "Press Enter to exit..."
    read
fi
