#!/bin/bash
# Search, preview, open files using fzf.
# Dependences: rg, bat, fzf, fzf-preview.sh, fzf_open.sh, fzf_bind.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source $SCRIPT_DIR/fzf_bind.sh

FLAG="--multi --layout=reverse --border none --preview-border none --no-scrollbar --no-separator --inline-info --ansi"
FZF_DEFAULT_COMMAND="rg --files"
BIND_NAVIGATE="--bind 'alt-p:preview-page-up,alt-n:preview-page-down'"
BIND_SELECT="--bind 'tab:select+down,btab:deselect+down,ctrl-a:select-all,ctrl-d:deselect-all'"
BIND_ENTER="--bind 'enter:execute(bash \"${SCRIPT_DIR}/fzf_open.sh\" {+})+abort'"
BIND_TOGGLE_PREVIEW="--bind 'ctrl-\\:change-preview-window(up,60%,border-bottom,+{2}+3/3,~2|right,60%,wrap,~2)'"
PREVIEW="--preview 'bash ${SCRIPT_DIR}/fzf_preview.sh {}'"
PREVIEW_WINDOW="--preview-window 'right,60%,wrap,~2'"

FZF_CMD="fzf $FLAG $BIND_NAVIGATE $BIND_SELECT $BIND_ENTER $BIND_NVIM $BIND_SUBL $BIND_TOGGLE_PREVIEW $PREVIEW $PREVIEW_WINDOW"

get_target_dir() {
    if [[ -n "$1" ]]; then
        if [[ -d "$1" ]]; then
            echo "$1"
        else
            echo "Error: Directory does not exist: $1" >&2
            return 1
        fi
    else
        echo "."
    fi
}

show_usage() {
    echo "Usage: fzf_files [<directory>]"
    echo ""
    echo "Arguments:"
    echo "  <dir>    Search in specified directory (default: current directory)"
    echo ""
    echo "Examples:"
    echo "  fzf_files                    # Search in current directory"
    echo "  fzf_files ~/Documents        # Search in specified directory"
    echo ""
    echo "Key Bindings:"
    echo "  Tab          Select and move down"
    echo "  Shift-Tab    Deselect and move down"
    echo "  Ctrl-A       Select all"
    echo "  Ctrl-D       Deselect all"
    echo "  Enter        Copy selected to clipboard"
    echo "  Alt-P        Preview page up"
    echo "  Alt-N        Preview page down"
    echo "  Ctrl-\\       Toggle preview position"
}

main() {
    local target_dir

    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        show_usage
        exit 0
    fi

    target_dir=$(get_target_dir "$1") || exit 1

    cd "$target_dir" && eval "$FZF_CMD"
}

main "$@"
