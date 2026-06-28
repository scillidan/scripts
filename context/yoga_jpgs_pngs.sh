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

readonly MAX_HEIGHT=1080

delete_source() {
    target="$1"
    if [ ! -e "$target" ]; then
        return 0
    fi
    if command -v gio >/dev/null 2>&1; then
        gio trash "$target" 2>/dev/null
    elif [ "$(uname -s)" = "MINGW"* ] || [ "$(uname -s)" = "MSYS"* ]; then
        powershell -NoProfile -Command "
            \$shell = New-Object -ComObject Shell.Application
            foreach (\$item in \$args) {
                \$fso = Get-Item -LiteralPath \$item
                \$folder = \$shell.NameSpace(\$fso.DirectoryName)
                \$folder.ParseName(\$fso.Name).InvokeVerb('delete')
            }
        " -- "$target" 2>/dev/null
    fi
}

format_size() {
    size=$1
    if [ "$size" -ge 1048576 ]; then
        awk "BEGIN { printf \"%.1f MB\", $size / 1048576 }"
    elif [ "$size" -ge 1024 ]; then
        awk "BEGIN { printf \"%.1f KB\", $size / 1024 }"
    else
        echo "${size} B"
    fi
}

if [ $# -eq 0 ]; then
    echo "Error: No files selected"
    echo "Press Enter to exit..."
    read
    exit 1
fi

echo "1. Just optimize"
echo "2. Resize to ${MAX_HEIGHT}px height if needed"
printf "Select (Default 1): "
read mode
mode=${mode:-1}

error=0
optimized_files=""

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

        if [ "$height" -gt "$MAX_HEIGHT" ]; then
            if ! magick "$file" -resize "x${MAX_HEIGHT}" "$tempfile" 2>/dev/null; then
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
        orig_size=$(stat -c%s "$file" 2>/dev/null || echo 0)
        new_size=$(stat -c%s "$output" 2>/dev/null || echo 0)
        if [ "$orig_size" -gt 0 ]; then
            ratio=$(awk "BEGIN { printf \"%.1f\", $new_size * 100 / $orig_size }")
        else
            ratio="0.0"
        fi
        echo "  $base: $(format_size "$orig_size") -> $(format_size "$new_size") (${ratio}%)"
        optimized_files="$optimized_files \"$file\""
    fi
done

if [ -z "$optimized_files" ]; then
    if [ $error -ne 0 ]; then
        echo "Press Enter to exit..."
        read
    fi
    exit $error
fi

echo ""
echo "Replace source files with optimized versions?"
echo "  (Source files will be moved to recycle bin)"
printf "[y/N]: "
read replace

eval "set -- $optimized_files"
case "$replace" in
    y|Y|yes)
        for file in "$@"; do
            dir=$(dirname "$file")
            base=$(basename "$file")
            name="${base%.*}"
            ext="${base##*.}"
            case "$ext" in
                jpg|JPG|jpeg|JPEG) outext=".jpg" ;;
                *) outext=".png" ;;
            esac
            optimized="${dir}/_yoga_${name}${outext}"
            if [ -f "$optimized" ]; then
                delete_source "$file"
                mv "$optimized" "$file" 2>/dev/null
                echo "  Replaced: $base"
            fi
        done
        echo "Done."
        ;;
    *)
        echo "Skipped."
        ;;
esac

if [ $error -ne 0 ]; then
    echo ""
    echo "Press Enter to exit..."
    read
fi
