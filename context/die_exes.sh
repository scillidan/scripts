#!/bin/sh
# Open files with Detect It Easy (DiE)
#
# Usage:
#   Windows:
#     Create a .lnk shortcut to this script in the SendTo folder, then:
#     Select files > Right-click > Send To > die_exes
#
#   Linux (Thunar):
#     Edit > Configure custom actions > Add action with command: /path/to/script.sh %F
#
#   Command line:
#     ./script.sh <file1> <file2> ...

error=0

for file in "$@"; do
    if ! die "$file"; then
        echo "Error: Failed to open $file"
        error=1
    fi
done

if [ $error -ne 0 ]; then
    echo "Press Enter to exit..."
    read
fi