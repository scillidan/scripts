#!/bin/sh
# Batch compress PDFs using presse with before/after size comparison.
#
# Usage:
#   Windows:
#     Create a .lnk shortcut to this script in the SendTo folder, then:
#     Select files > Right-click > Send To > presse_pdfs
#
#   Linux (Thunar):
#     Edit > Configure custom actions > Add action with command: /path/to/script.sh %F
#
#   Command line:
#     ./presse_pdfs.sh <pdf1> <pdf2> ...

readonly DEFAULT_QUALITY=80

current_tmp=""

delete_source() {
	target="$1"
	if [ ! -e "$target" ]; then
		return 0
	fi
	if command -v gio >/dev/null 2>&1; then
		gio trash "$target" 2>/dev/null
		return $?
	fi
	case "$(uname -s)" in
	MINGW* | MSYS* | CYGWIN*)
		winpath="$target"
		if command -v cygpath >/dev/null 2>&1; then
			winpath=$(cygpath -w "$target")
		fi
		escaped=$(printf "%s" "$winpath" | sed "s/'/''/g")
		if [ -d "$target" ]; then
			method="DeleteDirectory"
		else
			method="DeleteFile"
		fi
		powershell -NoProfile -Command \
			"Add-Type -AssemblyName Microsoft.VisualBasic; [Microsoft.VisualBasic.FileIO.FileSystem]::$method('$escaped','OnlyErrorDialogs','SendToRecycleBin')" 2>/dev/null
		return $?
		;;
	esac
	return 1
}

format_size() {
	size=$1
	if [ "$size" -ge 1048576 ]; then
		awk "BEGIN { printf \"%.1f MB\", $size / 1048576 }"
	elif [ "$size" -ge 1024 ]; then
		awk "BEGIN { printf \"%.1f KB\", $size / 1024 }"
	else
		echo "${size} B"
	fi
}

cleanup() {
	if [ -n "$current_tmp" ]; then
		rm -f "$current_tmp"
	fi
}
trap cleanup INT TERM EXIT

if ! command -v presse >/dev/null 2>&1; then
	echo "Error: presse not found in PATH"
	echo "Press Enter to exit..."
	read -r
	exit 1
fi

if [ $# -eq 0 ]; then
	echo "Error: No files selected"
	echo "Press Enter to exit..."
	read -r
	exit 1
fi

for file in "$@"; do
	ext=".${file##*.}"
	case "$ext" in
	.pdf | .PDF) ;;
	*)
		echo "Error: Not a PDF file: $file"
		echo "Press Enter to exit..."
		read -r
		exit 1
		;;
	esac
	if [ ! -f "$file" ] || [ ! -r "$file" ]; then
		echo "Error: File not found or not readable: $file"
		echo "Press Enter to exit..."
		read -r
		exit 1
	fi
done

printf "Quality (1-100, default %s): " "$DEFAULT_QUALITY"
read -r quality
quality=${quality:-$DEFAULT_QUALITY}
case "$quality" in
'' | *[!0-9]*)
	echo "Error: Quality must be a number between 1 and 100"
	echo "Press Enter to exit..."
	read -r
	exit 1
	;;
esac
if [ "$quality" -lt 1 ] || [ "$quality" -gt 100 ]; then
	echo "Error: Quality must be between 1 and 100"
	echo "Press Enter to exit..."
	read -r
	exit 1
fi

echo ""
echo "DPI preset (optional):"
echo "  0. No DPI cap (default)"
echo "  1. screen   - 75 DPI"
echo "  2. ebook    - 150 DPI"
echo "  3. printer  - 300 DPI"
echo "  4. prepress - 600 DPI"
printf "Select [0-4] (default 0): "
read -r dpi_choice
dpi_choice=${dpi_choice:-0}
case "$dpi_choice" in
0) dpi_arg="" ;;
1) dpi_arg="-d 75" ;;
2) dpi_arg="-d 150" ;;
3) dpi_arg="-d 300" ;;
4) dpi_arg="-d 600" ;;
*)
	echo "Error: Invalid DPI choice"
	echo "Press Enter to exit..."
	read -r
	exit 1
	;;
esac

echo ""
echo "Compressing..."
echo ""

error=0
compressed_files=""
total_orig=0
total_new=0

for file in "$@"; do
	dir=$(dirname "$file")
	base=$(basename "$file")
	name="${base%.*}"

	output="${dir}/_presse_${name}.pdf"
	if [ -e "$output" ]; then
		i=1
		while [ -e "${dir}/_presse_${name}_${i}.pdf" ]; do
			i=$((i + 1))
		done
		output="${dir}/_presse_${name}_${i}.pdf"
	fi

	tmp_output="${dir}/._presse_${name}.$$.pdf.tmp"
	current_tmp="$tmp_output"
	rm -f "$current_tmp"

	echo "  $base"
	if ! presse press "$file" -q "$quality" $dpi_arg -o "$current_tmp" 2>/dev/null; then
		echo "    Error: presse failed for $base"
		rm -f "$current_tmp"
		current_tmp=""
		error=1
		continue
	fi

	if [ ! -f "$current_tmp" ] || [ ! -s "$current_tmp" ]; then
		echo "    Error: Output file is empty or missing for $base"
		rm -f "$current_tmp"
		current_tmp=""
		error=1
		continue
	fi

	if ! mv "$current_tmp" "$output" 2>/dev/null; then
		echo "    Error: Failed to finalize output for $base"
		rm -f "$current_tmp"
		current_tmp=""
		error=1
		continue
	fi
	current_tmp=""

	orig_size=$(stat -c%s "$file" 2>/dev/null || echo 0)
	new_size=$(stat -c%s "$output" 2>/dev/null || echo 0)
	if [ "$orig_size" -gt 0 ]; then
		ratio=$(awk "BEGIN { printf \"%.1f\", $new_size * 100 / $orig_size }")
		saved=$(awk "BEGIN { printf \"%.1f\", ($orig_size - $new_size) * 100 / $orig_size }")
	else
		ratio="0.0"
		saved="0.0"
	fi

	if [ "$new_size" -lt "$orig_size" ]; then
		indicator="↓${saved}%"
	elif [ "$new_size" -gt "$orig_size" ]; then
		indicator="↑${saved#-}%"
	else
		indicator="no change"
	fi

	echo "    $(format_size "$orig_size") -> $(format_size "$new_size") (${ratio}%, ${indicator})"

	compressed_files="$compressed_files \"$file\""
	total_orig=$((total_orig + orig_size))
	total_new=$((total_new + new_size))
done

if [ -z "$compressed_files" ]; then
	if [ $error -ne 0 ]; then
		echo ""
		echo "Press Enter to exit..."
		read -r
	fi
	exit $error
fi

if [ "$total_orig" -gt 0 ]; then
	total_ratio=$(awk "BEGIN { printf \"%.1f\", $total_new * 100 / $total_orig }")
	total_saved=$(awk "BEGIN { printf \"%.1f\", ($total_orig - $total_new) * 100 / $total_orig }")
	if [ "$total_new" -lt "$total_orig" ]; then
		total_indicator="↓${total_saved}%"
	elif [ "$total_new" -gt "$total_orig" ]; then
		total_indicator="↑${total_saved#-}%"
	else
		total_indicator="no change"
	fi
	echo ""
	echo "Total: $(format_size "$total_orig") -> $(format_size "$total_new") (${total_ratio}%, ${total_indicator})"
fi

echo ""
echo "Replace source files with compressed versions?"
echo "  (Source files will be moved to recycle bin)"
printf "[y/N]: "
read -r replace

eval "set -- $compressed_files"
case "$replace" in
y | Y | yes)
	for file in "$@"; do
		dir=$(dirname "$file")
		base=$(basename "$file")
		name="${base%.*}"

		compressed="${dir}/_presse_${name}.pdf"
		if [ ! -f "$compressed" ]; then
			i=1
			while [ -e "${dir}/_presse_${name}_${i}.pdf" ]; do
				compressed="${dir}/_presse_${name}_${i}.pdf"
				i=$((i + 1))
			done
		fi

		if [ -f "$compressed" ]; then
			if delete_source "$file"; then
				mv "$compressed" "$file" 2>/dev/null
				echo "  Replaced: $base"
			else
				echo "  Error: Could not move $base to recycle bin; original kept ($compressed left alongside)"
				error=1
			fi
		fi
	done
	echo "Done."
	;;
*)
	echo "Skipped."
	;;
esac

if [ $error -ne 0 ]; then
	echo ""
	echo "Press Enter to exit..."
	read -r
fi

exit $error
