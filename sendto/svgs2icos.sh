#!/bin/sh
# Convert SVG files to multi-size ICO icons
#
# Usage:
#   Windows:
#     Create a .lnk shortcut to this script in the SendTo folder, then:
#     Select files > Right-click > Send To > svgs2icos
#
#   Linux (Thunar):
#     Edit > Configure custom actions > Add action with command: /path/to/svgs2icos.sh %F
#
#   Command line:
#     ./script.sh <file1> <file2> ...
#
# Requires: inkscape, magick (ImageMagick)

if [ $# -eq 0 ]; then
    echo "Error: No files selected"
    echo "Press Enter to exit..."
    read
    exit 1
fi

if ! command -v inkscape >/dev/null 2>&1; then
    echo "Error: inkscape is not installed or not in PATH"
    echo "Press Enter to exit..."
    read
    exit 1
fi

if ! command -v magick >/dev/null 2>&1; then
    echo "Error: magick (ImageMagick) is not installed or not in PATH"
    echo "Press Enter to exit..."
    read
    exit 1
fi

sizes="16 32 48 64 128 256"
error=0

for file in "$@"; do
    if [ ! -f "$file" ]; then
        echo "Error: File not found: $file"
        error=1
        continue
    fi

    dir=$(dirname "$file")
    name=$(basename "$file" .svg)
    tmpdir="$dir/${name}_ico_tmp"

    if [ -d "$tmpdir" ]; then
        echo "Error: Temp directory already exists: $tmpdir"
        error=1
        continue
    fi

    if ! mkdir "$tmpdir"; then
        echo "Error: Failed to create temp directory for $file"
        error=1
        continue
    fi

    pngs=""
    convert_ok=1
    for s in $sizes; do
        png="$tmpdir/${s}.png"
        if ! inkscape "$file" -w "$s" -h "$s" -o "$png" 2>/dev/null; then
            echo "Error: Inkscape failed to export ${s}x${s} PNG for $file"
            convert_ok=0
            break
        fi
        if [ ! -s "$png" ]; then
            echo "Error: Output PNG is empty (${s}x${s}) for $file"
            convert_ok=0
            break
        fi
        pngs="$pngs $png"
    done

    if [ $convert_ok -eq 0 ]; then
        rm -rf "$tmpdir"
        error=1
        continue
    fi

    ico="$dir/${name}.ico"
    if ! magick $pngs "$ico" 2>/dev/null; then
        echo "Error: ImageMagick failed to create ICO for $file"
        rm -rf "$tmpdir"
        error=1
        continue
    fi

    if [ ! -s "$ico" ]; then
        echo "Error: Output ICO is empty for $file"
        rm -f "$ico"
        rm -rf "$tmpdir"
        error=1
        continue
    fi

    rm -rf "$tmpdir"
    echo "OK: $ico"
done

if [ $error -ne 0 ]; then
    echo "Press Enter to exit..."
    read
fi

exit $error
