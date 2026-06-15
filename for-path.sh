#!/bin/sh
# Execute command on multiple files with path normalization
# Authors: GLM-5🧙‍♂️, scillidan🤡
#
# Usage:
#   for-path.sh <command> [file1] [file2] ...
#
# Examples:
#   for-path.sh "magick convert {} -quality 90 {.}.jpg" img1.png img2.png
#   for-path.sh "die {}" file1.exe file2.exe
#   for-path.sh "vimg vcs -c4 -n16 {}" video.mp4
#
# Placeholders in command:
#   {}  - Full file path
#   {.} - File path without extension
#   {/} - Directory path
#   {n} - Filename only
#   {e} - Extension only

if [ $# -eq 0 ]; then
    echo "Usage: for-path.sh <command> [file1] [file2] ..."
    echo ""
    echo "Placeholders:"
    echo "  {}  - Full file path"
    echo "  {.} - File path without extension"
    echo "  {/} - Directory path"
    echo "  {n} - Filename only"
    echo "  {e} - Extension only"
    exit 1
fi

CMD="$1"
shift

if [ $# -eq 0 ]; then
    set -- "."
fi

resolve_path() {
    local file="$1"
    local dir=$(dirname "$file")
    local base=$(basename "$file")
    local name="${base%.*}"
    local ext="${base##*.}"
    local noext="${file%.*}"

    printf '%s\n' "$CMD" | while IFS= read -r line; do
        line="${line//\{\}/"$file"}"
        line="${line//\{.\}/"$noext"}"
        line="${line//\{\/\}/"$dir"}"
        line="${line//\{n\}/"$name"}"
        line="${line//\{e\}/"$ext"}"
        printf '%s\n' "$line"
    done
}

for file in "$@"; do
    if [ ! -e "$file" ]; then
        echo "Error: File not found: $file"
        continue
    fi

    eval "$(resolve_path "$file")"
done

if [ -t 0 ]; then
    echo "Press Enter to continue..."
    read
fi
