#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat <<EOF
Usage: bash crop-black-border.sh <input> [--output <path>] [--crf <0-51>]

Crop black borders from video via ffmpeg auto-detection.
Output is always MP4 (x264 + copy audio).

Options:
  --output <path>  Output path (default: <name>_crop.mp4)
  --crf <0-51>     Quality: 0 = lossless, 4-6 = visually lossless (default: 0)
  -h, --help       Show this help
EOF
    exit "${1:-0}"
}

input=""
output=""
crf=0

while [[ $# -gt 0 ]]; do
    case $1 in
        --output) output="$2"; shift 2 ;;
        --crf) crf="$2"; shift 2 ;;
        -h|--help) usage 0 ;;
        -*) echo "Unknown option: $1"; usage 1 ;;
        *) input="$1"; shift ;;
    esac
done

[[ -z "$input" ]] && { echo "Error: input required"; usage 1; }
[[ ! -f "$input" ]] && { echo "Error: file not found: $input"; exit 1; }

echo "Detecting black borders..."

crop=$(ffmpeg -t 30 -i "$input" -vf cropdetect=limit=24:round=2 -f null - 2>&1 \
    | grep -o 'crop=[0-9:]*' | tail -1 | cut -d= -f2)

[[ -z "$crop" ]] && { echo "Error: could not detect crop values"; exit 1; }

original_size=$(ffprobe -v error -select_streams v:0 \
    -show_entries stream=width,height -of csv=s=x:p=0 "$input")

crop_w=${crop%%:*}
crop_h=${crop#*:}; crop_h=${crop_h%%:*}

if [[ "${crop_w}x${crop_h}" == "$original_size" ]]; then
    echo "No black borders detected ($original_size). Nothing to crop."
    exit 0
fi

echo "Crop: $original_size -> ${crop_w}x${crop_h}"

if [[ -z "$output" ]]; then
    dir=$(dirname "$input")
    name=$(basename "$input" | sed 's/\.[^.]*$//')
    output="${dir}/${name}_crop.mp4"
fi

echo "Encoding (crf=$crf) -> $output"

ffmpeg -i "$input" -vf "crop=$crop" \
    -c:v libx264 -crf "$crf" -preset slow \
    -c:a copy \
    -movflags +faststart \
    "$output"

echo "Done: $output"
