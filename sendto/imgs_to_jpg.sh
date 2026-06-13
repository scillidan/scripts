#!/bin/sh
# Convert image files to JPEG format, delete original if conversion succeeded
#
# Usage:
#   Windows:
#     Create a .lnk shortcut to this script in the SendTo folder, then:
#     Select files > Right-click > Send To > imgs_to_jpg
#
#   Linux (Thunar):
#     Edit > Configure custom actions > Add action with command: /path/to/script.sh %F
#
#   Command line:
#     ./script.sh <img1> <img2> ...

error=0

for file in "$@"; do
    output="${file%.*}.jpg"
    if ! magick convert "$file" -quality 90 "$output"; then
        echo "Error: Failed to convert $file"
        error=1
        continue
    fi
    if [ -f "$output" ]; then
        rm "$file"
    fi
done

if [ $error -ne 0 ]; then
    echo "Press Enter to exit..."
    read
fi
