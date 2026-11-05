#!/bin/sh
# OCR image-based subtitles to SRT via seconv (Tesseract engine)
#
# Handles Blu-ray .sup, VobSub .sub/.idx, and image tracks inside mkv/mp4/ts/avi.
# For text tracks use subs_format.sh instead.
#
# Usage:
#   Windows:
#     Create a .lnk shortcut to this script in the SendTo folder, then:
#     Select files > Right-click > Send To > subs_ocr
#
#   Linux (Thunar):
#     Edit > Configure custom actions > Add action with command: /path/to/script.sh %F
#
#   Command line:
#     ./script.sh <sup1> <mkv1> ...
#
# Requires: seconv (Subtitle Edit CLI), tesseract (+ language packs)

if [ $# -eq 0 ]; then
	echo "Error: No files selected"
	echo "Press Enter to exit..."
	read
	exit 1
fi

if ! command -v seconv >/dev/null 2>&1; then
	echo "Error: seconv not found (https://subtitleedit.github.io/subtitleedit/reference/command-line.html)"
	echo "Press Enter to exit..."
	read
	exit 1
fi

if ! command -v tesseract >/dev/null 2>&1; then
	echo "Error: tesseract not found (needed by the seconv OCR engine)"
	echo "Press Enter to exit..."
	read
	exit 1
fi

LANGS=$(tesseract --list-langs 2>/dev/null | sed -n '2,$p' | tr -d '\r')
if [ -z "$LANGS" ]; then
	echo "Error: No tesseract language packs found"
	echo "Press Enter to exit..."
	read
	exit 1
fi

select_language() {
	while true; do
		echo ""
		echo "OCR Language"
		echo "----------------------------------------"
		num=1
		for code in $LANGS; do
			printf "%3d) %s\n" "$num" "$code"
			num=$((num + 1))
		done
		echo ""
		printf "Enter number or code (e.g. eng, chi_sim, eng+chi_sim): "
		read choice

		if [ -z "$choice" ]; then
			echo "Error: Selection required"
			continue
		fi

		case "$choice" in
		*[!0-9]*)
			LANG="$choice"
			return
			;;
		*)
			LANG=$(printf '%s\n' "$LANGS" | sed -n "${choice}p")
			if [ -z "$LANG" ]; then
				echo "Error: Invalid number"
				continue
			fi
			return
			;;
		esac
	done
}

select_language
printf "\nOCR language: %s\n" "$LANG"

error=0

for file in "$@"; do
	if [ ! -f "$file" ]; then
		echo "Error: Not found: $file"
		error=1
		continue
	fi

	printf "\n--- %s ---\n" "$file"
	if ! out=$(seconv "$file" subrip \
		--ocr-engine:tesseract \
		--ocr-language:"$LANG" \
		--no-language-suffix --overwrite --encoding:utf-8-no-bom 2>&1); then
		echo "Error: Failed to OCR $file"
		printf '%s\n' "$out" | tail -5
		error=1
		continue
	fi
	echo "Done: $file"
done

if [ $error -ne 0 ]; then
	echo ""
	echo "Press Enter to exit..."
	read
else
	printf "\nAll done. "
	read -t 3 -p "Closing in 3s..." 2>/dev/null || echo ""
fi

exit $error
