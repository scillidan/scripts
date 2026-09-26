#!/bin/sh
# Convert LRC files to Mandarin Pinyin or Cantonese Jyutping
#
# Usage:
#   Windows:
#     Create a .lnk shortcut to this script in the SendTo folder, then:
#     Select files > Right-click > Send To > lrcs_to_pinyin
#
#   Linux (Thunar):
#     Edit > Configure custom actions > Add action with command: /path/to/script.sh %F
#
#   Command line:
#     ./script.sh [pinyin|jyutping|both] <lrc1> <lrc2> ...

# Restart without startup files if ble.sh has intercepted arguments.
if [ -n "${BASH_VERSION:-}" ] && [ -n "${BLE_VERSION:-}" ] && [ -z "${LRC_PINYIN_NO_RC:-}" ]; then
	LRC_PINYIN_NO_RC=1 exec bash --norc --noprofile "$0" "$@"
fi

SCRIPT_DIR=$(dirname "$(readlink -f "$0" 2>/dev/null || echo "$0")")
PY_SCRIPT="$SCRIPT_DIR/lib/lrc_to_pinyin.py"

if ! command -v uv >/dev/null 2>&1; then
	echo "Error: uv not found (https://docs.astral.sh/uv/)"
	echo "Press Enter to exit..."
	read
	exit 1
fi

select_mode() {
	while true; do
		echo "Select mode: 1) pinyin 2) jyutping 3) both"
		printf "Choice: "
		read choice
		case "$choice" in
		1)
			mode="pinyin"
			return
			;;
		2)
			mode="jyutping"
			return
			;;
		3)
			mode="both"
			return
			;;
		*) echo "Invalid choice" ;;
		esac
	done
}

if [ "$1" = "pinyin" ] || [ "$1" = "jyutping" ] || [ "$1" = "both" ]; then
	mode="$1"
	shift
else
	case "$(basename "$0")" in
	*jyutping* | *Jyutping*) mode="jyutping" ;;
	*) select_mode ;;
	esac
fi

if [ $# -eq 0 ]; then
	echo "Usage: script.sh [pinyin|jyutping|both] <lrc1> <lrc2> ..."
	echo "Press Enter to exit..."
	read
	exit 1
fi

error=0

convert_file() {
	file="$1"
	cvt_mode="$2"
	output="${file%.lrc}.${cvt_mode}.lrc"
	if ! uv run "$PY_SCRIPT" "$cvt_mode" "$file" "$output"; then
		echo "Error: Failed to convert $file to $cvt_mode"
		error=1
	fi
}

for file in "$@"; do
	case "$file" in
	*.lrc | *.LRC) ;;
	*)
		echo "Skipping non-LRC file: $file"
		continue
		;;
	esac
	if [ "$mode" = "both" ]; then
		convert_file "$file" "pinyin"
		convert_file "$file" "jyutping"
	else
		convert_file "$file" "$mode"
	fi
done

if [ $error -ne 0 ]; then
	echo "Press Enter to exit..."
	read
	exit $error
fi
