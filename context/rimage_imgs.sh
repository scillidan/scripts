#!/bin/sh
# Optimize and resize images using Rimage (static) and gifsicle (animated GIF)
# SVG files are skipped.
# If optimization makes a file larger, the original is restored.
#
# Usage:
#   Windows:
#     Create a .lnk shortcut to this script in the SendTo folder, then:
#     Select files > Right-click > Send To > rimage_imgs
#
#   Linux (Thunar):
#     Edit > Configure custom actions > Add action with command: /path/to/script.sh %F
#
#   Command line:
#     ./script.sh <img1> <img2> ...

# Requires: rimage, gifsicle (for GIF)

get_encoder() {
	case "$1" in
	.jpg | .JPG | .jpeg | .JPEG) echo "mozjpeg" ;;
	.png | .PNG) echo "oxipng" ;;
	.webp | .WEBP) echo "webp" ;;
	.avif | .AVIF) echo "avif" ;;
	.gif | .GIF) echo "gif" ;;
	.svg | .SVG) echo "skip" ;;
	*) echo "" ;;
	esac
}

human_size() {
	size=$1
	if [ "$size" -ge 1048576 ]; then
		echo "$((size / 1048576))MB"
	elif [ "$size" -ge 1024 ]; then
		echo "$((size / 1024))KB"
	else
		echo "${size}B"
	fi
}

if [ $# -eq 0 ]; then
	echo "Error: No files selected"
	echo "Press Enter to exit..."
	read
	exit 1
fi

echo "1. Just optimize"
echo "2. Resize to 1080px height if needed"
printf "Select (Default 1): "
read mode
mode=${mode:-1}

error=0
skip_count=0

for file in "$@"; do
	ext=".${file##*.}"
	encoder=$(get_encoder "$ext")

	if [ "$encoder" = "skip" ]; then
		echo "Skip: $file (SVG)"
		skip_count=$((skip_count + 1))
		continue
	fi

	if [ "$encoder" = "gif" ]; then
		gif_args="-O3 --lossy=80"
		if [ "$mode" = "2" ]; then
			gif_args="$gif_args --resize-fit 9999x1080"
		fi

		dir=$(dirname "$file")
		name=$(basename "$file" | sed 's/\.[^.]*$//')
		output="$dir/${name}_optimized.gif"

		orig_size=$(wc -c <"$file" 2>/dev/null)
		if ! gifsicle $gif_args -o "$output" "$file" 2>/dev/null; then
			echo "Error: Failed to optimize $file"
			error=1
			continue
		fi
		new_size=$(wc -c <"$output" 2>/dev/null)

		if [ -z "$new_size" ] || [ "$new_size" -gt "$orig_size" ]; then
			echo "Skip: $(basename "$file") ($(human_size "$orig_size") -> $(human_size "${new_size:-0}") larger)"
			rm -f "$output"
			skip_count=$((skip_count + 1))
		else
			pct=$((100 * (orig_size - new_size) / orig_size))
			echo "OK: $(basename "$file") ($(human_size "$orig_size") -> $(human_size "$new_size"), -${pct}%)"
			mv "$output" "$file"
		fi
		continue
	fi

	if [ -z "$encoder" ]; then
		echo "Error: Unsupported format for $file"
		error=1
		continue
	fi

	resize_args=""
	if [ "$mode" = "2" ]; then
		resize_args="--resize 1080h --downscale --no-upscale"
	fi

	orig_size=$(wc -c <"$file" 2>/dev/null)
	backup="${file}.bak"
	cp "$file" "$backup"

	if ! rimage "$encoder" $resize_args "$file" 2>/dev/null; then
		echo "Error: Failed to optimize $file"
		rm -f "$backup"
		error=1
		continue
	fi

	new_size=$(wc -c <"$file" 2>/dev/null)

	if [ -z "$new_size" ] || [ "$new_size" -gt "$orig_size" ]; then
		echo "Skip: $(basename "$file") ($(human_size "$orig_size") -> $(human_size "${new_size:-0}") larger)"
		mv "$backup" "$file"
		skip_count=$((skip_count + 1))
	else
		pct=$((100 * (orig_size - new_size) / orig_size))
		echo "OK: $(basename "$file") ($(human_size "$orig_size") -> $(human_size "$new_size"), -${pct}%)"
		rm -f "$backup"
	fi
done

if [ $skip_count -gt 0 ]; then
	echo ""
	echo "Skipped $skip_count files (SVG or larger after optimization)"
fi

if [ $error -ne 0 ]; then
	echo "Press Enter to exit..."
	read
else
	printf "\nAll done. "
	read -t 3 -p "Closing in 3s..." 2>/dev/null || echo ""
fi

exit $error
