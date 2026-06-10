#!/bin/bash

# Authors: GLM-5🧙‍♂️, Hy3-preview🧙‍♂️ scillidan🤡
# License: MIT
# Description: CDs - cd dirs, spawn tool
# Usage: cds.sh <command> [paths...]
# Examples:
#   cds.sh lazygit
#   cds.sh nvim .
#   cds.sh lazygit ~/r1 ~/r2
#
# Environment:
#   CDS_TERMINAL=wezterm | tmux

set -o errexit
set -o nounset

TOOL="$1"
shift

if [[ -z "$TOOL" ]]; then
    echo "Error: No tool specified" >&2
    echo "Usage: cds.sh <command> [path1] [path2] ..." >&2
    exit 1
fi

PATHS=()
for arg in "$@"; do
    arg="${arg%/}"
    arg="${arg%\\}"
    PATHS+=("$arg")
done

if [[ ${#PATHS[@]} -eq 0 ]]; then
    PATHS+=(".")
fi

get_abs_path() {
    local path="$1"
    if [[ -d "$path" ]]; then
        (cd "$path" && pwd)
    else
        echo "Error: Path not found '$path'" >&2
        return 1
    fi
}

wezterm_only() {
    exec bash -c "cd '$1' && exec $TOOL"
}

wezterm_first() {
    wezterm cli spawn --cwd "$1" -- bash -c "$TOOL"
}

wezterm_next() {
    sleep 0.5
    wezterm cli spawn --cwd "$1" -- bash -c "$TOOL"
    wezterm cli activate-tab --tab-relative -1
}

tmux_only() {
    if tmux has-session 2>/dev/null; then
        exec tmux new-window -c "$1" "$TOOL"
    else
        exec tmux new-session -s cds -c "$1" "$TOOL"
    fi
}

tmux_first() {
    if tmux has-session 2>/dev/null; then
        tmux new-window -c "$1" "$TOOL"
    else
        tmux new-session -s cds -c "$1" "$TOOL"
        tmux attach-session -t cds
    fi
}

tmux_next() {
    sleep 0.2
    tmux new-window -c "$1" "$TOOL"
}

open_in_tabs() {
    local backend="$1"

    if [[ ${#PATHS[@]} -eq 1 ]]; then
        ABS_PATH=$(get_abs_path "${PATHS[0]}") || return 1
        "${backend}_only" "$ABS_PATH"
        return
    fi

    local first=true
    for path in "${PATHS[@]}"; do
        ABS_PATH=$(get_abs_path "$path") || continue

        if $first; then
            "${backend}_first" "$ABS_PATH"
            first=false
        else
            "${backend}_next" "$ABS_PATH"
        fi
    done
}

CDS_TERMINAL="${CDS_TERMINAL:-}"

case "$CDS_TERMINAL" in
    wezterm)
        open_in_tabs wezterm
        ;;
    tmux)
        open_in_tabs tmux
        ;;
    *)
        echo "Error: Unsupported or unset CDS_TERMINAL" >&2
        echo "Supported values: wezterm, tmux" >&2
        exit 1
        ;;
esac
