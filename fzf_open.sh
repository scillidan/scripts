#!/bin/bash
# Open files with appropriate applications or copy to clipboard for fzf

set -euo pipefail

[[ $# -eq 0 ]] && exit 0

files=("$@")

if [[ ${#files[@]} -gt 1 ]]; then
    if command -v clip.exe &>/dev/null; then
        printf '%s\n' "${files[@]}" | clip.exe
    elif command -v xclip &>/dev/null; then
        printf '%s\n' "${files[@]}" | xclip -selection clipboard
    elif command -v xsel &>/dev/null; then
        printf '%s\n' "${files[@]}" | xsel --clipboard --input
    else
        printf '%s\n' "${files[@]}"
    fi
    exit 0
fi

file="${files[0]}"
ext="${file##*.}"
ext=".${ext}"

clip_to_clipboard() {
    local content="$1"
    if command -v clip.exe &>/dev/null; then
        echo -n "$content" | clip.exe
    elif command -v xclip &>/dev/null; then
        echo -n "$content" | xclip -selection clipboard
    elif command -v xsel &>/dev/null; then
        echo -n "$content" | xsel --clipboard --input
    else
        echo "$content"
    fi
}

open_file() {
    if command -v start &>/dev/null; then
        start "" "$@"
    elif command -v xdg-open &>/dev/null; then
        xdg-open "$@"
    elif command -v open &>/dev/null; then
        open "$@"
    fi
}

case "${ext,,}" in
    .png|.jpg|.jpeg|.bmp|.tiff|.tif|.webp|.ico)
        # open_file "$file"
        clip_to_clipboard "$file"
        ;;
    .svg|.avif)
        qview "$file"
        ;;
    .mp4|.mkv|.webm|.avi|.gif)
        mpvc video "$file"
        ;;
    .mp3|.ogg|.wav|.flac|.m4a|.m4b)
        mpvc music "$file"
        ;;
    .pdf|.epub)
        sioyek --new-window "$file"
        ;;
    .md)
        glow "$file"
        ;;
    .csv)
        tw "$file"
        ;;
    .html)
    	  links "$file"
    	  ;;
    .log)
        tspin "$file"
        ;;
    *)
        clip_to_clipboard "$file"
        ;;
esac

exit 0
