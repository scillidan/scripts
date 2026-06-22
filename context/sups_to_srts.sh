#!/bin/sh
# Convert PGS (SUP) files to SRT format using OCR
#
# Notes:
#   scoop install https://github.com/scillidan/scoop-pile/raw/refs/heads/master/bucket/pgstosrt.json
#   scoop install tesseract tesseract-languages
#
# Usage:
#   Windows:
#     Create a .lnk shortcut to this script in the SendTo folder, then:
#     Select files > Right-click > Send To > sups_to_srts
#
#   Linux (Thunar):
#     Edit > Configure custom actions > Add action with command: /path/to/script.sh %F
#
#   Command line:
#     ./script.sh <sup1> <sup2> ...

# Tesseract supported languages (163 total):
# https://tesseract-ocr.github.io/tessdoc/Data-Files-in-different-languages.html
# Or run: tesseract --list-langs
COMMON_LANGUAGES="eng:English chi_sim:Simplified-Chinese chi_tra:Traditional-Chinese jpn:Japanese kor:Korean spa:Spanish fra:French deu:German ita:Italian por:Portuguese rus:Russian ara:Arabic hin:Hindi nld:Dutch pol:Polish tur:Turkish vie:Vietnamese tha:Thai ind:Indonesian ukr:Ukrainian ces:Czech swe:Swedish dan:Danish fin:Finnish ell:Greek heb:Hebrew hun:Hungarian ron:Romanian nor:Norwegian"

OTHER_LANGUAGES="afr:Afrikaans amh:Amharic asm:Assamese aze:Azerbaijani aze_cyrl:Azerbaijani-Cyrillic bel:Belarusian ben:Bengali bod:Tibetan bos:Bosnian bre:Breton bul:Bulgarian cat:Catalan ceb:Cebuano chi_sim_vert:Simplified-Chinese-Vertical chi_tra_vert:Traditional-Chinese-Vertical chr:Cherokee cos:Corsican cym:Welsh div:Dhivehi dzo:Dzongkha enm:English-Middle epo:Esperanto equ:Math est:Estonian eus:Basque fao:Faroese fas:Persian fil:Filipino frk:German-Fraktur frm:French-Middle fry:Western-Frisian gla:Scottish-Gaelic gle:Irish glg:Galician grc:Ancient-Greek guj:Gujarati hat:Haitian hrv:Croatian hye:Armenian iku:Inuktitut isl:Icelandic ita_old:Italian-Old jav:Javanese jpn_vert:Japanese-Vertical kan:Kannada kat:Georgian kat_old:Georgian-Old kaz:Kazakh khm:Central-Khmer kir:Kirghiz kmr:Kurdish kor_vert:Korean-Vertical lao:Lao lat:Latin lav:Latvian lit:Lithuanian ltz:Luxembourgish mal:Malayalam mar:Marathi mkd:Macedonian mlt:Maltese mon:Mongolian mri:Maori msa:Malay mya:Burmese nep:Nepali oci:Occitan ori:Oriya pan:Panjabi pus:Pushto que:Quechua san:Sanskrit sin:Sinhala slk:Slovak slv:Slovenian snd:Sindhi spa_old:Spanish-Old sqi:Albanian srp:Serbian srp_latn:Serbian-Latin sun:Sundanese swa:Swahili syr:Syriac tam:Tamil tat:Tatar tel:Telugu tgk:Tajik tir:Tigrinya ton:Tonga uig:Uighur urd:Urdu uzb:Uzbek uzb_cyrl:Uzbek-Cyrillic yid:Yiddish yor:Yoruba"

show_languages() {
    list="$1"

    cols=0
    num=1
    for entry in $list; do
        code="${entry%%:*}"
        name="${entry#*:}"
        printf "%3d) %-12s %-18s" "$num" "$code" "$name"
        cols=$((cols + 1))
        if [ $((cols % 3)) -eq 0 ]; then
            printf "\n"
        fi
        num=$((num + 1))
    done

    printf "%3d) %-12s %-18s\n" "$num" "" "Other-Languages..."

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
        printf "%3d) %-12s %-18s" "$num" "$code" "$name"
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
        echo "WARNING: OCR quality not guaranteed for these languages"
        echo ""
        show_other_languages
        total=$(echo "$OTHER_LANGUAGES" | wc -w)
        echo ""
        printf "Enter number or code (e.g. eng, jpn, chi_sim): "
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
        printf "Enter number or code (e.g. eng, jpn, chi_sim): "
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

if [ -z "$TESSDATA_PREFIX" ]; then
    echo "Error: TESSDATA_PREFIX is not set"
    echo "Press Enter to exit..."
    read
    exit 1
fi

if ! command -v pgstosrt >/dev/null 2>&1; then
    echo "Error: pgstosrt not found"
    echo "Press Enter to exit..."
    read
    exit 1
fi

select_language "OCR Language"
LANG="$SELECTED"

printf "\nConverting with language: %s\n" "$LANG"

error=0

for file in "$@"; do
    output="${file%.*}.srt"
    printf "\n--- %s ---\n" "$file"

    if ! pgstosrt \
        --input "$file" \
        --output "$output" \
        --tesseractlanguage "$LANG" \
        --tesseractdata "$TESSDATA_PREFIX"
    then
        echo "Error: Failed to convert $file"
        error=1
        continue
    fi

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
