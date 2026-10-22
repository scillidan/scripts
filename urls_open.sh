#!/bin/sh
# Open every URL from the clipboard in the default browser
#
# Usage:
#   ./script.sh
#
# Lines are opened from top to bottom; empty lines are ignored.
# Only http:// and https:// lines are opened.

os=$(uname -s)

case "$os" in
MINGW* | MSYS* | CYGWIN*)
	clipboard=$(powershell.exe -NoProfile -Command Get-Clipboard 2>/dev/null)
	;;
*)
	if [ -n "$WAYLAND_DISPLAY" ] && command -v wl-paste >/dev/null 2>&1; then
		clipboard=$(wl-paste 2>/dev/null)
	elif command -v xclip >/dev/null 2>&1; then
		clipboard=$(xclip -selection clipboard -o 2>/dev/null)
	elif command -v xsel >/dev/null 2>&1; then
		clipboard=$(xsel --clipboard --output 2>/dev/null)
	fi
	;;
esac

if [ -z "$clipboard" ]; then
	echo "Error: Clipboard is empty or no clipboard tool is available"
	echo "Press Enter to exit..."
	read
	exit 1
fi

open_url() {
	case "$os" in
	MINGW* | MSYS* | CYGWIN*)
		rundll32.exe url.dll,FileProtocolHandler "$1"
		;;
	*)
		if command -v xdg-open >/dev/null 2>&1; then
			xdg-open "$1"
		else
			return 1
		fi
		;;
	esac
}

printf '%s\n' "$clipboard" | tr -d '\r' | {
	error=0
	opened=0

	while IFS= read -r url; do
		[ -z "$url" ] && continue
		case "$url" in
		http://* | https://*) ;;
		*) continue ;;
		esac

		echo "Opening: $url"
		if open_url "$url"; then
			opened=$((opened + 1))
		else
			echo "Error: Failed to open $url"
			error=1
		fi
	done

	if [ $opened -eq 0 ] && [ $error -eq 0 ]; then
		echo "No URLs found in clipboard"
	elif [ $opened -gt 0 ]; then
		echo "Opened $opened URL(s)"
	fi

	exit $error
}

error=$?

if [ $error -ne 0 ]; then
	echo "Press Enter to exit..."
	read
fi

exit $error
