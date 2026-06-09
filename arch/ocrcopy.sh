#!/bin/bash
# Write by GPT-4o mini🧙‍♂️, scillidan🤡
# Capture a screenshot, perform OCR, and copy the result to clipboard.
# Dependences: scrot, imagemagick, tesseract, xclip, dunst
# Usage: ./script.sh

set -euo pipefail

# Temporary files
TMP_BASE=$(mktemp -u)
trap 'rm -f "${TMP_BASE}"*' EXIT

# 1. Let user select an area on the screen
scrot -s "${TMP_BASE}.png"
if [[ ! -f "${TMP_BASE}.png" ]]; then
	notify-send -u low "OCR" "Screenshot was cancelled."
	exit 1
fi

# 2. Enhance image to improve OCR accuracy (boost contrast & resize)
mogrify -modulate 100,0 -resize 400% "${TMP_BASE}.png"

# 3. OCR with English and Simplified Chinese
tesseract "${TMP_BASE}.png" "${TMP_BASE}" -l eng+chi_sim &>/dev/null

# 4. Read OCR output
OCR_TEXT=$(cat "${TMP_BASE}.txt" | tr -d '\014' | sed '/^\s*$/d')

if [[ -z "$OCR_TEXT" ]]; then
	notify-send -u normal "OCR Result" "No text detected."
	exit 0
fi

# 5. Copy OCR text to clipboard
echo -n "$OCR_TEXT" | xclip -selection clipboard

# 6. Show notification with OCR text preview (truncate if too long)
MAX_LEN=200
if [ ${#OCR_TEXT} -gt $MAX_LEN ]; then
	DISPLAY_TEXT="${OCR_TEXT:0:$MAX_LEN}..."
else
	DISPLAY_TEXT="$OCR_TEXT"
fi

notify-send -u normal -t 10000 "OCR Result (copied to clipboard)" "$DISPLAY_TEXT"
