#!/bin/sh
# Extract embedded subtitles from video files using ffmpeg
# Supports SRT, ASS, and SUP (PGS) subtitle formats extracted with stream copy
#
# Reference: https://github.com/kelciour/mpv-scripts/blob/master/sub-export.lua
#
# Usage:
#   Windows:
#     Create a .lnk shortcut to this script in the SendTo folder, then:
#     Select files > Right-click > Send To > ffmpeg_extract_subs
#
#   Linux (Thunar):
#     Edit > Configure custom actions > Add action with command: /path/to/script.sh %F
#
#   Command line:
#     ./script.sh <vid1> <vid2> ...

if [ $# -eq 0 ]; then
    echo "Error: No files selected"
    echo "Press Enter to exit..."
    read
    exit 1
fi

if ! command -v ffprobe >/dev/null 2>&1; then
    echo "Error: ffprobe not found (install ffmpeg)"
    echo "Press Enter to exit..."
    read
    exit 1
fi

if ! command -v ffmpeg >/dev/null 2>&1; then
    echo "Error: ffmpeg not found"
    echo "Press Enter to exit..."
    read
    exit 1
fi

select_sub_index() {
    file="$1"

    tmp_subs=$(mktemp)

    ffprobe -v error -select_streams s \
        -show_entries "stream=index,codec_name:stream_tags=language,title" \
        -of csv=p=0 "$file" 2>/dev/null >"$tmp_subs"

    if [ ! -s "$tmp_subs" ]; then
        rm -f "$tmp_subs"
        echo "No embedded subtitle tracks found in $file"
        return 1
    fi

    echo ""
    echo "Subtitle tracks in $(basename "$file"):"
    echo "----------------------------------------"

    num=1
    while IFS= read -r row; do
        idx=$(echo "$row" | cut -d, -f1)
        codec=$(echo "$row" | cut -d, -f2)
        lang=$(echo "$row" | cut -d, -f3)
        title=$(echo "$row" | cut -d, -f4-)

        if [ -z "$idx" ] || [ -z "$codec" ]; then
            continue
        fi

        desc="$idx: $codec"
        if [ -n "$lang" ]; then
            desc="$desc [$lang]"
        fi
        if [ -n "$title" ]; then
            desc="$desc - $title"
        fi
        printf "%3d) %s\n" "$num" "$desc"
        num=$((num + 1))
    done <"$tmp_subs"

    SUBS=$(cat "$tmp_subs")
    rm -f "$tmp_subs"

    if [ -z "$SUBS" ]; then
        echo "No embedded subtitle tracks found in $file"
        return 1
    fi

    total=$(printf '%s\n' "$SUBS" | wc -l)
    echo ""
    echo "  a) Extract all subtitle tracks"
    printf "Enter number or a (Default 1): "
    read choice
    choice=${choice:-1}

    SELECTED_INDEX="$choice"
    SELECTED_TOTAL="$total"
    return 0
}

get_codec_ext() {
    codec="$1"
    case "$codec" in
        *ass*) echo ".ass" ;;
        *pgs*) echo ".sup" ;;
        *)     echo ".srt" ;;
    esac
}

error=0

for file in "$@"; do
    printf "\n=== %s ===\n" "$(basename "$file")"

    if ! select_sub_index "$file"; then
        error=1
        continue
    fi

    dir=$(dirname "$file")
    name=$(basename "$file" | sed 's/\.[^.]*$//')

    if [ "$SELECTED_INDEX" = "a" ]; then
        echo "$SUBS" | while IFS=, read -r idx codec lang title; do
            suffix=""
            if [ -n "$title" ]; then
                suffix=".${title}"
            fi
            if [ -n "$lang" ]; then
                suffix="${suffix}.${lang}"
            fi

            ext=$(get_codec_ext "$codec")
            output="$dir/${name}${suffix}${ext}"

            printf "Extracting stream %s (%s) -> %s\n" "$idx" "$codec" "$(basename "$output")"

            log=$(mktemp)
            if ! ffmpeg -y -hide_banner -loglevel error -i "$file" \
                 -map "0:$idx" -vn -an -c:s copy "$output" >"$log" 2>&1; then
                echo "Error: FFmpeg failed for stream $idx"
                tail -3 "$log"
                rm -f "$log"
                touch "$dir/.extract_subs_error"
                continue
            fi
            rm -f "$log"

            echo "Done: $(basename "$output")"
        done
        if [ -f "$dir/.extract_subs_error" ]; then
            rm -f "$dir/.extract_subs_error"
            error=1
        fi
    else
        row=$(printf '%s\n' "$SUBS" | sed -n "${SELECTED_INDEX}p")
        idx=$(echo "$row" | cut -d, -f1)
        codec=$(echo "$row" | cut -d, -f2)
        lang=$(echo "$row" | cut -d, -f3)
        title=$(echo "$row" | cut -d, -f4-)

        if [ -z "$idx" ]; then
            echo "Error: Invalid selection"
            error=1
            continue
        fi

        suffix=""
        if [ -n "$title" ]; then
            suffix=".${title}"
        fi
        if [ -n "$lang" ]; then
            suffix="${suffix}.${lang}"
        fi

        ext=$(get_codec_ext "$codec")
        output="$dir/${name}${suffix}${ext}"

        printf "Extracting stream %s (%s) -> %s\n" "$idx" "$codec" "$(basename "$output")"

        log=$(mktemp)
        if ! ffmpeg -y -hide_banner -loglevel error -i "$file" \
             -map "0:$idx" -vn -an -c:s copy "$output" >"$log" 2>&1; then
            echo "Error: FFmpeg failed for stream $idx"
            tail -3 "$log"
            rm -f "$log"
            error=1
            continue
        fi
        rm -f "$log"

        echo "Done: $(basename "$output")"
    fi
done

if [ $error -ne 0 ]; then
    echo ""
    echo "Press Enter to exit..."
    read
else
    printf "\nAll done. "
    read -t 3 -p "Closing in 3s..." 2>/dev/null || echo ""
fi

exit $error
