#!/bin/sh
# Remove cover art (APIC) from MP3 files while preserving all other metadata
#
# Usage:
#   Windows:
#     Create a .lnk shortcut to this script in the SendTo folder, then:
#     Select files > Right-click > Send To > auds_rm_cover
#
#   Linux (Thunar):
#     Edit > Configure custom actions > Add action with command: /path/to/script.sh %F
#
#   Command line:
#     ./script.sh <mp31> <mp32> ...

error=0

for file in "$@"; do
    case "$file" in
    *.*) ;;
    *)
        echo "Skip (no extension): $file"
        error=1
        continue
        ;;
    esac
    dir=$(dirname "$file")
    ext="${file##*.}"
    name=$(basename "$file" ".$ext")
    temp="$dir/${name}_tmp.$ext"
    backup="$dir/${name}.${ext}.bak"

    echo "Processing: $file"

    # -map 0:a            : select only audio streams
    # -map_metadata 0     : copy all metadata (ID3 tags)
    # -dn                 : discard all data streams (covers / APIC)
    # -c:a copy           : do not re-encode audio
    if ! ffmpeg -y -i "$file" \
         -map 0:a \
         -map_metadata 0 \
         -dn \
         -c:a copy \
         "$temp" 2>/dev/null; then
        echo "Error: FFmpeg failed for $file"
        rm -f "$temp"
        error=1
        continue
    fi

    # Safety check
    if [ ! -s "$temp" ]; then
        echo "Error: Output file is empty"
        rm -f "$temp"
        error=1
        continue
    fi

    mv "$file" "$backup" &&
    mv "$temp" "$file" ||
    {
        echo "Error: Failed to replace original file, restoring backup"
        mv "$backup" "$file"
        error=1
        continue
    }

    rm -f "$backup"
    echo "Cover removed: $file"
done

[ "$error" -ne 0 ] && echo "Press Enter to exit..." && read

exit $error