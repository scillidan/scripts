#!/bin/sh
#
# Usage:
#   ./script.sh [name] [text]     (no text: clipboard; no name: menu)
#
# Runs on Linux and on Windows via git bash. The result is printed and also
# copied to the clipboard when one is available.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PY_SCRIPT="$SCRIPT_DIR/lib/puzz_tool.py"

# name:description
TOOLS='
delquery:delete after ?
delspace:remove all whitespace (NBSP too)
ghcommitsatom:repo url -> its commits atom feed
ghreleasesatom:repo url -> its releases atom feed
ghurlapi:https://github.com/o/r -> https://api.github.com/repos/o/r
ghurlraw:blob url -> raw.githubusercontent.com url
ghurlshorter:repo url -> owner/repo
linessplitbycomma:lines -> one lowercase comma list
scoopwhere:Scoop shims\app.exe -> apps\app\current\app.exe
typstsearch:preview/name/... -> universe search url
unixlink:backslashes -> slashes
unixlink2:double backslashes -> slashes
windowslink:slashes -> backslashes
windowslink2:backslashes -> double backslashes
'

is_tool() { # 1: name -> succeeds if it is a known tool
	printf '%s\n' "$TOOLS" | cut -d: -f1 | grep -qx -- "$1"
}

select_tool() {
	while :; do
		echo "Convert:"
		printf '%s\n' "$TOOLS" | while IFS=: read -r name desc; do
			[ -n "$name" ] && printf '  %-16s %s\n' "$name" "$desc"
		done
		printf "Choice: "
		read -r choice
		is_tool "$choice" && tool=$choice && return
		echo "Invalid choice"
	done
}

case "$1" in
-h | --help)
	echo "Usage: $(basename "$0") [name] [text]"
	exit 0
	;;
*)
	if is_tool "$1"; then
		tool=$1
		shift
	else
		select_tool
	fi
	;;
esac

uv run "$PY_SCRIPT" "$tool" "$@"
error=$?

if [ $error -ne 0 ]; then
	echo "Error: conversion failed"
	echo "Press Enter to exit..."
	read -r
fi

exit $error
