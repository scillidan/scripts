#!/bin/sh
# Whiten the gray background of scanned PDFs so paper prints white and saves ink.
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

echo ""
echo "Output mode:"
echo "  1. clean  - keep gray tones (default)"
echo "  2. binary - pure black and white, least ink"
printf "Select [1-2] (default 1): "
read -r mode_choice
case "${mode_choice:-1}" in
1) mode=clean ;;
2) mode=binary ;;
*)
	echo "Error: Invalid mode choice"
	echo "Press Enter to exit..."
	read -r _
	exit 1
	;;
esac

echo ""
echo "Whitening..."

if ! uv run "$PY_SCRIPT" --mode "$mode" "$@"; then
	error=1
fi

if [ $error -ne 0 ]; then
	echo "Press Enter to exit..."
	read -r _
fi

exit $error
