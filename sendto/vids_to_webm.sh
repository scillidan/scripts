#!/bin/sh
# Convert MP4/MKV to WebM with resolution downscale and audio normalization
#
# Usage:
#   Windows:
#     Create a .lnk shortcut to this script in the SendTo folder, then:
#     Select files > Right-click > Send To > vids_to_webm
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

echo "1. Keep original (default)"
echo "2. 1080p (max height 1080)"
echo "3. 720p (max height 720)"
printf "Select resolution (Default 1): "
read res
case "$res" in
    2) scale="-vf scale=-2:1080" ;;
    3) scale="-vf scale=-2:720" ;;
    *) scale="" ;;
esac

error=0

for file in "$@"; do
    dir=$(dirname "$file")
    name=$(basename "$file" | sed 's/\.[^.]*$//')
    output="$dir/${name}_webm.webm"
    temp="$dir/${name}_webm_tmp.webm"

    printf "\n--- %s ---\n" "$file"

    has_audio=$(ffprobe -v error -select_streams a:0 -show_entries stream=codec_type -of csv=s=x:p=0 "$file" 2>/dev/null | head -1)
    if [ -n "$has_audio" ] && [ "$has_audio" = "audio" ]; then
        audio_codec=$(ffprobe -v error -select_streams a:0 -show_entries stream=codec_name -of csv=s=x:p=0 "$file" 2>/dev/null | head -1)
        case "$audio_codec" in
            opus|vorbis)
                echo "Audio: copy ($audio_codec)"
                audio_opts="-c:a copy"
                ;;
            *)
                echo "Audio: encode to opus (source: $audio_codec)"
                audio_opts="-c:a libopus -ac 2 -ar 48000 -b:a 96k"
                ;;
        esac
    else
        echo "No audio stream detected"
        audio_opts="-an"
    fi

    log=$(mktemp)
    if ! ffmpeg -y -i "$file" $scale \
         -c:v libvpx-vp9 -crf 20 -b:v 0 -row-mt 1 \
         -r 30 \
         $audio_opts \
         "$temp" >"$log" 2>&1; then
        echo "Error: FFmpeg failed for $file"
        tail -5 "$log"
        rm -f "$temp" "$log"
        error=1
        continue
    fi
    rm -f "$log"

    if [ ! -s "$temp" ]; then
        echo "Error: Output file is empty"
        rm -f "$temp"
        error=1
        continue
    fi

    mv "$temp" "$output"
    echo "Done: $output"
done

if [ $error -ne 0 ]; then
    echo "Press Enter to exit..."
    read
else
    printf "\nAll done. "
    read -t 3 -p "Closing in 3s..." 2>/dev/null || echo ""
fi

exit $error
