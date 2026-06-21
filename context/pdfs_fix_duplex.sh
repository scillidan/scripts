#!/bin/sh
# Fix PDF page order from non-duplex scanning (2-file mode)
# Select exactly 2 PDFs -> sorted alphabetically: A=odd pages, B=even pages
#
# Usage:
#   Windows:
#     Create a .lnk shortcut to this script in the SendTo folder, then:
#     Select 2 files > Right-click > Send To > pdfs_fix_duplex
#
#   Linux (Thunar):
#     Edit > Configure custom actions > Add action with command: /path/to/script.sh %F
#
#   Command line:
#     ./pdfs_fix_duplex.sh <a.pdf> <b.pdf>

if [ $# -ne 2 ]; then
    echo "Error: Please select exactly 2 PDF files"
    echo "Press Enter to exit..."
    read
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

for file in "$1" "$2"; do
    ext=".${file##*.}"
    case "$ext" in
        .pdf|.PDF) ;;
        *)
            echo "Error: Not a PDF file: $file"
            echo "Press Enter to exit..."
            read
            exit 1
            ;;
    esac
done

echo "Fixing duplex order..."
echo ""

if uv run "$SCRIPT_DIR/lib/pdf_fix_duplex.py" "$1" "$2"; then
    echo ""
    printf "All done. "
    read -t 3 -p "Closing in 3s..." 2>/dev/null || echo ""
else
    echo "Press Enter to exit..."
    read
    exit 1
fi
