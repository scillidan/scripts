#!/bin/sh
# Extract selected pages from PDFs into one new PDF per input file.
# Page syntax: single pages, ranges, or comma-separated lists, e.g.
#   1 ; 1-3 ; 1,3 ; 1,3-5,8
#
# Usage:
#   Windows:
#     Create a .lnk shortcut to this script in the SendTo folder, then:
#     Select PDF files > Right-click > Send To > pdfs_extract
#
#   Linux (Thunar):
#     Edit > Configure custom actions > Add action with command: /path/to/script.sh %F
#
#   Command line:
#     ./script.sh <pdf1> <pdf2> ...

SCRIPT_DIR=$(dirname "$(readlink -f "$0" 2>/dev/null || echo "$0")")
PY_SCRIPT="$SCRIPT_DIR/lib/pdf_extract.py"

error=0

if [ $# -eq 0 ]; then
	echo "Error: No PDF files selected"
	echo "Press Enter to exit..."
	read
	exit 1
fi

for file in "$@"; do
	ext=".${file##*.}"
	case "$ext" in
	.pdf | .PDF) ;;
	*)
		echo "Error: Not a PDF file: $file"
		echo "Press Enter to exit..."
		read
		exit 1
		;;
	esac
done

printf "Pages to extract (e.g. 1 ; 1-3 ; 1,3): "
read pages

if [ -z "$pages" ]; then
	echo "Error: No pages specified"
	echo "Press Enter to exit..."
	read
	exit 1
fi

if ! uv run "$PY_SCRIPT" -p "$pages" "$@"; then
	error=1
fi

if [ $error -ne 0 ]; then
	echo "Press Enter to exit..."
	read
fi

exit $error
