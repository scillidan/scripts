#!/bin/sh
# Crop black borders from video files via ffmpeg auto-detection
#
# Usage:
#   Windows:
#     Create a .lnk shortcut to this script in the SendTo folder, then:
#     Select files > Right-click > Send To > vid_crop_border
#
#   Linux (Thunar):
#     Edit > Configure custom actions > Add action with command: /path/to/script.sh %F
#
#   Command line:
#     ./vid_crop_border.sh <vid1> <vid2> ...

if [ $# -eq 0 ]; then
    echo "Error: No files selected"
    echo "Press Enter to exit..."
    read
    exit 1
fi

echo "1. MP4"
echo "2. WebM"
echo "3. Both (MP4 + WebM)"
printf "Select format (Default 1): "
read fmt
case "$fmt" in
    2) formats="webm" ;;
    3) formats="mp4 webm" ;;
    *) formats="mp4" ;;
esac

echo "1. Strict (pure black only)"
echo "2. Normal (recommended)"
echo "3. Loose (near-black backgrounds)"
printf "Select sensitivity (Default 2): "
read sens
case "$sens" in
    1) limit=24 ;;
    3) limit=60 ;;
    *) limit=40 ;;
esac

echo "1. Lossless (crf 0)"
echo "2. Visually lossless (crf 4, recommended)"
echo "3. High quality (crf 8)"
printf "Select quality (Default 2): "
read mode
case "$mode" in
    1) crf=0 ;;
    3) crf=8 ;;
    *) crf=4 ;;
esac

error=0

for file in "$@"; do
    dir=$(dirname "$file")
    name=$(basename "$file" | sed 's/\.[^.]*$//')

    printf "\n--- %s ---\n" "$file"

    echo "Detecting black borders..."

    crop=$(ffmpeg -t 30 -i "$file" -vf cropdetect=limit=$limit:round=2 -f null - 2>&1 \
        | grep -o 'crop=[0-9:]*' | tail -1 | cut -d= -f2)

    if [ -z "$crop" ]; then
        echo "Error: Could not detect crop values"
        error=1
        continue
    fi

    crop_w=${crop%%:*}
    crop_h=${crop#*:}; crop_h=${crop_h%%:*}

    original_size=$(ffprobe -v error -select_streams v:0 \
        -show_entries stream=width,height -of csv=s=x:p=0 "$file")

    if [ "${crop_w}x${crop_h}" = "$original_size" ]; then
        echo "No black borders detected ($original_size). Skipped."
        continue
    fi

    printf "Crop: %s -> %sx%s\n" "$original_size" "$crop_w" "$crop_h"

    for fmt in $formats; do
        ext="$fmt"
        output="$dir/${name}_crop.$ext"
        temp="$dir/${name}_crop_tmp.$ext"

        has_audio=$(ffprobe -v error -select_streams a:0 -show_entries stream=codec_type -of csv=s=x:p=0 "$file" 2>/dev/null | head -1)
        if [ -n "$has_audio" ] && [ "$has_audio" = "audio" ]; then
            if [ "$fmt" = "mp4" ]; then
                audio_opts="-c:a copy"
            else
                audio_codec=$(ffprobe -v error -select_streams a:0 -show_entries stream=codec_name -of csv=s=x:p=0 "$file" 2>/dev/null | head -1)
                case "$audio_codec" in
                    opus|vorbis) audio_opts="-c:a copy" ;;
                    *) audio_opts="-c:a libopus -ar 48000 -b:a 96k" ;;
                esac
            fi
        else
            audio_opts="-an"
        fi

        if [ "$fmt" = "mp4" ]; then
            vcodec="libx264"
            actual_crf="$crf"
            extra="-movflags +faststart"
        else
            vcodec="libvpx-vp9"
            actual_crf=20
            extra="-b:v 0 -row-mt 1"
        fi

        log=$(mktemp)
        if ! ffmpeg -y -i "$file" -vf "crop=$crop" \
             -c:v "$vcodec" -crf "$actual_crf" -preset slow \
             $audio_opts \
             $extra \
             "$temp" >"$log" 2>&1; then
            echo "Error: FFmpeg failed for $file ($fmt)"
            tail -5 "$log"
            rm -f "$temp" "$log"
            error=1
            continue
        fi
        rm -f "$log"

        if [ ! -s "$temp" ]; then
            echo "Error: Output file is empty ($fmt)"
            rm -f "$temp"
            error=1
            continue
        fi

        mv "$temp" "$output"
        echo "Done: $output"
    done
done

if [ $error -ne 0 ]; then
    echo "Press Enter to exit..."
    read
else
    printf "\nAll done. "
    read -t 3 -p "Closing in 3s..." 2>/dev/null || echo ""
fi

exit $error
