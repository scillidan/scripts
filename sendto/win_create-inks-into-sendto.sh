#!/bin/sh

# Create SendTo shortcuts for executable files
#
# Notes:
#   - Supports .sh, .bat, .exe and other executable files
#   - Existing shortcuts will be overwritten without warning
#   - .sh and .bat files will use cmd.ico icon
#   - .exe files use their own embedded icon
#   - Requires PowerShell on Windows
#
# Usage:
#   1. Create a .lnk to this script in SendTo folder (manual, one-time setup)
#   2. Right-click any executable file > Send To > create_link_into_sendto
#   3. A .lnk shortcut will be created in SendTo folder

SENDTO_DIR="$APPDATA/Microsoft/Windows/SendTo"
SCRIPT_DIR=$(dirname "$(readlink -f "$0" 2>/dev/null || echo "$0")")
SENDTO_ICON="$SCRIPT_DIR/share/sendto.ico"

create_shortcut() {
    local script_path="$1"
    local base_name=$(basename "$script_path")
    local script_name="${base_name%.*}"
    local ext="${base_name##*.}"
    local lnk_path="$SENDTO_DIR/${script_name}.lnk"

    if [ ! -f "$script_path" ]; then
        echo "Error: File not found: $script_path"
        return 1
    fi

    local win_script_path=$(cygpath -w "$script_path" 2>/dev/null || echo "$script_path")
    local win_lnk_path=$(cygpath -w "$lnk_path" 2>/dev/null || echo "$lnk_path")
    local win_icon_path=""

    case "$ext" in
        sh|bat)
            if [ -f "$SENDTO_ICON" ]; then
                win_icon_path=$(cygpath -w "$SENDTO_ICON" 2>/dev/null || echo "$SENDTO_ICON")
            fi
            ;;
    esac

    local ps_command="\$ws = New-Object -ComObject WScript.Shell; "
    ps_command+="\$s = \$ws.CreateShortcut('$win_lnk_path'); "
    ps_command+="\$s.TargetPath = '$win_script_path'; "

    if [ -n "$win_icon_path" ]; then
        ps_command+="\$s.IconLocation = '$win_icon_path'; "
    fi

    ps_command+="\$s.Save()"

    if ! powershell.exe -NoProfile -Command "$ps_command"; then
        echo "Error: Failed to create shortcut for: $script_path"
        return 1
    else
        echo "Created: $lnk_path"
    fi
}

if [ -z "$SENDTO_DIR" ] || [ ! -d "$SENDTO_DIR" ]; then
    echo "Error: SendTo folder not found. This script only works on Windows."
    echo "Press Enter to exit..."
    read
    exit 1
fi

error=0

for script in "$@"; do
    create_shortcut "$script" || error=1
done

if [ $error -ne 0 ]; then
    echo "Press Enter to exit..."
    read
fi