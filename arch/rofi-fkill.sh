#!/bin/bash
#
# Select and kill processes with rofi.
# Authors: GPT-4o mini🧙‍♂️, scillidan🤡
# Dependences: ps, sed, rofi, awk, kill

lines=$(ps -ef | sed 1d)

selected_lines=$(echo "$lines" | rofi -dmenu -multi-select -i -p "Kill process(es)")

if [[ -z "$selected_lines" ]]; then
	echo "No process selected."
	exit 1
fi

pids=$(echo "$selected_lines" | awk '{print $2}')

kill -9 $pids 2>/dev/null

echo "Killed process(es): $pids"