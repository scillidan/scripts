#!/bin/sh
# Get SHA256 hash from files and copy to clipboard
#
# Usage:
#   Windows:
#     Create a .lnk shortcut to this script in the SendTo folder, then:
#     Select files > Right-click > Send To > files_copy_sha256
#
#   Linux (Thunar):
#     Edit > Configure custom actions > Add action with command: /path/to/script.sh %F
#
#   Command line:
#     ./script.sh <file1> <file2> ...

error=0

for file in "$@"; do
    if [ -f "$file" ]; then
        hash=$(sha256sum "$file" | awk '{print $1}')
        echo "$hash"
        hashes="${hashes}${hash}"$'\n'
    else
        echo "Error: File not found: $file"
        error=1
    fi
done

if [ -n "$hashes" ]; then
    if command -v clip.exe >/dev/null 2>&1; then
        echo -n "$hashes" | clip.exe
    elif command -v xclip >/dev/null 2>&1; then
        echo -n "$hashes" | xclip -selection clipboard
    elif command -v xsel >/dev/null 2>&1; then
        echo -n "$hashes" | xsel --clipboard --input
    else
        echo "Error: No clipboard utility found"
        error=1
    fi
fi

if [ $error -ne 0 ]; then
    echo "Press Enter to exit..."
    read
fi