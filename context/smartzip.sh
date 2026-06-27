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

readonly NESTED_EXTS="zip rar 7z 001"
readonly RECURSION_MAX=5

password_menu() {
    echo "Password options:"
    echo "  1) No password (try empty)"
    echo "  2) Enter manually"
    echo "  3) Skip (cancel extraction)"
    printf "Choice [1]: "
    read pw_choice
    case "${pw_choice:-1}" in
        2)
            printf "Enter password: "
            read manual_pass
            echo "$manual_pass"
            ;;
        3) echo "" ;;
        *) echo "" ;;
    esac
}

probe_archive() {
    archive="$1"
    "$_7Z" l -slt "$archive" 2>/dev/null | grep -c '^Path = ' || echo 0
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

    if [ "$item_count" -le 1 ]; then
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

    if "$_7Z" x -p"" -o"$target_dir" -y $cp_opts "$archive" >/dev/null 2>&1; then
        echo "Extracted"
    else
        echo "Archive is password-protected."
        chosen_pass=$(password_menu)

        if [ -z "$chosen_pass" ]; then
            echo "Skipped: $archive"
            return 1
        fi

        if ! "$_7Z" x "-p$chosen_pass" -o"$target_dir" -y $cp_opts "$archive" >/dev/null 2>&1; then
            echo "Error: Wrong password for $archive"
            return 1
        fi
        echo "Extracted (password)"
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

    if [ -d "$item" ]; then
        item_name=$(basename "$item")
        item_dir=$(dirname "$item")
        output="$item_dir/${item_name}.7z"
    else
        first_name=$(basename "$item" | sed 's/\.[^.]*$//')
        first_dir=$(dirname "$item")
        output="$first_dir/${first_name}.7z"
    fi

    printf "Creating %s ... " "$(basename "$output")"
    if "$_7Z" a "$output" "$item" >/dev/null 2>&1; then
        echo "OK"
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

total=$#
current=0
error=0

if [ "$open_fm" = true ]; then
    for file in "$@"; do
        current=$((current + 1))
        printf "[%d/%d] " "$current" "$total"
        if ! "$_7Z" fm "$file"; then
            echo "Error: Failed to open $file"
            error=1
        fi
    done
elif [ "$mode" = "create" ]; then
    for item in "$@"; do
        current=$((current + 1))
        printf "[%d/%d] " "$current" "$total"
        if ! create_archive "$item"; then
            error=1
        fi
    done
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
