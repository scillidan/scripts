#!/bin/bash
# https://github.com/narnaud/clink-terminal/blob/main/bin/y.cmd

tmpfile="${TEMP}/yazi-cwd.$$"

yazi "$@" --cwd-file="$tmpfile"

if [ -f "$tmpfile" ]; then
    cwd=$(cat "$tmpfile")

    if [ -n "$cwd" ]; then
        cd "$cwd"
    fi
    rm "$tmpfile"
fi