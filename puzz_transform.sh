#!/bin/sh
#
# Usage:
#   ./script.sh [option|number] [text]   (no text: clipboard; no option: menu)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PY_SCRIPT="$SCRIPT_DIR/lib/puzz_transform.py"

# option:description
TRANSFORM='
delquery:delete after ?
delspace:remove all whitespace (NBSP too)
ghurlcommitsatom:repo url -> its commits atom feed
ghurlreleasesatom:repo url -> its releases atom feed
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

# Known options, one per line. Blank lines are dropped, so "" is never an option.
OPS="$(printf '%s\n' "$TRANSFORM" | sed '/^[[:space:]]*$/d' | cut -d: -f1)"

is_op() { # 1: option -> succeeds if it is a known, non-empty op
	[ -n "$1" ] || return 1
	printf '%s\n' "$OPS" | grep -Fqx -- "$1"
}

op_by_number() { # 1: number -> print the 1-based option name (generated from OPS)
	case "$1" in
		'' | *[!0-9]*) return 1 ;;
	esac
	[ "$1" -ge 1 ] 2>/dev/null || return 1
	name=$(printf '%s\n' "$OPS" | sed -n "${1}p")
	[ -n "$name" ] || return 1
	printf '%s\n' "$name"
}

clean_choice() { # strip CR, control chars and ANSI CSI (bracketed paste / arrow keys)
	printf '%s' "$1" \
		| tr -d '\000-\037\177' \
		| sed 's/\[[0-9;?]*~//g; s/\[[0-9;]*[A-Za-z]//g'
}

select_op() {
	while :; do
		echo "Convert:"
		printf '%s\n' "$TRANSFORM" | sed '/^[[:space:]]*$/d' | awk -F: '{
			printf "  %2d) %-16s %s\n", NR, $1, substr($0, index($0, ":") + 1)
		}'
		printf "Choice (number or name): "
		read -r choice || { echo; echo "No interactive input; pass an option explicitly"; return 1; }
		choice=$(clean_choice "$choice")
		if is_op "$choice"; then
			op=$choice
			return 0
		fi
		if op=$(op_by_number "$choice"); then
			return 0
		fi
		echo "Invalid choice"
	done
}

case "$1" in
-h | --help)
	echo "Usage: $(basename "$0") [option|number] [text]"
	exit 0
	;;
*)
	if is_op "$1"; then
		op=$1
		[ $# -gt 0 ] && shift
	elif op=$(op_by_number "$1"); then
		[ $# -gt 0 ] && shift
	else
		select_op || exit 2
	fi
	;;
esac

[ -n "$op" ] || { echo "Error: no transform selected"; exit 2; }

uv run "$PY_SCRIPT" "$op" "$@"
error=$?

if [ $error -ne 0 ]; then
	echo "Error: conversion failed"
	echo "Press Enter to exit..."
	read -r
fi

exit $error
