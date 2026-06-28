#!/usr/bin/env sh
# Inspired by https://github.com/soulim/bookmarks.txt

set -o errexit
set -o nounset

url=${1:-}
title=${2:-}
tag=${3:-}

if [ -n "$url" ]
then
	echo "$url $title - $tag" >> bookmarks.bkm
else
	global="$USERHOME/Share/files/bookmarks"
	files=$(find "$global" -maxdepth 1 \( -name '*.bkm' -o -name '*.txt' \) ! -name '*.bak' | sort)

	selection=$(cat $files | fzf --multi --height=80%)
	if [ -z "$selection" ]; then
		exit 0
	fi
	echo "$selection" | while IFS= read -r line; do
		url=$(echo "$line" | awk '{print $1}')
		"$BROWSER" "$url"
	done
fi
