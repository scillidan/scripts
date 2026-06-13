#!/bin/sh
# Convert English PGS files to SRT format
#
# Notes:
#   scoop install https://github.com/scillidan/scoop-pile/raw/refs/heads/master/bucket/pgstosrt.json
#   scoop install tesseract tesseract-languages
#
# Usage:
#   Windows:
#     Create a .lnk shortcut to this script in the SendTo folder, then:
#     Select files > Right-click > Send To > sups_to_srts_en
#
#   Linux (Thunar):
#     Edit > Configure custom actions > Add action with command: /path/to/script.sh %F
#
#   Command line:
#     ./script.sh <sup1> <sup2> ...

error=0

if [ -z "$TESSDATA_PREFIX" ]; then
    echo "Error: TESSDATA_PREFIX is not set"
    exit 1
fi

if ! command -v pgstosrt >/dev/null 2>&1; then
    echo "Error: pgstosrt not found"
    exit 1
fi

for file in "$@"; do
    output="${file%.*}.srt"
    echo "Converting: $file"

    if ! pgstosrt \
        --input "$file" \
        --output "$output" \
        --tesseractlanguage eng \
        --tesseractdata "$TESSDATA_PREFIX"
    then
        echo "Failed: $file"
        error=1
    fi
done

[ $error -ne 0 ] && echo "Press Enter to exit..." && read

exit $error