#!/bin/sh
# Smart archive extraction/creation — intelligently decide target dir, handle passwords, nested archives
#
# Requirements: 7-Zip (7z)
#
# Usage:
#   Windows:
#     Create a .lnk shortcut to this script in the SendTo folder, then:
#     Select archives/files/folders > Right-click > Send To > smartzip
#
#   Linux (Thunar):
#     Edit > Configure custom actions > Add action with command: /path/to/script.sh %F
#
#   Command line:
#     ./script.sh <archive1> <archive2> ...      # extract
#     ./script.sh -a <file_or_dir1> ...           # create archive(s)
#     ./script.sh --xc=gbk <archive>              # extract with codepage
#     ./script.sh -o <archive>                    # open in 7-Zip FM

if ! command -v 7z >/dev/null 2>&1; then
    echo "Error: 7z not found"
    echo "Press Enter to exit..."
    read
    exit 1
fi

readonly NESTED_EXTS="7z zip rar 001 tar gz bz2 xz lzma Z lzh cab iso wim swm esd msi dmg vhd vmdk vdi"
readonly ARCHIVE_EXTS="7z zip rar 001 tar gz tgz bz2 bz2 xz txz lzma lz Z lzh cab iso wim swm esd msi dmg vhd vmdk vdi arj zst"
readonly RECURSION_MAX=5
readonly DEFAULT_ARCHIVE_EXT="zip"
readonly DELETE_SOURCE_AFTER=false

delete_source() {
    target="$1"
    if [ ! -e "$target" ]; then
        return 0
    fi
    if command -v gio >/dev/null 2>&1; then
        gio trash "$target" 2>/dev/null
    elif [ "$(uname -s)" = "MINGW"* ] || [ "$(uname -s)" = "MSYS"* ]; then
        powershell -NoProfile -Command "
            \$shell = New-Object -ComObject Shell.Application
            foreach (\$item in \$args) {
                \$fso = Get-Item -LiteralPath \$item
                \$folder = \$shell.NameSpace(\$fso.DirectoryName)
                \$folder.ParseName(\$fso.Name).InvokeVerb('delete')
            }
        " -- "$target" 2>/dev/null
    fi
}

probe_archive() {
    archive="$1"
    7z l -slt "$archive" 2>/dev/null | grep -c '^Path = '
}

is_archive() {
    f="$1"
    ext=$(printf "%s" "$f" | sed 's/.*\.//' | tr '[:upper:]' '[:lower:]')
    for e in $ARCHIVE_EXTS; do
        [ "$ext" = "$e" ] && return 0
    done
    return 1
}

confirm_overwrite() {
    dir="$1"
    if [ -d "$dir" ]; then
        printf "Overwrite existing '%s'? [y/N]: " "$(basename "$dir")"
        read ans
        case "$ans" in
            y|Y|yes) rm -rf "$dir" ;;
            *) return 1 ;;
        esac
    fi
    return 0
}

extract_archive() {
    archive="$1"
    codepage="$2"
    depth="${3:-0}"

    if [ ! -f "$archive" ]; then
        echo "Error: File not found: $archive"
        return 1
    fi

    item_count=$(probe_archive "$archive")
    archive_dir=$(dirname "$archive")
    archive_name=$(basename "$archive" | sed 's/\.[^.]*$//')

    if [ "${item_count:-0}" -eq 1 ]; then
        target_dir="$archive_dir"
    else
        target_dir="$archive_dir/$archive_name"
    fi

    echo "Items: $item_count | Target: $target_dir"

    if ! confirm_overwrite "$target_dir"; then
        echo "Skipped"
        return 1
    fi

    cp_opts=""
    [ -n "$codepage" ] && cp_opts="-mcp=$codepage"

    if 7z x -p"" -o"$target_dir" -y $cp_opts "$archive" >/dev/null 2>&1; then
        echo "Extracted"
        if [ "$DELETE_SOURCE_AFTER" = true ]; then
            delete_source "$archive"
        fi
    else
        echo "Error: Failed to extract $archive (possibly password-protected or corrupted)"
        return 1
    fi

    if [ "$depth" -lt "$RECURSION_MAX" ]; then
        handle_nested "$target_dir" "$codepage" "$depth"
    fi

    return 0
}

handle_nested() {
    target_dir="$1"
    codepage="$2"
    depth="$3"
    new_depth=$((depth + 1))

    ext_pattern=""
    for ext in $NESTED_EXTS; do
        [ -n "$ext_pattern" ] && ext_pattern="$ext_pattern -o"
        ext_pattern="$ext_pattern -name '*.$ext'"
    done

    find "$target_dir" -maxdepth 1 -type f \( $ext_pattern \) 2>/dev/null | while IFS= read -r nested; do
        printf "  Nested: %s -> " "$(basename "$nested")"
        if extract_archive "$nested" "$codepage" "$new_depth"; then
            rm -f "$nested"
            echo "  Cleaned: $(basename "$nested")"
        else
            echo "  Skipped: $(basename "$nested")"
        fi
    done
}

create_archive() {
    item="$1"
    outdir=$(dirname "$item" | sed 's|[/\\]$||')
    item_base=$(basename "$item")

    if [ -d "$item" ]; then
        output="$outdir/${item_base}.${DEFAULT_ARCHIVE_EXT}"
        if [ -f "$output" ]; then
            printf "Overwrite existing '%s'? [y/N]: " "$(basename "$output")"
            read ans
            case "$ans" in
                y|Y|yes) rm -f "$output" ;;
                *) echo "Skipped"; return 1 ;;
            esac
        fi
        printf "Creating %s ... " "$(basename "$output")"
        out_abs=$(cd "$outdir" && pwd)
        (cd "$item" && 7z a "$out_abs/${item_base}.${DEFAULT_ARCHIVE_EXT}" .) >/dev/null 2>&1
        if [ $? -eq 0 ]; then
            echo "OK"
            if [ "$DELETE_SOURCE_AFTER" = true ]; then
                delete_source "$item"
            fi
        else
            echo "Error"
            return 1
        fi
    else
        name_noext=$(printf "%s" "$item_base" | sed 's/\.[^.]*$//')
        output="$outdir/${name_noext}.${DEFAULT_ARCHIVE_EXT}"
        if [ -f "$output" ]; then
            printf "Overwrite existing '%s'? [y/N]: " "$(basename "$output")"
            read ans
            case "$ans" in
                y|Y|yes) rm -f "$output" ;;
                *) echo "Skipped"; return 1 ;;
            esac
        fi
        printf "Creating %s ... " "$(basename "$output")"
        if 7z a "$output" "$item" >/dev/null 2>&1; then
            echo "OK"
            if [ "$DELETE_SOURCE_AFTER" = true ]; then
                delete_source "$item"
            fi
        else
            echo "Error"
            return 1
        fi
    fi
}

create_combined_archive() {
    parent_dir=$(dirname "$1" | sed 's|[/\\]$||')
    for f in "$@"; do
        d=$(dirname "$f" | sed 's|[/\\]$||')
        if [ "$d" != "$parent_dir" ]; then
            echo "Error: Files must be in the same directory"
            return 1
        fi
    done

    parent_name=$(basename "$parent_dir")
    default_name="${parent_name}.${DEFAULT_ARCHIVE_EXT}"
    printf "Archive name [%s]: " "$default_name"
    read given_name
    if [ -z "$given_name" ]; then
        given_name="$default_name"
    fi
    output="$parent_dir/$given_name"

    if [ -f "$output" ]; then
        printf "Overwrite existing '%s'? [y/N]: " "$(basename "$output")"
        read ans
        case "$ans" in
            y|Y|yes) rm -f "$output" ;;
            *) echo "Skipped"; return 1 ;;
        esac
    fi

    printf "Creating %s ... " "$(basename "$output")"
    if 7z a "$output" "$@" >/dev/null 2>&1; then
        echo "OK"
        if [ "$DELETE_SOURCE_AFTER" = true ]; then
            for f in "$@"; do
                delete_source "$f"
            done
        fi
    else
        echo "Error"
        return 1
    fi
}

if [ $# -eq 0 ]; then
    echo "Usage:"
    echo "  $(basename "$0") <archive1> ...                  # extract"
    echo "  $(basename "$0") -a <file_or_dir1> ...           # create archive(s)"
    echo "  $(basename "$0") --xc=gbk <archive>              # extract with codepage"
    echo "  $(basename "$0") -o <archive>                    # open in 7-Zip FM"
    echo "Press Enter to exit..."
    read
    exit 1
fi

mode="extract"
codepage=""
open_fm=false
files=""

for arg in "$@"; do
    case "$arg" in
        -a) mode="create" ;;
        --xc=*) codepage="${arg#--xc=}" ;;
        -o) open_fm=true ;;
        -*)
            echo "Error: Unknown option $arg"
            echo "Press Enter to exit..."
            read
            exit 1
            ;;
        *) files="$files \"$arg\"" ;;
    esac
done

eval "set -- $files"

if [ $# -eq 0 ]; then
    echo "Error: No files specified"
    echo "Press Enter to exit..."
    read
    exit 1
fi

# Auto-detect: if no -a flag and none of the inputs are archives, switch to create mode
if [ "$mode" = "extract" ] && [ "$open_fm" = false ]; then
    all_not_archive=true
    for f in "$@"; do
        if is_archive "$f"; then
            all_not_archive=false
            break
        fi
    done
    if [ "$all_not_archive" = true ]; then
        mode="create"
    fi
fi

total=$#
current=0
error=0

if [ "$open_fm" = true ]; then
    for file in "$@"; do
        current=$((current + 1))
        printf "[%d/%d] " "$current" "$total"
        if ! 7z fm "$file"; then
            echo "Error: Failed to open $file"
            error=1
        fi
    done
elif [ "$mode" = "create" ]; then
    echo "Archive mode:"
    echo "  1) One archive per file/directory"
    echo "  2) Single combined archive"
    printf "Choice [1]: "
    read create_mode
    echo ""
    case "${create_mode:-1}" in
        2)
            if ! create_combined_archive "$@"; then
                error=1
            fi
            ;;
        *)
            for item in "$@"; do
                current=$((current + 1))
                printf "[%d/%d] " "$current" "$total"
                if ! create_archive "$item"; then
                    error=1
                fi
            done
            ;;
    esac
else
    for file in "$@"; do
        current=$((current + 1))
        printf "[%d/%d] " "$current" "$total"
        if ! extract_archive "$file" "$codepage" 0; then
            error=1
        fi
    done
fi

if [ $error -ne 0 ]; then
    echo ""
    echo "Press Enter to exit..."
    read
else
    printf "\nAll done. "
    read -t 3 -p "Closing in 3s..." 2>/dev/null || echo ""
fi

exit $error
