#!/bin/sh
# Convert PDF pages to PNG format
#
# Usage:
#   Windows:
#     Create a .lnk shortcut to this script in the SendTo folder, then:
#     Select files > Right-click > Send To > pdfs_to_pngs
#
#   Linux (Thunar):
#     Edit > Configure custom actions > Add action with command: /path/to/script.sh %F
#
#   Command line:
#     ./script.sh <pdf1> <pdf2> ...

error=0

printf "Enter page number (default=1): "
read page
page=${page:-1}
imgpage=$((page - 1))

for file in "$@"; do
    base="${file%.*}"
    if ! magick -density 300 "${file}[${imgpage}]" -define png:compression-level=9 -alpha remove "${base}_p${page}.png"; then
        echo "Error: Failed to convert $file"
        error=1
    fi
done

if [ $error -ne 0 ]; then
    echo "Press Enter to exit..."
    read
fi
