#!/bin/sh
# Scan files and dirs with ClamAV
#
# Usage:
#   Windows:
#     Create a .lnk shortcut to this script in the SendTo folder, then:
#     Select files/folders > Right-click > Send To > clamav_files
#
#   Linux (Thunar):
#     Edit > Configure custom actions > Add action with command: /path/to/script.sh %F
#
#   Command line:
#     ./script.sh <file1> <file2> ... <dir1> <dir2> ...

error=0

for target in "$@"; do
    if [ -d "$target" ]; then
        echo "Scanning folder: $target"
        clamscan -r -i "$target" || error=1
    else
        echo "Scanning file: $target"
        clamscan -v -a --max-filesize=1000M --max-scansize=1000M --alert-exceeds-max=yes "$target" || error=1
    fi
done

if [ $error -ne 0 ]; then
    echo "Error: Scan failed for some files"
    echo "Press Enter to exit..."
    read
fi