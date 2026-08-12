#!/bin/sh
# Convert PDF pages to image format (JPG default, PNG optional)
#
# Usage:
#   Windows:
#     Create a .lnk shortcut to this script in the SendTo folder, then:
#     Select files > Right-click > Send To > pdfs_to_imgs
#
#   Linux (Thunar):
#     Edit > Configure custom actions > Add action with command: /path/to/script.sh %F
#
#   Command line:
#     ./script.sh <pdf1> <pdf2> ...

error=0

printf "Enter page number (default=1): "
read page
page=${page:-1}
imgpage=$((page - 1))

printf "Enter format [jpg/png] (default=jpg): "
read format
format=${format:-jpg}
case "$format" in
jpg | jpeg)
	ext=jpg
	opts="-quality 90"
	;;
png)
	ext=png
	opts="-define png:compression-level=9"
	;;
*)
	echo "Invalid format: $format (use jpg or png)"
	echo "Press Enter to exit..."
	read
	exit 1
	;;
esac

for file in "$@"; do
	base="${file%.*}"
	if ! magick -density 300 "${file}[${imgpage}]" $opts -alpha remove "${base}_p${page}.${ext}"; then
		echo "Error: Failed to convert $file"
		error=1
	fi
done

if [ $error -ne 0 ]; then
	echo "Press Enter to exit..."
	read
fi

exit $error
