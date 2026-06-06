#!/bin/bash
# Search and view documents using fzf.
# Dependences: rg, bat, fzf, fzf-preview.sh

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# FZF configuration
export FZF_DEFAULT_COMMAND="rg --files"
FLAG="--layout=reverse --border none --preview-border none --no-scrollbar --no-separator --inline-info --ansi"
BIND="--bind 'alt-p:preview-page-up,alt-n:preview-page-down'"
BIND_VIEW="--bind 'enter:execute(less -RN {+})+abort'"
BIND_NVIM="--bind 'ctrl-v:execute(nvim {+})+abort'"
BIND_TABIEW="--bind 'ctrl-t:execute(tw {+})+abort'"
BIND_FX="--bind 'ctrl-f:execute(fx {+})+abort'"
PREVIEW="--preview 'bash ${SCRIPT_DIR}/fzf-preview.sh {}'"
PREVIEW_WINDOW="--preview-window 'up,60%,border-bottom,+{2}+3/3,~2'"
BIND_TOGGLE_PREVIEW="--bind 'ctrl-\\:change-preview-window(up,60%,border-bottom,+{2}+3/3,~2|right,60%,wrap,~2)'"

FZF_CMD="fzf $FLAG $BIND $BIND_VIEW $BIND_NVIM $BIND_TABIEW $BIND_FX $BIND_TOGGLE_PREVIEW $PREVIEW $PREVIEW_WINDOW"


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
    echo "Usage: fzf_docs [<directory>]"
    echo ""
    echo "Arguments:"
    echo "  <dir>    Search in specified directory (default: current directory)"
    echo ""
    echo "Examples:"
    echo "  fzf_docs                    # Search in current directory"
    echo "  fzf_docs ~/Documents/man    # Search in specified directory"
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
