#!/bin/sh

# Convert PNG/BMP/GIF/JPG/SVG files to multi-resolution ICO format
#
# Usage:
#   Windows:
#     Create a .lnk shortcut to this script in the SendTo folder, then:
#     Select files > Right-click > Send To > pngs_to_icos
#
#   Linux (Thunar):
#     Edit > Configure custom actions > Add action with command: /path/to/script.sh %F
#
#   Command line:
#     ./script.sh <file1> <file2> ...

error=0

for file in "$@"; do
    output="${file%.*}.ico"
    if ! magick -quiet "$file" -alpha on -background transparent -resize 256x256 -gravity center -extent 256x256 -filter Lanczos -strip -define icon:auto-resize=256,128,96,64,48,32,24,16 "$output"; then
        echo "Error: Failed to convert $file"
        error=1
    fi
done

if [ $error -ne 0 ]; then
    echo "Press Enter to exit..."
    read
fi
