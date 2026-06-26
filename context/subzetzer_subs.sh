#!/bin/sh
# Translate SRT/VTT/TSV subtitles using subsetzer-llamacpp
#
# Command source (forked and rewritten):
#   https://github.com/scillidan/subsetzer-llamacpp
#   (C:\Users\User\Share\forks\subsetzer-llamacpp)
#
# Notes:
#   Requires subsetzer-llamacpp installed and llama.cpp server running
#   Server: llama-server -m <model>.gguf --port 8010
#
# Usage:
#   Windows:
#     Create a .lnk shortcut to this script in the SendTo folder, then:
#     Select files > Right-click > Send To > subzetzer_subs
#
#   Linux (Thunar):
#     Edit > Configure custom actions > Add action with command: /path/to/script.sh %F
#
#   Command line:
#     ./script.sh <srt1> <srt2> ...
#
#   Non-interactive (skip menu):
#     ./script.sh --model=translategemma-12b-it-i1 --source=en --target=zh <file.srt>
#     LLM_TRANS_MODEL=translategemma-12b-it-i1 LLM_TRANS_SRC=en LLM_TRANS_TGT=zh ./script.sh <file.srt>
#
# ── Built-in ENV defaults ─────────────────────────────────────────────────────
# Set externally to skip the interactive menu. Precedence: --args > ENV > menu.
#   LLM_TRANS_MODEL=translategemma-12b-it-i1
#   LLM_TRANS_SRC=en
#   LLM_TRANS_TGT=zh

# ── Parse --args ─────────────────────────────────────────────────────────────

arg_model=""
arg_source=""
arg_target=""

while [ $# -gt 0 ]; do
    case "$1" in
        --model=*)
            arg_model="${1#--model=}"
            shift
            ;;
        --source=*)
            arg_source="${1#--source=}"
            shift
            ;;
        --target=*)
            arg_target="${1#--target=}"
            shift
            ;;
        *)
            break
            ;;
    esac
done

# ── File checks ──────────────────────────────────────────────────────────────

if [ $# -eq 0 ]; then
    echo "Error: No files selected"
    echo "Press Enter to exit..."
    read
    exit 1
fi

if ! command -v subsetzer-llamacpp >/dev/null 2>&1; then
    echo "Error: subsetzer-llamacpp not found"
    echo "Press Enter to exit..."
    read
    exit 1
fi

# ════════════════════════════════════════════════════════════════════════════
# Language lists — subsetzer-llamacpp normalises languages via its langs.py
#
# WARNING: The language lists below reference Gemma 3's cloud model card
# (https://ai.google.dev/gemma/core/cards/gemma-3). The local GGUF checkpoint
# may not support all listed languages with the same quality — or at all.
# Verify with your GGUF before relying on obscure language pairs.
#
# translategemma-12b-it-i1 supports ~30 languages (see model card):
#   https://ai.google.dev/gemma/core/translate-gemma
# ════════════════════════════════════════════════════════════════════════════

COMMON_LANGUAGES="en:English zh-cn:Simplified-Chinese zh-tw:Traditional-Chinese ja:Japanese ko:Korean es:Spanish fr:French de:German ru:Russian it:Italian pt:Portuguese ar:Arabic hi:Hindi nl:Dutch pl:Polish tr:Turkish vi:Vietnamese th:Thai id:Indonesian uk:Ukrainian cs:Czech sv:Swedish da:Danish fi:Finnish el:Greek he:Hebrew hu:Hungarian ro:Romanian no:Norwegian"

OTHER_LANGUAGES="aa:Afar ab:Abkhazian af:Afrikaans ak:Akan sq:Albanian am:Amharic an:Aragonese hy:Armenian as:Assamese av:Avaric ae:Avestan ay:Aymara az:Azerbaijani bm:Bambara ba:Bashkir eu:Basque be:Belarusian bn:Bengali bh:Bihari bi:Bislama bs:Bosnian br:Breton bg:Bulgarian my:Burmese ca:Catalan ch:Chamorro ce:Chechen cu:Church-Slavic cv:Chuvash kw:Cornish co:Corsican cr:Cree hr:Croatian dv:Divehi dz:Dzongkha eo:Esperanto et:Estonian ee:Ewe fo:Faroese fj:Fijian fy:Western-Frisian ff:Fulah gd:Scottish-Gaelic ga:Irish gl:Galician gv:Manx gn:Guarani gu:Gujarati ht:Haitian ha:Hausa hz:Herero ho:Hiri-Motu ig:Igbo is:Icelandic io:Ido ia:Interlingua ie:Interlingue iu:Inuktitut ik:Inupiaq jv:Javanese kl:Kalaallisut kn:Kannada ks:Kashmiri kr:Kanuri kk:Kazakh km:Central-Khmer ki:Kikuyu rw:Kinyarwanda ky:Kirghiz kv:Komi kg:Kongo kj:Kuanyama ku:Kurdish lo:Lao la:Latin lv:Latvian lt:Lithuanian li:Limburgan ln:Lingala lb:Luxembourgish lu:Luba-Katanga lg:Ganda mk:Macedonian ml:Malayalam ms:Malay mg:Malagasy mt:Maltese mi:Maori mr:Marathi mh:Marshallese mn:Mongolian na:Nauru nv:Navajo nd:North-Ndebele ng:Ndonga ne:Nepali se:Northern-Sami nb:Norwegian-Bokmal nn:Norwegian-Nynorsk oc:Occitan oj:Ojibwa or:Oriya os:Ossetian om:Oromo pi:Pali pa:Panjabi fa:Persian ps:Pushto qu:Quechua rm:Raeto-Romance rn:Rundi sm:Samoan sg:Sango sa:Sanskrit sr:Serbian sh:Serbo-Croatian st:Southern-Sotho tn:Tswana sn:Shona sd:Sindhi si:Sinhala sk:Slovak sl:Slovenian so:Somali su:Sundanese sw:Swahili ss:Swati tl:Tagalog ty:Tahitian tg:Tajik ta:Tamil tt:Tatar te:Telugu bo:Tibetan ti:Tigrinya to:Tonga ts:Tsonga tk:Turkmen tw:Twi ug:Uighur ur:Urdu uz:Uzbek ve:Venda vo:Volapuk wa:Walloon cy:Welsh wo:Wolof xh:Xhosa yi:Yiddish yo:Yoruba za:Zhuang zu:Zulu"

show_languages() {
    list="$1"
    default="$2"

    cols=0
    if [ "$default" = "auto" ]; then
        printf "  0) %-18s" "auto"
        cols=1
    fi

    num=1
    for entry in $list; do
        name="${entry#*:}"
        printf "%3d) %-18s" "$num" "$name"
        cols=$((cols + 1))
        if [ $((cols % 3)) -eq 0 ]; then
            printf "\n"
        fi
        num=$((num + 1))
    done

    printf "%3d) %-18s\n" "$num" "Other-Languages..."

    if [ $((cols % 3)) -ne 0 ]; then
        printf "\n"
    fi
}

show_other_languages() {
    cols=0
    num=1
    for entry in $OTHER_LANGUAGES; do
        name="${entry#*:}"
        printf "%3d) %-18s" "$num" "$name"
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
        echo "WARNING: Language quality not guaranteed — see notes above"
        echo ""
        show_other_languages
        total=$(echo "$OTHER_LANGUAGES" | wc -w)
        echo ""
        printf "Enter number or code (e.g. en, eng, English): "
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
    default="$2"

    while true; do
        echo ""
        echo "$prompt"
        echo "----------------------------------------"
        show_languages "$COMMON_LANGUAGES" "$default"
        total=$(echo "$COMMON_LANGUAGES" | wc -w)
        total=$((total + 1))
        echo ""
        printf "Enter number or code (e.g. en, eng, English)"
        if [ -n "$default" ]; then
            printf " [%s]" "$default"
        fi
        printf ": "
        read choice

        if [ -z "$choice" ] && [ -n "$default" ]; then
            SELECTED="$default"
            return 0
        fi

        if [ -z "$choice" ]; then
            echo "Error: Selection required"
            continue
        fi

        if [ "$choice" = "0" ] && [ "$default" = "auto" ]; then
            SELECTED="auto"
            return 0
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

# ── Model selection ──────────────────────────────────────────────────────────

# Available models (display-name:model-tag)
MODELS="TranslateGemma-12b:translategemma-12b-it-i1 Gemma-3-12b:gemma-3-12b-it"

if [ -n "$arg_model" ]; then
    MODEL="$arg_model"
elif [ -n "$LLM_TRANS_MODEL" ]; then
    MODEL="$LLM_TRANS_MODEL"
else
    echo "Select model:"
    mnum=0
    for entry in $MODELS; do
        name="${entry%%:*}"
        code="${entry#*:}"
        mnum=$((mnum + 1))
        printf "  %d) %-22s %s\n" "$mnum" "$name" "$code"
    done
    printf "Choice [1]: "
    read mchoice
    mchoice=${mchoice:-1}

    if echo "$mchoice" | grep -qE '^[0-9]+$'; then
        MODEL=$(echo "$MODELS" | tr ' ' '\n' | sed -n "${mchoice}p" | cut -d: -f2)
        if [ -z "$MODEL" ]; then
            echo "Error: Invalid selection"
            echo "Press Enter to exit..."
            read
            exit 1
        fi
    else
        MODEL="$mchoice"
    fi
fi

# ── Source language selection ────────────────────────────────────────────────

if [ -n "$arg_source" ]; then
    SRC_LANG="$arg_source"
elif [ -n "$LLM_TRANS_SRC" ]; then
    SRC_LANG="$LLM_TRANS_SRC"
else
    select_language "Source Language" "auto"
    SRC_LANG="$SELECTED"
fi

# ── Target language selection ────────────────────────────────────────────────

if [ -n "$arg_target" ]; then
    TGT_LANG="$arg_target"
elif [ -n "$LLM_TRANS_TGT" ]; then
    TGT_LANG="$LLM_TRANS_TGT"
else
    select_language "Target Language" ""
    TGT_LANG="$SELECTED"
    while [ -z "$TGT_LANG" ]; do
        echo "Error: Target language is required"
        select_language "Target Language" ""
        TGT_LANG="$SELECTED"
    done
fi

echo ""
echo "Model:  $MODEL"
echo "Source: $SRC_LANG"
echo "Target: $TGT_LANG"
echo ""

error=0

for file in "$@"; do
    dir=$(dirname "$file")
    basename_noext=$(basename "$file" | sed 's/\.[^.]*$//')
    outfile="$dir/$basename_noext.$TGT_LANG.srt"

    printf "\n--- %s ---\n" "$file"

    if ! subsetzer-llamacpp \
        --host http://localhost:8010 \
        --model "$MODEL" \
        --format srt \
        --no-punc \
        --source "$SRC_LANG" \
        --target "$TGT_LANG" \
        --in "$file" \
        --out "$outfile"
    then
        echo "Error: Failed to translate $file"
        error=1
        continue
    fi

    echo "Done: $outfile"
done

if [ $error -ne 0 ]; then
    echo "Press Enter to exit..."
    read
else
    printf "\nAll done. "
    read -t 3 -p "Closing in 3s..." 2>/dev/null || echo ""
fi

exit $error
