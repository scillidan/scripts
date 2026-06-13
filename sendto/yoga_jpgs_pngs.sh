#!/bin/sh
# Optimize images using yoga and ImageMagick
#
# Usage:
#   Windows:
#     Create a .lnk shortcut to this script in the SendTo folder, then:
#     Select files > Right-click > Send To > yoga_jpgs_pngs
#
#   Linux (Thunar):
#     Edit > Configure custom actions > Add action with command: /path/to/script.sh %F
#
#   Command line:
#     ./script.sh <img1> <img2> ...

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
    dir=$(dirname "$file")
    base=$(basename "$file")
    name="${base%.*}"
    ext="${base##*.}"

    case "$ext" in
        jpg|JPG|jpeg|JPEG)
            outext=".jpg" ;;
        *)
            outext=".png" ;;
    esac

    output="${dir}/_yoga_${name}${outext}"
    tempfile="${dir}/_temp_${base}"

    if [ "$mode" = "2" ]; then
        height=$(magick identify -format "%h" "$file" 2>/dev/null)
        height=${height:-0}

        if [ "$height" -gt 1080 ]; then
            if ! magick "$file" -resize x1080 "$tempfile" 2>/dev/null; then
                echo "Error: Failed to resize $file"
                error=1
                continue
            fi
            if [ -f "$tempfile" ]; then
                if ! yoga image "$tempfile" "$output" 2>/dev/null; then
                    echo "Error: Failed to optimize $file"
                    error=1
                fi
                rm "$tempfile" 2>/dev/null
            fi
        else
            if ! yoga image "$file" "$output" 2>/dev/null; then
                echo "Error: Failed to optimize $file"
                error=1
            fi
        fi
    else
        if ! yoga image "$file" "$output" 2>/dev/null; then
            echo "Error: Failed to optimize $file"
            error=1
        fi
    fi

    if [ -f "$output" ]; then
        rm "$file" 2>/dev/null
    fi
done

if [ $error -ne 0 ]; then
    echo "Press Enter to exit..."
    read
fi
