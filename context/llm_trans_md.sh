#!/bin/sh
# Translate Markdown/TXT files using local LLM (preserving formatting)
#
# Markdown placeholder/tokenization strategy adapted from:
#   https://github.com/rockbenben/md-translator
#
# Model language support (see lib/llm_trans_md.py for full list):
#   gemma-3-12b-it        https://ai.google.dev/gemma/core/cards/gemma-3  (140+)
#   translategemma-12b-it-i1  https://ai.google.dev/gemma/core/translate-gemma (~30)
#
# Requires:
#   uv (https://docs.astral.sh/uv/)
#   llama.cpp server running (default: http://127.0.0.1:8010)
#
# Usage:
#   Windows:
#     Create a .lnk shortcut to this script in the SendTo folder, then:
#     Select .md/.txt files > Right-click > Send To > llm_trans_md
#
#   Linux (Thunar):
#     Edit > Configure custom actions > Add action with command: /path/to/script.sh %F
#
#   Command line:
#     ./script.sh <file1.md> <file2.txt> ...
#
#   Non-interactive (skip menu):
#     ./script.sh --model=translategemma-12b-it-i1 --source=en --target=zh <file1.md>
#     LLM_TRANS_MODEL=translategemma-12b-it-i1 LLM_TRANS_SRC=en LLM_TRANS_TGT=zh ./script.sh <file1.md>
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

if ! command -v uv >/dev/null 2>&1; then
    echo "Error: uv not found (https://docs.astral.sh/uv/)"
    echo "Press Enter to exit..."
    read
    exit 1
fi

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

# Languages: Name:code (alphabetical by name, 2-column layout)
LANGUAGES="Arabic:ar Czech:cs Danish:da Dutch:nl English:en Finnish:fi French:fr German:de Greek:el Hebrew:he Hindi:hi Hungarian:hu Indonesian:id Italian:it Japanese:ja Korean:ko Norwegian:no Polish:pl Portuguese:pt Romanian:ro Russian:ru Simplified-Chinese:zh Spanish:es Swedish:sv Thai:th Traditional-Chinese:zh-tw Turkish:tr Ukrainian:uk Vietnamese:vi Auto-detect:auto"

# ── Source language selection ────────────────────────────────────────────────

if [ -n "$arg_source" ]; then
    SRC_LANG="$arg_source"
elif [ -n "$LLM_TRANS_SRC" ]; then
    SRC_LANG="$LLM_TRANS_SRC"
else
    echo "Source language:"
    cols=0
    num=1
    for entry in $LANGUAGES; do
        name="${entry%%:*}"
        code="${entry#*:}"
        printf "  %2d) %-22s %s" "$num" "$name" "$code"
        cols=$((cols + 1))
        if [ $((cols % 2)) -eq 0 ]; then
            printf "\n"
        fi
        num=$((num + 1))
    done
    if [ $((cols % 2)) -ne 0 ]; then
        printf "\n"
    fi
    printf "Enter number or code [30]: "
    read choice
    choice=${choice:-30}

    if echo "$choice" | grep -qE '^[0-9]+$'; then
        SRC_LANG=$(echo "$LANGUAGES" | tr ' ' '\n' | sed -n "${choice}p" | cut -d: -f2)
        if [ -z "$SRC_LANG" ]; then
            echo "Error: Invalid selection"
            echo "Press Enter to exit..."
            read
            exit 1
        fi
    else
        SRC_LANG="$choice"
    fi
fi

# ── Target language selection ────────────────────────────────────────────────

if [ -n "$arg_target" ]; then
    TGT_LANG="$arg_target"
elif [ -n "$LLM_TRANS_TGT" ]; then
    TGT_LANG="$LLM_TRANS_TGT"
else
    echo ""
    echo "Target language:"
    cols=0
    tnum=0
    for entry in $LANGUAGES; do
        name="${entry%%:*}"
        code="${entry#*:}"
        # Skip "Auto-detect" for target
        if [ "$code" = "auto" ]; then
            continue
        fi
        tnum=$((tnum + 1))
        printf "  %2d) %-22s %s" "$tnum" "$name" "$code"
        cols=$((cols + 1))
        if [ $((cols % 2)) -eq 0 ]; then
            printf "\n"
        fi
    done
    if [ $((cols % 2)) -ne 0 ]; then
        printf "\n"
    fi
    printf "Enter number or code [22]: "
    read choice
    choice=${choice:-22}

    if echo "$choice" | grep -qE '^[0-9]+$'; then
        # Build target list (without auto)
        TGT_LANGUAGES=$(echo "$LANGUAGES" | tr ' ' '\n' | grep -v ':auto$')
        TGT_LANG=$(echo "$TGT_LANGUAGES" | sed -n "${choice}p" | cut -d: -f2)
        if [ -z "$TGT_LANG" ]; then
            echo "Error: Invalid selection"
            echo "Press Enter to exit..."
            read
            exit 1
        fi
    else
        TGT_LANG="$choice"
    fi
fi

echo ""
echo "Model:  $MODEL"
echo "Source: $SRC_LANG"
echo "Target: $TGT_LANG"
echo ""

script_dir="$(cd "$(dirname "$0")" && pwd)"

error=0

for file in "$@"; do
    if ! uv run "$script_dir/lib/llm_trans_md.py" \
        --host "http://127.0.0.1:8010" \
        --model "$MODEL" \
        --src-lang "$SRC_LANG" \
        --tgt-lang "$TGT_LANG" \
        "$file"
    then
        echo "Error: Failed to translate $file"
        error=1
    fi
done

if [ $error -ne 0 ]; then
    echo "Press Enter to exit..."
    read
fi

exit $error
