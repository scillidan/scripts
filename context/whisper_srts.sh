#!/bin/sh
# Transcribe audio/video files to SRT using whisper.cpp
# Model: https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3-turbo.bin
#
# Notes:
#   scoop install whisper-cpp
#
# Usage:
#   Windows:
#     Create a .lnk shortcut to this script in the SendTo folder, then:
#     Select files > Right-click > Send To > whisper_srts
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

MODEL="$USERHOME/Local/Model/whisper-cpp/ggml-large-v3-turbo.bin"

if [ ! -f "$MODEL" ]; then
    echo "Error: Model not found: $MODEL"
    echo "Press Enter to exit..."
    read
    exit 1
fi

# Full list: https://github.com/openai/whisper/blob/main/whisper/tokenizer.py
LANGS="auto en fr de es ru zh ko ja"
printf "Language [%s] (Default en): " "$LANGS"
read lang
lang=${lang:-en}

error=0

for file in "$@"; do
    dir=$(dirname "$file")
    basename_noext=$(basename "$file" | sed 's/\.[^.]*$//')
    outbase="$dir/$basename_noext.[whisper].$lang"

    printf "\n--- %s ---\n" "$file"

    if ! whisper-cli \
        -m "$MODEL" \
        -t 16 \
        -of "$outbase" \
        -osrt \
        -ml 80 \
        --prompt "Transcribe with proper punctuation, capitalize proper nouns." \
        -l "$lang" \
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
