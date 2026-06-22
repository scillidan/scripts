#!/bin/sh
# Dewarp / straighten document images or PDFs using py-reform
#
# Usage:
#   Windows:
#     Create a .lnk shortcut to this script in the SendTo folder, then:
#     Select files > Right-click > Send To > reform_cli
#
#   Linux (Thunar):
#     Edit > Configure custom actions > Add action with command: /path/to/script.sh %F
#
#   Command line:
#     ./script.sh <img_or_pdf1> <img_or_pdf2> ...

script_dir="$(cd "$(dirname "$0")" && pwd)"

echo "Select model:"
echo "  1) deskew - For scanned PDFs with rotation (faster, recommended)"
echo "  2) uvdoc  - For curved/warped pages (slower, more powerful)"
echo ""
printf "Choice [1]: "
read choice

case "$choice" in
    2|uvdoc)
        model="uvdoc"
        echo ""
        echo "Select device:"
        echo "  1) auto  - Auto detect (default)"
        echo "  2) cpu   - Force CPU"
        printf "Choice [1]: "
        read device_choice
        case "$device_choice" in
            2) device="cpu" ;;
            *) device="auto" ;;
        esac
        model_opts="--model uvdoc --device $device"
        ;;
    *)
        model="deskew"
        echo ""
        echo "Max rotation angle (higher = allow more rotation):"
        echo "  1) 15.0  - Default, suitable for most scans"
        echo "  2) 30.0  - For pages with larger tilt"
        echo "  3) 45.0  - For severely tilted pages"
        printf "Choice [1]: "
        read angle_choice
        case "$angle_choice" in
            2) max_angle=30.0 ;;
            3) max_angle=45.0 ;;
            *) max_angle=15.0 ;;
        esac
        model_opts="--model deskew --max-angle $max_angle"
        ;;
esac

echo ""
echo "Options: $model_opts"
echo ""

error=0

for file in "$@"; do
    if ! uv run "$script_dir/../lib/reform_cli.py" --input "$file" $model_opts; then
        echo "Error: Failed to process $file"
        error=1
    fi
done

if [ $error -ne 0 ]; then
    echo "Press Enter to exit..."
    read
fi