#!/bin/sh
# Transcribe audio/video files to SRT using whisper.cpp
#
# Models:
#   Default: https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3-turbo.bin
#   Chinese: https://huggingface.co/BELLE-2/Belle-whisper-large-v3-turbo-zh-ggml
#
# Notes:
#   scoop install whisper-cpp
#
# Supported formats:
#   Audio: mp3, wav, flac, ogg, m4a, m4b, aac, wma, ape, opus
#   Video: mp4, mkv, webm, avi, mov, wmv, flv, m4v
#
# Usage:
#   Windows:
#     Create a .lnk shortcut to this script in the SendTo folder, then:
#     Select files > Right-click > Send To > whisper_medias
#
#   Linux (Thunar):
#     Edit > Configure custom actions > Add action with command: /path/to/script.sh %F
#
#   Command line:
#     ./script.sh <file1> <file2> ...

MODEL_DIR="$USERHOME/Local/Model/whisper-cpp"
MODEL_DEFAULT="$MODEL_DIR/ggml-large-v3-turbo.bin"
MODEL_ZH="$MODEL_DIR/Belle-whisper-large-v3-turbo-zh-ggml.bin"

# Whisper supported languages (99 total):
# https://github.com/openai/whisper/blob/main/whisper/tokenizer.py
COMMON_LANGUAGES="en:English zh:Simplified-Chinese ja:Japanese ko:Korean es:Spanish fr:French de:German ru:Russian it:Italian pt:Portuguese ar:Arabic hi:Hindi nl:Dutch pl:Polish tr:Turkish vi:Vietnamese th:Thai id:Indonesian uk:Ukrainian cs:Czech sv:Swedish da:Danish fi:Finnish el:Greek he:Hebrew hu:Hungarian ro:Romanian no:Norwegian"

OTHER_LANGUAGES="af:Afrikaans am:Amharic as:Assamese az:Azerbaijani ba:Bashkir be:Belarusian bg:Bulgarian bn:Bengali bo:Tibetan br:Breton bs:Bosnian ca:Catalan cy:Welsh eo:Esperanto et:Estonian eu:Basque fa:Persian fo:Faroese gl:Galician gu:Gujarati ha:Hausa haw:Hawaiian hr:Croatian ht:Haitian hy:Armenian is:Icelandic jw:Javanese ka:Georgian kk:Kazakh km:Khmer kn:Kannada la:Latin lb:Luxembourgish ln:Lingala lo:Lao lt:Lithuanian lv:Latvian mg:Malagasy mi:Maori mk:Macedonian ml:Malayalam mn:Mongolian mr:Marathi ms:Malay mt:Maltese my:Myanmar ne:Nepali nn:Norwegian-Nynorsk oc:Occitan pa:Panjabi ps:Pashto ro:Romanian sa:Sanskrit sd:Sindhi si:Sinhala sk:Slovak sl:Slovenian sn:Shona so:Somali sq:Albanian sr:Serbian su:Sundanese sw:Swahili ta:Tamil te:Telugu tg:Tajik tk:Turkmen tl:Tagalog tt:Tatar ug:Uighur ur:Urdu uz:Uzbek yi:Yiddish yo:Yoruba"

show_languages() {
    list="$1"

    cols=0
    num=1
    for entry in $list; do
        code="${entry%%:*}"
        name="${entry#*:}"
        printf "%3d) %-4s %-16s" "$num" "$code" "$name"
        cols=$((cols + 1))
        if [ $((cols % 3)) -eq 0 ]; then
            printf "\n"
        fi
        num=$((num + 1))
    done

    printf "%3d) %-4s %-16s\n" "$num" "" "Other-Languages..."

    if [ $((cols % 3)) -ne 0 ]; then
        printf "\n"
    fi
}

show_other_languages() {
    cols=0
    num=1
    for entry in $OTHER_LANGUAGES; do
        code="${entry%%:*}"
        name="${entry#*:}"
        printf "%3d) %-4s %-16s" "$num" "$code" "$name"
        cols=$((cols + 1))
        if [ $((cols % 3)) -eq 0 ]; then
            printf "\n"
        fi
        num=$((num + 1))
    done

    if [ $((cols % 3)) -ne 0 ]; then
        printf "\n"
    fi
}

select_other_language() {
    prompt="$1"

    while true; do
        echo ""
        echo "$prompt (Other Languages)"
        echo "----------------------------------------"
        echo "WARNING: Transcription quality not guaranteed for these languages"
        echo ""
        show_other_languages
        total=$(echo "$OTHER_LANGUAGES" | wc -w)
        echo ""
        printf "Enter number or code (e.g. en, zh, ja): "
        read choice

        if [ -z "$choice" ]; then
            echo "Error: Selection required"
            continue
        fi

        if echo "$choice" | grep -qE '^[0-9]+$'; then
            if [ "$choice" -ge 1 ] && [ "$choice" -le "$total" ]; then
                SELECTED=$(echo "$OTHER_LANGUAGES" | cut -d' ' -f"$choice" | cut -d: -f1)
                return 0
            fi
        fi

        SELECTED="$choice"
        return 0
    done
}

select_language() {
    prompt="$1"

    while true; do
        echo ""
        echo "$prompt"
        echo "----------------------------------------"
        show_languages "$COMMON_LANGUAGES"
        total=$(echo "$COMMON_LANGUAGES" | wc -w)
        total=$((total + 1))
        echo ""
        printf "Enter number or code (e.g. en, zh, ja): "
        read choice

        if [ -z "$choice" ]; then
            echo "Error: Selection required"
            continue
        fi

        if echo "$choice" | grep -qE '^[0-9]+$'; then
            if [ "$choice" -ge 1 ] && [ "$choice" -le "$(echo "$COMMON_LANGUAGES" | wc -w)" ]; then
                SELECTED=$(echo "$COMMON_LANGUAGES" | cut -d' ' -f"$choice" | cut -d: -f1)
                return 0
            fi

            if [ "$choice" -eq "$total" ]; then
                select_other_language "$prompt"
                return $?
            fi
        fi

        SELECTED="$choice"
        return 0
    done
}

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

select_language "Transcription Language"
LANG="$SELECTED"

if [ "$LANG" = "zh" ] || [ "$LANG" = "zh-cn" ] || [ "$LANG" = "zh_CN" ]; then
    MODEL="$MODEL_ZH"
    PROMPT="使用简体中文，正确使用标点符号。"
else
    MODEL="$MODEL_DEFAULT"
    PROMPT="Transcribe with proper punctuation, capitalize proper nouns."
fi

if [ ! -f "$MODEL" ]; then
    echo "Error: Model not found: $MODEL"
    echo "Press Enter to exit..."
    read
    exit 1
fi

printf "\nTranscribing with language: %s\n" "$LANG"
printf "Model: %s\n" "$(basename "$MODEL")"

error=0

for file in "$@"; do
    dir=$(dirname "$file")
    basename_noext=$(basename "$file" | sed 's/\.[^.]*$//')
    outbase="$dir/$basename_noext.[whisper].$LANG"

    printf "\n--- %s ---\n" "$file"

    if ! whisper-cli \
        -m "$MODEL" \
        -t 16 \
        -of "$outbase" \
        -osrt \
        -ml 80 \
        --prompt "$PROMPT" \
        -l "$LANG" \
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
