#!/bin/sh
#
# Usage:
#   Windows:
#     Create a .lnk shortcut to this script in the SendTo folder, then:
#     Run it, or drop text on it: the text is chosen in the menu.
#
#   Command line:
#     ./script.sh [1-14|name] [text]     (no text: clipboard; no tool: menu)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PY_SCRIPT="$SCRIPT_DIR/lib/puzz_tool.py"

# index:tool:description
TOOLS='
1:delquery:delete after ?
2:delspace:remove all whitespace
3:ghcommitsatom:repo url -> its commits atom feed
4:ghreleasesatom:repo url -> its releases atom feed
5:ghurlapi:https://github.com/o/r -> https://api.github.com/repos/o/r
6:ghurlraw:blob url -> raw.githubusercontent.com url
7:ghurlshorter:repo url -> owner/repo
8:linessplitbycomma:lines -> one lowercase comma list
9:scoopwhere:Scoop shims\app.exe -> apps\app\current\app.exe
10:typstsearch:packages/preview/name/... -> universe search url
11:unixlink:backslashes -> slashes
12:unixlink2:double backslashes -> slashes
13:windowslink:slashes -> backslashes
14:windowslink2:backslashes -> double backslashes
'

lookup() { # 1: index or name -> prints the tool name
	printf '%s\n' "$TOOLS" | while IFS=: read -r n name _; do
		if [ "$n" = "$1" ] || [ "$name" = "$1" ]; then
			echo "$name"
			break
		fi
	done
}

select_tool() {
	while :; do
		echo "Convert:"
		printf '%s\n' "$TOOLS" | while IFS=: read -r n name desc; do
			[ -n "$n" ] && printf '  %2s) %-13s %s\n' "$n" "$name" "$desc"
		done
		printf "Choice: "
		read choice
		tool=$(lookup "$choice")
		[ -n "$tool" ] && return
		echo "Invalid choice"
	done
}

case "$1" in
-h | --help)
	echo "Usage: $(basename "$0") [1-14|name] [text]"
	exit 0
	;;
*)
	tool=$(lookup "$1")
	if [ -n "$tool" ]; then
		shift
	else
		select_tool
	fi
	;;
esac

if [ $# -gt 0 ]; then
	uv run "$PY_SCRIPT" "$tool" "$@"
else
	uv run "$PY_SCRIPT" "$tool"
fi
error=$?

if [ $error -ne 0 ]; then
	echo "Error: conversion failed"
	echo "Press Enter to exit..."
	read
fi

exit $error
