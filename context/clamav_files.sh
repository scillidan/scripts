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
        if ! clamscan -r -i "$target"; then
            echo "Error: ClamAV scan failed for folder: $target"
            error=1
            continue
        fi
    else
        echo "Scanning file: $target"
        if ! clamscan -v -a --max-filesize=1000M --max-scansize=1000M --alert-exceeds-max=yes "$target"; then
            echo "Error: ClamAV scan failed for file: $target"
            error=1
            continue
        fi
    fi
done

if [ $error -ne 0 ]; then
    echo "Press Enter to exit..."
    read
fi

exit $error