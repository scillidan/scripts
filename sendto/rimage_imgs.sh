#!/bin/sh

# Optimize and resize images using Rimage
#
# Usage:
#   Windows:
#     Create a .lnk shortcut to this script in the SendTo folder, then:
#     Select files > Right-click > Send To > rimage_imgs
#
#   Linux (Thunar):
#     Edit > Configure custom actions > Add action with command: /path/to/script.sh %F
#
#   Command line:
#     ./script.sh <img1> <img2> ...

get_encoder() {
    case "$1" in
        .jpg|.JPG|.jpeg|.JPEG) echo "mozjpeg" ;;
        .png|.PNG) echo "oxipng" ;;
        .webp|.WEBP) echo "webp" ;;
        .avif|.AVIF) echo "ravif" ;;
        *) echo "" ;;
    esac
}

if [ $# -eq 0 ]; then
    echo "Error: No files selected"
    echo "Press Enter to exit..."
    read
    exit 1
fi

echo "1. Just optimize"
echo "2. Resize to 1080px height if needed"
printf "Select (Default 1): "
read mode
mode=${mode:-1}

error=0

for file in "$@"; do
    ext=".${file##*.}"
    encoder=$(get_encoder "$ext")

    if [ -n "$encoder" ]; then
        if [ "$mode" = "2" ]; then
            height=$(magick identify -format "%h" "$file" 2>/dev/null)
            height=${height:-0}

            if [ "$height" -gt 1080 ]; then
                if ! rimage --height 1080 "$encoder" "$file"; then
                    echo "Error: Failed to optimize $file"
                    error=1
                fi
            else
                if ! rimage "$encoder" "$file"; then
                    echo "Error: Failed to optimize $file"
                    error=1
                fi
            fi
        else
            if ! rimage "$encoder" "$file"; then
                echo "Error: Failed to optimize $file"
                error=1
            fi
        fi
    else
        echo "Error: Unsupported format for $file"
        error=1
    fi
done

if [ $error -ne 0 ]; then
    echo "Press Enter to exit..."
    read
fi
