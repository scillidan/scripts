#!/bin/sh
# Create an M3U playlist from files
#
# Usage:
#   Windows:
#     Create a .lnk shortcut to this script in the SendTo folder, then:
#     Select files > Right-click > Send To > files_to_m3u
#
#   Linux (Thunar):
#     Edit > Configure custom actions > Add action with command: /path/to/script.sh %F
#
#   Command line:
#     ./script.sh <file1> <file2> ...

if [ $# -eq 0 ]; then
    echo "Error: No files selected"
    echo "Press Enter to exit..."
    read
    exit 1
fi

output="playlist.m3u"

if [ -f "$output" ]; then
    rm "$output"
fi

echo "#EXTM3U" > "$output"

error=0

for file in "$@"; do
    if [ -f "$file" ]; then
        echo "Processing file: $file"
        realpath "$file" >> "$output"
    else
        echo "Error: File does not exist: $file"
        error=1
    fi
done

echo "Done creating playlists."

if [ $error -ne 0 ]; then
    echo "Press Enter to exit..."
    read
fi
