#!/bin/bash

set -euo pipefail

[[ $# -eq 0 ]] && exit 0

file="$1"
ext="${file##*.}"
ext=".${ext}"
tmp_img="/tmp/_fzf_preview_$$"
chafa="chafa -f symbols --animate=off --clear --size x25"
img_preview=$chafa


preview_image() {
    $img_preview "$file"
}

preview_media() {
    ffmpeg -i "$file" -vframes 1 -q:v 2 -y "${tmp_img}.jpg" 2>/dev/null
    $img_preview "${tmp_img}.jpg"
    rm -f "${tmp_img}.jpg"
    mediainfo "$file" 2>/dev/null
}

preview_pdf() {
    pdftoppm -jpeg -singlefile -scale-to 400 "$file" "$tmp_img" 2>/dev/null
    $img_preview "${tmp_img}.jpg"
    rm -f "${tmp_img}.jpg"
}

preview_epub() {
    epub-thumbnailer "$file" "${tmp_img}.png" 400 2>/dev/null
    $img_preview "${tmp_img}.png"
    rm -f "${tmp_img}.png"
}

preview_md() {
    CLICOLOR_FORCE=1 glow --style dark "$file" 2>/dev/null || cat "$file"
}

preview_csv() {
    xan view "$file" 2>/dev/null || cat "$file"
}

preview_log() {
    tspin -p "$file" 2>/dev/null || cat "$file"
}

preview_text() {
    bat --color=always --style=numbers,changes --line-range=:500 "$file" 2>/dev/null || cat "$file"
}

case "${ext,,}" in
    .png|.jpg|.jpeg|.gif|.bmp|.tiff|.tif|.webp|.svg|.ico)
        preview_image
        ;;
    .mp4|.mkv|.avi|.mp3|.ogg|.flac|.wav)
        preview_media
        ;;
    .pdf)
        preview_pdf
        ;;
    .epub)
        preview_epub
        ;;
    .md)
        preview_md
        ;;
    .csv)
        preview_csv
        ;;
    .log)
        preview_log
        ;;
    *)
        preview_text
        ;;
esac

exit 0
