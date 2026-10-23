#!/bin/sh
# Remove EXIF/metadata from images and other media files (like ExifCleaner)
# Works on anything exiftool supports: jpg/png/gif/tiff/webp/avif,
# mp4/mov/mkv, mp3/m4a/flac, pdf, docx...
#
# Usage:
#   Windows:
#     Create a .lnk shortcut to this script in the SendTo folder, then:
#     Select files > Right-click > Send To > imgs_rm_exif
#
#   Linux (Thunar):
#     Edit > Configure custom actions > Add action with command: /path/to/script.sh %F
#
#   Command line:
#     ./script.sh <file1> <file2> ...
#
# Requires: exiftool

if [ $# -eq 0 ]; then
	echo "Error: No files selected"
	echo "Press Enter to exit..."
	read
	exit 1
fi

error=0

for file in "$@"; do
	echo "Processing: $file"

	if ! exiftool -all= -overwrite_original "$file" >/dev/null 2>&1; then
		echo "Error: Failed to clean $file"
		error=1
		continue
	fi

	echo "Metadata removed: $file"
done

if [ $error -ne 0 ]; then
	echo "Press Enter to exit..."
	read
else
	printf "\nAll done. "
	read -t 3 -p "Closing in 3s..." 2>/dev/null || echo ""
fi

exit $error
