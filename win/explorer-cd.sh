#!/bin/bash
# Open Windows Explorer at path
# Supports: relative, C:\, C:\\, /c/ (Git Bash), /mnt/c/ (WSL)

to_win_path() {
    local p="$1"
    p="${p%/}"
    p="${p%\\}"
    p="${p//\\\\/\\}"

    case "$p" in
        [A-Za-z]:[\\/]*) p="${p//\//\\}"; printf '%s' "$p"; return ;;
    esac

    if command -v cygpath >/dev/null 2>&1; then
        cygpath -wa "$p" && return
    fi

    if [[ "$p" != /* ]]; then
        if [ -d "$p" ]; then
            p="$(cd "$p" && pwd)"
        else
            local dir="$(dirname "$p")"
            if [ -d "$dir" ]; then
                p="$(cd "$dir" && pwd)/$(basename "$p")"
            else
                p="$(pwd)/$p"
            fi
        fi
    fi

    if command -v wslpath >/dev/null 2>&1; then
        wslpath -w "$p" && return
    fi

    case "$p" in
        /mnt/[A-Za-z]|/mnt/[A-Za-z]/*)
            local d="${p:5:1}"

            d="${d^^}"
            local rest="${p:6}"
            rest="${rest//\//\\}"
            printf '%s' "${d}:${rest}"
            return
            ;;
        /[A-Za-z]|/[A-Za-z]/*)
            local d="${p:1:1}"

            d="${d^^}"
            local rest="${p:2}"
            rest="${rest//\//\\}"
            printf '%s' "${d}:${rest}"
            return
            ;;
    esac

    printf '%s' "$p"
}

target="${1:-.}"
explorer.exe "$(to_win_path "$target")"
