#!/bin/sh
# Fit image into A4 (2476x3504) canvas with black background
#
# Pipeline: [rotate 90] -> fit height <=3404 -> fit width >=2376 -> canvas 2476x3504 black center
#
# Usage:
#   Windows:
#     Create a .lnk shortcut to this script in the SendTo folder, then:
#     Select files > Right-click > Send To > imgs_to_a4
#
#   Linux (Thunar):
#     Edit > Configure custom actions > Add action with command: /path/to/script.sh %F
#
#   Command line:
#     ./script.sh <img1> <img2> ...

if [ $# -eq 0 ]; then
	echo "Error: No files selected"
	echo "Press Enter to exit..."
	read
	exit 1
fi

echo "1. No rotation (default)"
echo "2. Rotate 90 first"
printf "Select (default 1): "
read rotate_choice
rotate_choice=${rotate_choice:-1}

if [ "$rotate_choice" = "2" ]; then
	rotate_ops="-rotate 90"
	suffix="_h3504w2476bbr"
else
	rotate_ops=""
	suffix="_h3504w2476bb"
fi

error=0

for file in "$@"; do
	dir=$(dirname "$file")
	name=$(basename "$file" | sed 's/\.[^.]*$//')
	output="$dir/${name}${suffix}_${file##*.}"

	if ! magick "$file" \
		$rotate_ops \
		-resize 'x3404>' \
		-resize '2376x<' \
		-background black -gravity center -extent 2476x3504 \
		"$output"; then
		echo "Error: Failed to process $file"
		error=1
	fi
done

if [ $error -ne 0 ]; then
	echo "Press Enter to exit..."
	read
else
	printf "\nAll done. "
	read -t 3 -p "Closing in 3s..." 2>/dev/null || echo ""
fi

exit $error
