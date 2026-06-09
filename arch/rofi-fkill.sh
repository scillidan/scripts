#!/bin/bash
# Select and kill processes with rofi.
# Authors: GPT-4o mini🧙‍♂️, scillidan🤡
# Dependences: ps, sed, rofi, awk, kill
# Usage: ./script.sh

# List all processes except header line
lines=$(ps -ef | sed 1d)

# Use rofi dmenu for multiple selection with a prompt
selected_lines=$(echo "$lines" | rofi -dmenu -multi-select -i -p "Kill process(es)")

# If no selection, exit
if [[ -z "$selected_lines" ]]; then
	echo "No process selected."
	exit 1
fi

# Extract PIDs from the selected lines (second column)
pids=$(echo "$selected_lines" | awk '{print $2}')

# Kill selected PIDs with signal (default SIGKILL, signal 9)
kill -9 $pids 2>/dev/null

# Optional: print confirmation
echo "Killed process(es): $pids"
