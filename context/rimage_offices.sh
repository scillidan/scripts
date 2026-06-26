#!/bin/sh
# Compress images in Office documents (docx/pptx/xlsx) using rimage
#
# Usage:
#   Windows:
#     Create a .lnk shortcut to this script in the SendTo folder, then:
#     Select files > Right-click > Send To > rimage_office
#
#   Linux (Thunar):
#     Edit > Configure custom actions > Add action with command: /path/to/script.sh %F
#
#   Command line:
#     ./script.sh <office1> <office2> ...

if [ $# -eq 0 ]; then
    echo "Error: No files selected"
    echo "Press Enter to exit..."
    read
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
error=0

for file in "$@"; do
    ext=".${file##*.}"
    case "$ext" in
        .docx|.DOCX|.pptx|.PPTX|.xlsx|.XLSX)
            echo "Processing: $file"
            if ! uv run "$SCRIPT_DIR/lib/rimage_office.py" "$file"; then
                error=1
            fi
            ;;
        *)
            echo "Error: Unsupported format for $file"
            error=1
            ;;
    esac
done

if [ $error -ne 0 ]; then
    echo "Press Enter to exit..."
    read
else
    printf "\nAll done. "
    read -t 3 -p "Closing in 3s..." 2>/dev/null || echo ""
fi

exit $error
