#!/bin/sh
# Print TTF font metadata (font-family, font-weight, font-style)
#
# Usage:
#   Windows:
#     Create a .lnk shortcut to this script in the SendTo folder, then:
#     Select files > Right-click > Send To > fonttools_ttfs
#
#   Linux (Thunar):
#     Edit > Configure custom actions > Add action with command: /path/to/script.sh %F
#
#   Command line:
#     ./script.sh <ttf1> <ttf2> ...

error=0
script_dir="$(dirname "$(readlink -f "$0")")"

for file in "$@"; do
	if [ -f "$file" ]; then
		if ! python "$script_dir/lib/fonttools_ttfs.py" "$file"; then
			echo "Error: Failed to process $file"
			error=1
		fi
	fi
done

echo ""
echo "Press Enter to exit..."
read