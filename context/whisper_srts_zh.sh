#!/bin/sh
# Transcribe audio/video files to Simplified Chinese SRT using whisper.cpp
# Model: https://huggingface.co/BELLE-2/Belle-whisper-large-v3-turbo-zh-ggml
#
# Notes:
#   scoop install whisper-cpp
#
# Usage:
#   Windows:
#     Create a .lnk shortcut to this script in the SendTo folder, then:
#     Select files > Right-click > Send To > whisper_srts_zh
#
#   Linux (Thunar):
#     Edit > Configure custom actions > Add action with command: /path/to/script.sh %F
#
#   Command line:
#     ./script.sh <audio1> <audio2> ...

if [ $# -eq 0 ]; then
    echo "Error: No files selected"
    echo "Press Enter to exit..."
    read
    exit 1
fi

if ! command -v whisper-cli >/dev/null 2>&1; then
    echo "Error: whisper-cli not found"
    echo "Press Enter to exit..."
    read
    exit 1
fi

MODEL="$USERHOME/Local/Model/whisper-cpp/Belle-whisper-large-v3-turbo-zh-ggml.bin"

if [ ! -f "$MODEL" ]; then
    echo "Error: Model not found: $MODEL"
    echo "Press Enter to exit..."
    read
    exit 1
fi

error=0

for file in "$@"; do
    dir=$(dirname "$file")
    basename_noext=$(basename "$file" | sed 's/\.[^.]*$//')
    outbase="$dir/$basename_noext.[whisper].zh"

    printf "\n--- %s ---\n" "$file"

    if ! whisper-cli \
        -m "$MODEL" \
        -t 16 \
        -of "$outbase" \
        -osrt \
        -ml 80 \
        --prompt "使用简体中文，正确使用标点符号。" \
        -l zh \
        -f "$file"
    then
        echo "Error: Failed to transcribe $file"
        error=1
        continue
    fi

    echo "Done: ${outbase}.srt"
done

if [ $error -ne 0 ]; then
    echo "Press Enter to exit..."
    read
else
    printf "\nAll done. "
    read -t 3 -p "Closing in 3s..." 2>/dev/null || echo ""
fi

exit $error
