#!/bin/sh
# Convert Sublime Text snippets (.sublime-snippet) to VSCode/LuaSnip JSON format
#
# Requirements: python (for XML parsing and JSON generation)
#
# Usage:
#   Windows:
#     Create a .lnk shortcut to this script in the SendTo folder, then:
#     Select .sublime-snippet files > Right-click > Send To > sublime_to_nvim
#
#   Linux (Thunar):
#     Edit > Configure custom actions > Add action with command: /path/to/script.sh %F
#
#   Command line:
#     ./script.sh <snippet1.sublime-snippet> <snippet2.sublime-snippet> ...
#
# Output:
#   For each input file, generates a .json file in the same directory.
#   The JSON format is compatible with LuaSnip's VSCode-style loader.
#
# Scope mapping:
#   Sublime scope (e.g. text.html, source.python) is mapped to VSCode language
#   identifier for the optional "scope" field.

if [ $# -eq 0 ]; then
	echo "Usage: ./script.sh <snippet1.sublime-snippet> ..."
	echo "Press Enter to exit..."
	read
	exit 1
fi

script_dir="$(cd "$(dirname "$0")" && pwd)"

error=0

for file in "$@"; do
	if [ ! -f "$file" ]; then
		echo "Error: File not found: $file"
		error=1
		continue
	fi

	basename_noext=$(basename "$file" .sublime-snippet)
	output="${file%.sublime-snippet}.json"

	if ! python "$script_dir/lib/sublime_to_nvim.py" "$file" "$output"; then
		echo "Error: Failed to convert $file"
		error=1
		continue
	fi

	if [ ! -s "$output" ]; then
		echo "Error: Output empty for $file"
		rm -f "$output"
		error=1
		continue
	fi

	echo "Converted: $file -> $output"
done

if [ $error -ne 0 ]; then
	echo "Press Enter to exit..."
	read
fi

exit $error
