#!/bin/bash
# Create an image with a caption via interactive prompts.
# Run directly and follow the prompts; output is written to the current working directory.

font="/c/Users/User/Scoop/apps/Sarasa-Mono-SC/current/SarasaMonoSC-Regular.ttf"
error=0

printf "Image size (e.g. 800x600): "
read img_size

printf "Caption: "
read caption

if [ -z "$img_size" ] || [ -z "$caption" ]; then
	echo "Error: Image size and caption are required."
	error=1
else
	kebab_caption=$(echo "$caption" | tr ' ' '-')
	output_file="${kebab_caption}.png"

	if ! magick -size "$img_size" \
		-background "#000000" \
		-fill "#fffff8" \
		-font "$font" \
		-gravity Center \
		-pointsize 20 \
		-interline-spacing 2 \
		caption:"$caption" \
		"$output_file" 2>/dev/null; then
		echo "Error: Failed to generate image."
		error=1
	else
		echo "Created: $output_file"
	fi
fi

if [ $error -ne 0 ]; then
	echo "Press Enter to exit..."
	read
fi

exit $error
