#!/bin/bash
#
# Record a selected window with optional audio.
# Authors: GPT-4o mini🧙‍♂️, scillidan🤡
# Dependences: wmctrl, rofi, xwininfo, ffmpeg

WINDOW_LIST=$(wmctrl -l | awk '{for(i=3;i<=NF;i++) printf $i " "; print ""}')
SELECTED_WINDOW=$(echo "$WINDOW_LIST" | rofi -dmenu -i -p "Select a window")
if [ -z "$SELECTED_WINDOW" ]; then
	echo "No window selected."
	exit 1
fi

SELECTED_WINDOW_ID=$(wmctrl -l | grep "$(echo "$SELECTED_WINDOW" | awk '{$1=""; print $0}')" | awk '{print $1}')
GEOMETRY=$(xwininfo -id "$SELECTED_WINDOW_ID")
if [ -z "$GEOMETRY" ]; then
	echo "Unable to get geometry for the selected window."
	exit 1
fi

X=$(echo "$GEOMETRY" | grep 'Absolute upper-left X' | awk '{print $4}')
Y=$(echo "$GEOMETRY" | grep 'Absolute upper-left Y' | awk '{print $4}')
WIDTH=$(echo "$GEOMETRY" | grep 'Width' | awk '{print $2}')
HEIGHT=$(echo "$GEOMETRY" | grep 'Height' | awk '{print $2}')
echo "Selected Window ID: $SELECTED_WINDOW_ID"
echo "X: $X, Y: $Y, WIDTH: $WIDTH, HEIGHT: $HEIGHT"
SCREEN_WIDTH=1920
SCREEN_HEIGHT=1080
if [[ "$X" -lt 0 || "$Y" -lt 0 || "$WIDTH" -le 0 || "$HEIGHT" -le 0 || "$X" -ge "$SCREEN_WIDTH" || "$Y" -ge "$SCREEN_HEIGHT" ]]; then
	echo "Invalid geometry: X, Y, WIDTH, HEIGHT must be within the screen limits."
	exit 1
fi

RECORD_OPTION=$(echo -e "Record video and audio\nRecord video only" | rofi -dmenu -i -p "Select recording option")
if [ -z "$RECORD_OPTION" ]; then
	echo "No recording option selected."
	exit 1
fi
if [[ "$RECORD_OPTION" == "Record video and audio" ]]; then
	AUDIO_INPUT="-f alsa -ac 2 -i default"
elif [[ "$RECORD_OPTION" == "Record video only" ]]; then
	AUDIO_INPUT=""
else
	echo "Invalid option selected."
	exit 1
fi

OUTPUT_PATH="/home/$(whoami)/Downloads/$(date +%Y-%m-%d_%H-%M-%S).mkv"
if [ -n "$AUDIO_INPUT" ]; then
	ffmpeg -f x11grab -framerate 30 -video_size ${WIDTH}x${HEIGHT} -i :0.0+$X,$Y $AUDIO_INPUT -c:v libx264 "$OUTPUT_PATH"
else
	ffmpeg -f x11grab -framerate 30 -video_size ${WIDTH}x${HEIGHT} -i :0.0+$X,$Y -c:v libx264 "$OUTPUT_PATH"
fi
