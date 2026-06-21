#!/bin/sh
# Crop black borders from image files via ImageMagick trim
#
# Usage:
#   Windows:
#     Create a .lnk shortcut to this script in the SendTo folder, then:
#     Select files > Right-click > Send To > imgs_crop_black_border
#
#   Linux (Thunar):
#     Edit > Configure custom actions > Add action with command: /path/to/script.sh %F
#
#   Command line:
#     ./imgs_crop_black_border.sh <img1> <img2> ...

if [ $# -eq 0 ]; then
    echo "Error: No files selected"
    echo "Press Enter to exit..."
    read
    exit 1
fi

error=0

for file in "$@"; do
    dir=$(dirname "$file")
    name=$(basename "$file" | sed 's/\.[^.]*$//')
    output="$dir/${name}_crop.png"

    if ! magick "$file" -fuzz 5% -trim +repage "$output"; then
        echo "Error: Failed to crop $file"
        error=1
    fi
done

if [ $error -ne 0 ]; then
    echo "Press Enter to exit..."
    read
else
    printf "\nAll done. "
    read -t 3 -p "Closing in 3s..." 2>/dev/null || echo ""
fi

exit $error
