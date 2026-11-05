#!/bin/sh
# Convert or pre-process subtitle files (LRC/SRT/VTT/ASS/SUP/MKV...) via seconv
#
# Usage:
#   Windows:
#     Create a .lnk shortcut to this script in the SendTo folder, then:
#     Select files/folders > Right-click > Send To > subs_format
#
#   Linux (Thunar):
#     Edit > Configure custom actions > Add action with command: /path/to/script.sh %F
#
#   Command line:
#     ./script.sh [--to srt|vtt|ass|keep] [--prep 1,2|none] <file1> <file2> ... <dir1> ...
#
#   No --to: interactive menu (target format + pre-process).
#   Pre-process: 1 = merge multi-line into one line, 2 = punctuation to space.
#   Pre-processed files are written as name.merged[.spc].<ext>; conversions
#   keep the original stem, so a same-format run never overwrites the source.
#
# Requires: seconv (Subtitle Edit command-line converter)

SCRIPT_DIR=$(dirname "$(readlink -f "$0" 2>/dev/null || echo "$0")")
RULES="$SCRIPT_DIR/lib/subs_punc.csv"
SUBS_GLOB="*.srt *.vtt *.ass *.ssa *.sub *.lrc *.smi"

to=""
prep=""

usage() {
	echo "Usage: $(basename "$0") [--to srt|vtt|ass|keep] [--prep 1,2|none] <file|dir> ..."
	echo ""
	echo "  --to    1=srt 2=vtt 3=ass 4=keep (menu when omitted)"
	echo "  --prep  1=merge multi-line 2=punc to space; 'none' to skip"
}

while [ $# -gt 0 ]; do
	case "$1" in
	--to)
		[ $# -ge 2 ] || { echo "Error: --to needs a value"; exit 1; }
		to="$2"
		shift 2
		;;
	--to=*) to="${1#--to=}"; shift ;;
	--prep)
		[ $# -ge 2 ] || { echo "Error: --prep needs a value"; exit 1; }
		prep="$2"
		shift 2
		;;
	--prep=*) prep="${1#--prep=}"; shift ;;
	-h | --help)
		usage
		exit 0
		;;
	*) break ;;
	esac
done

if [ -z "$to" ]; then
	echo "Target format:"
	echo "  1) srt   SubRip"
	echo "  2) vtt   WebVTT"
	echo "  3) ass   Advanced SubStation Alpha"
	echo "  4) keep  only pre-process, keep format"
	printf "Choice [1]: "
	read choice
	case "$choice" in
	2 | vtt) to=vtt ;;
	3 | ass) to=ass ;;
	4 | keep | same) to=keep ;;
	*) to=srt ;;
	esac
fi

case "$to" in
srt | subrip) fmt=subrip ;;
vtt | webvtt) fmt=webvtt ;;
ass | assa) fmt=AdvancedSubStationAlpha ;;
ssa) fmt=SubStationAlpha ;;
keep | same) fmt="" ;;
*)
	echo "Error: unknown target format: $to"
	exit 1
	;;
esac

if [ -z "$prep" ]; then
	echo ""
	echo "Pre-process:"
	echo "  1) merge multi-line into one line"
	echo "  2) punctuation to space"
	printf "Enter numbers, comma separated [1,2] (0=none): "
	read prep
	prep=${prep:-1,2}
fi

merge=0
punc=0
case "$prep" in
none | 0 | "") ;;
*)
	old_ifs=$IFS
	IFS=,
	for n in $prep; do
		case "$n" in
		1 | merge | merge_line) merge=1 ;;
		2 | punc | punc_to_spc) punc=1 ;;
		0 | none) ;;
		*) echo "Warning: unknown pre-process '$n' ignored" ;;
		esac
	done
	IFS=$old_ifs
	;;
esac

suffix=""
[ $merge -eq 1 ] && suffix="${suffix}.merged"
[ $punc -eq 1 ] && suffix="${suffix}.spc"

if [ $# -eq 0 ]; then
	echo "Error: No files or folders selected"
	echo "Press Enter to exit..."
	read
	exit 1
fi

if ! command -v seconv >/dev/null 2>&1; then
	echo "Error: seconv not found (https://subtitleedit.github.io/subtitleedit/reference/command-line.html)"
	echo "Press Enter to exit..."
	read
	exit 1
fi

if [ $punc -eq 1 ] && [ ! -f "$RULES" ]; then
	echo "Error: rules file not found: $RULES"
	echo "Press Enter to exit..."
	read
	exit 1
fi

detect_format() {
	seconv info "$1" --json 2>/dev/null |
		sed -n 's/.*"format": *"\([^"]*\)".*/\1/p' |
		tr -d ' \r'
}

process_file() {
	_file="$1"
	_target="$fmt"
	_append=""

	if [ -z "$_target" ]; then
		_target=$(detect_format "$_file")
		if [ -z "$_target" ]; then
			echo "Error: Cannot detect subtitle format: $_file"
			error=1
			return
		fi
	fi

	_src_ext=$(printf '%s' "${_file##*.}" | tr '[:upper:]' '[:lower:]')
	_tgt_ext=""
	case "$_target" in
	subrip) _tgt_ext=srt ;;
	webvtt) _tgt_ext=vtt ;;
	AdvancedSubStationAlpha) _tgt_ext=ass ;;
	SubStationAlpha) _tgt_ext=ssa ;;
	esac

	if [ "$to" = "keep" ] || { [ -n "$_tgt_ext" ] && [ "$_src_ext" = "$_tgt_ext" ]; }; then
		if [ -z "$suffix" ]; then
			echo "Skip (nothing to do): $_file"
			return
		fi
		_append="$suffix"
	fi

	set -- "$_file" "$_target"
	[ $merge -eq 1 ] && set -- "$@" --remove-line-breaks
	[ $punc -eq 1 ] && set -- "$@" --multiple-replace:"$RULES"
	[ -n "$_append" ] && set -- "$@" --output-filename-append:"$_append"
	set -- "$@" --no-language-suffix --overwrite --encoding:utf-8-no-bom --quiet

	if ! out=$(seconv "$@" 2>&1); then
		echo "Error: Failed to process $_file"
		printf '%s\n' "$out" | tail -3
		error=1
		return
	fi
	echo "OK: $(basename "$_file")"
}

error=0

for arg in "$@"; do
	if [ -d "$arg" ]; then
		for file in "$arg"/$SUBS_GLOB; do
			[ -f "$file" ] || continue
			process_file "$file"
		done
	elif [ -f "$arg" ]; then
		process_file "$arg"
	else
		echo "Error: Not found: $arg"
		error=1
	fi
done

if [ $error -ne 0 ]; then
	echo "Press Enter to exit..."
	read
else
	printf "\nAll done. "
	read -t 3 -p "Closing in 3s..." 2>/dev/null || echo ""
fi

exit $error
