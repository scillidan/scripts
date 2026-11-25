#!/bin/sh
#
# Usage:
#   ./script.sh [option] [text]     (no text: clipboard; no option: menu)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PY_SCRIPT="$SCRIPT_DIR/lib/puzz_transform.py"

# option:description
TRANSFORM='
delquery:delete after ?
delspace:remove all whitespace (NBSP too)
ghcommitsatom:repo url -> its commits atom feed
ghreleasesatom:repo url -> its releases atom feed
ghurlapi:https://github.com/o/r -> https://api.github.com/repos/o/r
ghurlraw:blob url -> raw.githubusercontent.com url
ghurlshorter:repo url -> owner/repo
linessplitbycomma:lines -> one lowercase comma list
scoopwhere:Scoop shims\app.exe -> apps\app\current\app.exe
unixlink:backslashes -> slashes
unixlink2:double backslashes -> slashes
windowslink:slashes -> backslashes
windowslink2:backslashes -> double backslashes
'

is_op() { # 1: option -> succeeds if it is a known op
	printf '%s\n' "$TRANSFORM" | cut -d: -f1 | grep -qx -- "$1"
}

select_op() {
	while :; do
		echo "Convert:"
		printf '%s\n' "$TRANSFORM" | while IFS=: read -r option desc; do
			[ -n "$option" ] && printf '  %-16s %s\n' "$option" "$desc"
		done
		printf "Choice: "
		read -r choice
		is_op "$choice" && op=$choice && return
		echo "Invalid choice"
	done
}

case "$1" in
-h | --help)
	echo "Usage: $(basename "$0") [option] [text]"
	exit 0
	;;
*)
	if is_op "$1"; then
		op=$1
		shift
	else
		select_op
	fi
	;;
esac

uv run "$PY_SCRIPT" "$op" "$@"
error=$?

if [ $error -ne 0 ]; then
	echo "Error: conversion failed"
	echo "Press Enter to exit..."
	read -r
fi

exit $error
