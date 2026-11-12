#!/bin/sh
# Flatten bitmap PDFs for printing: 1-bit black/white images, no color profile,
# standard paper size. Removes the file-side causes of a gray background on paper.
#
# Usage:
#   Windows:
#     Create a .lnk shortcut to this script in the SendTo folder, then:
#     Select files > Right-click > Send To > pdfs_fix_brightness
#
#   Linux (Thunar):
#     Edit > Configure custom actions > Add action with command: /path/to/script.sh %F
#
#   Command line:
#     ./script.sh <pdf1> <pdf2> ...

SCRIPT_DIR=$(dirname "$(readlink -f "$0" 2>/dev/null || echo "$0")")
PY_SCRIPT="$SCRIPT_DIR/lib/pdfs_fix_brightness.py"

error=0

if [ $# -eq 0 ]; then
	echo "Error: No PDF files selected"
	echo "Press Enter to exit..."
	read -r _
	exit 1
fi

for file in "$@"; do
	ext=".${file##*.}"
	case "$ext" in
	.pdf | .PDF) ;;
	*)
		echo "Error: Not a PDF file: $file"
		echo "Press Enter to exit..."
		read -r _
		exit 1
		;;
	esac
	if [ ! -f "$file" ] || [ ! -r "$file" ]; then
		echo "Error: File not found or not readable: $file"
		echo "Press Enter to exit..."
		read -r _
		exit 1
	fi
done

printf "Paper [a4/a3/a4r/letter/b5 or WxH in pt] (default a4): "
read -r paper
paper=${paper:-a4}

echo ""
echo "Orientation:"
echo "  1. portrait (default)"
echo "  2. landscape"
printf "Select [1-2] (default 1): "
read -r orientation
case "${orientation:-1}" in
1) landscape=0 ;;
2) landscape=1 ;;
*)
	echo "Error: Invalid orientation choice"
	echo "Press Enter to exit..."
	read -r _
	exit 1
	;;
esac

printf "Threshold 0-255, lower keeps more white (default 128): "
read -r threshold
threshold=${threshold:-128}
case "$threshold" in
'' | *[!0-9]*)
	echo "Error: Threshold must be a number between 0 and 255"
	echo "Press Enter to exit..."
	read -r _
	exit 1
	;;
esac
if [ "$threshold" -gt 255 ]; then
	echo "Error: Threshold must be between 0 and 255"
	echo "Press Enter to exit..."
	read -r _
	exit 1
fi

echo ""
echo "Flattening..."

set -- --paper "$paper" --threshold "$threshold" "$@"
if [ "$landscape" -eq 1 ]; then
	set -- --landscape "$@"
fi

if ! uv run "$PY_SCRIPT" "$@"; then
	error=1
fi

if [ $error -ne 0 ]; then
	echo "Press Enter to exit..."
	read -r _
fi

exit $error
