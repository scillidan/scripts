#!/bin/sh
# Embed a cover image into video files that lack thumbnail/cover art.
# This makes Windows Explorer / file managers show a preview thumbnail.
#
# Usage:
#   Windows:
#     Create a .lnk shortcut to this script in the SendTo folder, then:
#     Select files > Right-click > Send To > ffmpeg_fix_thumber
#
#   Linux (Thunar):
#     Edit > Configure custom actions > Add action with command: /path/to/script.sh %F
#
#   Command line:
#     ./script.sh <vid1> <vid2> ...

if [ $# -eq 0 ]; then
	echo "Error: No files selected"
	echo "Press Enter to exit..."
	read
	exit 1
fi

error=0

for file in "$@"; do
	printf "\n--- %s ---\n" "$file"

	if [ ! -f "$file" ]; then
		echo "Error: File not found"
		error=1
		continue
	fi

	has_video=$(ffprobe -v error -select_streams v:0 -show_entries stream=codec_type -of csv=s=x:p=0 "$file" 2>/dev/null | head -1)
	if [ "$has_video" != "video" ]; then
		echo "No video stream, skipping"
		continue
	fi

	cover_count=$(ffprobe -v error -select_streams v -show_entries stream_disposition=attached_pic -of default=noprint_wrappers=1 "$file" 2>/dev/null | awk -F= '$1=="DISPOSITION:attached_pic" && $2==1 {c++} END{print c+0}')
	if [ "$cover_count" -gt 0 ]; then
		echo "Cover art already present, skipping"
		continue
	fi

	dir=$(dirname "$file")
	base=$(basename "$file")
	case "$base" in
	*.*)
		name="${base%.*}"
		ext="${base##*.}"
		;;
	*)
		name="$base"
		ext=""
		;;
	esac

	if [ -z "$ext" ]; then
		fmt=$(ffprobe -v error -show_entries format=format_name -of default=noprint_wrappers=1:nokey=1 "$file" 2>/dev/null | cut -d, -f1)
		case "$fmt" in
		mov | mp4 | m4a | m4v | 3gp | 3g2 | mj2) ext="mp4" ;;
		matroska) ext="mkv" ;;
		avi) ext="avi" ;;
		flv) ext="flv" ;;
		webm) ext="webm" ;;
		*) ext="mkv" ;;
		esac
	fi

	cover="${dir}/${name}_cover_tmp$$.jpg"
	temp="${dir}/${name}_ffmpeg_fix_thumber_tmp$$.${ext}"

	duration=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$file" 2>/dev/null | head -1 | cut -d. -f1)
	if [ -n "$duration" ] && [ "$duration" -gt 0 ]; then
		ss=$((duration / 10))
		[ "$ss" -lt 1 ] && ss=1
		[ "$ss" -gt 5 ] && ss=5
	else
		ss=1
	fi

	echo "Extracting thumbnail at ${ss}s..."
	log=$(mktemp)
	if ! ffmpeg -y -ss "$ss" -i "$file" -vframes 1 -q:v 2 -vf "scale=-1:720" -an -sn "$cover" >"$log" 2>&1; then
		echo "Error: Failed to extract thumbnail"
		tail -5 "$log"
		rm -f "$cover" "$log"
		error=1
		continue
	fi
	rm -f "$log"

	if [ ! -s "$cover" ]; then
		echo "Error: Extracted cover is empty"
		rm -f "$cover"
		error=1
		continue
	fi

	vcount=$(ffprobe -v error -select_streams v -show_entries stream=index -of csv=p=0 "$file" 2>/dev/null | wc -l | tr -d ' ')
	cover_index=${vcount:-1}

	echo "Embedding cover art..."
	log=$(mktemp)
	if ! ffmpeg -y -i "$file" -i "$cover" -map 0 -map 1 -c copy -disposition:v:${cover_index} attached_pic "$temp" >"$log" 2>&1; then
		echo "Error: Failed to embed cover art"
		tail -5 "$log"
		rm -f "$cover" "$temp" "$log"
		error=1
		continue
	fi
	rm -f "$log" "$cover"

	if [ ! -s "$temp" ]; then
		echo "Error: Output file is empty"
		rm -f "$temp"
		error=1
		continue
	fi

	if ! mv "$temp" "$file"; then
		echo "Error: Failed to replace original file"
		rm -f "$temp"
		error=1
		continue
	fi

	echo "Done"
done

if [ $error -ne 0 ]; then
	echo "Press Enter to exit..."
	read
else
	printf "\nAll done. "
	read -t 3 -p "Closing in 3s..." 2>/dev/null || echo ""
fi

exit $error
