#!/bin/sh
# arcs_7zip.sh - smart extract / create. Windows (Git Bash, MSYS2, Cygwin) + Linux.
#
# Assumption: bash/sh, 7z and THIS SCRIPT are already on PATH on every machine.
#   SEVENZ=7zz arcs_7zip.sh --dc foo.zip      # official 7-Zip for Linux
#   SEVENZ=7za arcs_7zip.sh --dc foo.zip      # p7zip standalone
#
# CLI:
#   arcs_7zip.sh <archive> ...       extract
#   arcs_7zip.sh -a <item> ...       create (interactive)
#   arcs_7zip.sh --xc=936 <archive>  extract with zip codepage (Windows-only reliable)
#   arcs_7zip.sh -o <archive>        open in 7-Zip FM (Windows) / list archive (Linux)
#   arcs_7zip.sh --dc <archive> ...  extract, non-interactive (Double Commander)
#   arcs_7zip.sh --dc --list=F       read paths from a DC %L / %LQ list file
#
# Toolbar buttons - identical Params on BOTH platforms (the platform branch is
# inside the script, driven only by uname -s):
#   Windows DC : Command  bash.exe   (or %SCOOP%\apps\git\current\bin\bash.exe)
#   Linux   DC : Command  bash
#   Params     : %"0 arcs_7zip.sh --dc %p{"}{"}
#   Start      : %D
#   Debug      : prepend %t1 to keep the terminal open; REMOVE it when stable.
#                (%t1 uses Windows Terminal on Win11, conhost on Win10,
#                 xterm/gnome-terminal on Linux - a pure difference generator.)
#   Old DC     : replace %p{"}{"} with --list=%LQ
#   Thunar     : Configure custom actions > arcs_7zip.sh %F
#
# Keep LF line endings. A copy from Windows onto Linux with CRLF makes
# "#!/bin/sh^M" fail:  sed -i 's/\r$//' arcs_7zip.sh

# Scan ALL args and pull --dc from any position. A DC build that does not
# consume %"0 / %t1 passes them through as literal args and would otherwise
# push --dc off position 1, turning batch mode into an interactive read().
BATCH=0
FORCE_EXTRACT=0
for _a in "$@"; do
	[ "$_a" = "--dc" ] && { BATCH=1; FORCE_EXTRACT=1; }
done
_n=$#
_i=0
while [ "$_i" -lt "$_n" ]; do
	_a="$1"; shift
	case "$_a" in
	--dc | %\"[01] | %t[01]) ;;
	*) set -- "$@" "$_a" ;;
	esac
	_i=$((_i + 1))
done

SEVENZ=${SEVENZ:-7z}
command -v "$SEVENZ" >/dev/null 2>&1 || { echo "Error: $SEVENZ not on PATH"; exit 1; }

IS_WIN=0
case "$(uname -s)" in
MINGW* | MSYS* | CYGWIN*) IS_WIN=1 ;;
esac

# Windows-style TMPDIR (C:\...) is not a writable POSIX path inside Git Bash.
case "${TMPDIR:-}" in *:*) TMPDIR= ;; esac
LOG="${TMPDIR:-/tmp}/arcs_7zip.$$.log"

MAX_DEPTH=5
EXTS="7z zip rar cb7 cbr cbt cbz 001 tar gz tgz bz2 tbz2 xz txz lzma lz z lzh cab iso wim swm esd msi dmg vhd vmdk vdi arj zst"
NESTED="7z zip rar cb7 cbr cbt cbz 001 tar gz bz2 xz lzma z lzh cab iso wim swm esd msi dmg vhd vmdk vdi"

# MSYS2 skips automatic POSIX->Windows conversion for args containing * ? [ ],
# so a path with [brackets] would reach 7z.exe as literal '/c/...' and 7z
# would silently exit 0. Explicit conversion is REQUIRED on Windows only.
# No cygpath on Linux; fall back to the raw path if it is ever missing.
win_path() {
	if [ "$IS_WIN" = 1 ]; then
		_w=$(cygpath -w "$1" 2>/dev/null)
		[ -n "$_w" ] && { printf '%s' "$_w"; return 0; }
	fi
	printf '%s' "$1"
}

# Version-independent member count.
# "7z l -slt" prints exactly one "Path = <archive>" header before the member
# records on p7zip 16.02 AND on Windows 7-Zip 24.x. Counting every Path line
# (the original bug) makes a one-file archive look like two, so two machines
# with different 7z builds choose different target dirs and appear to differ.
# Do NOT key off the "----------" separator: its shape varies by build.
count_items() {
	_n=$("$SEVENZ" l -slt "$(win_path "$1")" 2>>"$LOG" | grep -c '^Path = ')
	_r=$(( ${_n:-0} - 1 ))
	[ "$_r" -lt 0 ] && _r=0
	echo "$_r"
}

ext_is() {
	_e=$(printf '%s' "$1" | sed 's/.*\.//' | tr '[:upper:]' '[:lower:]')
	for _x in $2; do
		[ "$_e" = "$_x" ] && return 0
	done
	return 1
}
is_archive() { ext_is "$1" "$EXTS"; }
is_nested()  { ext_is "$1" "$NESTED"; }

# Win32 forbids these in names 7z itself must create. On Linux they are legal
# but normalising anyway keeps archive/target names identical on both systems.
sanitize() { printf '%s' "$1" | sed 's|[?*<>|":/\\]|_|g'; }

fail() {
	echo "Error: $1"
	echo "  --- $SEVENZ output (last 12 lines) ---"
	tail -n 12 "$LOG" 2>/dev/null | sed 's/^/  /'
	echo "  --- full log: $LOG ---"
}

extract() {
	arc="$1"; cp="$2"; depth="${3:-0}"
	[ -f "$arc" ] || { echo "Error: File not found: $arc"; return 1; }

	: >"$LOG"
	items=$(count_items "$arc")
	dir=$(dirname "$arc")
	base=$(basename "$arc" | sed 's/\.[^.]*$//')
	if [ "${items:-0}" -eq 1 ]; then
		out="$dir"
	else
		out="$dir/$(sanitize "$base")"
	fi
	echo "Items: $items | Target: $out"

	# Only archives that appeared during THIS extraction count as nested.
	# Otherwise a one-item archive (target = its own dir) would unpack and
	# rm -f every unrelated archive sitting next to it.
	# Unique per call: a nested extract must not overwrite/delete the list
	# its caller is still walking in its own find | while loop.
	PRE_SEQ=$(( ${PRE_SEQ:-0} + 1 ))
	pre="$LOG.pre.$PRE_SEQ"
	find "$out" -maxdepth 1 -type f 2>/dev/null >"$pre"

	cpopt=""
	[ -n "$cp" ] && cpopt="-mcp=$cp"

	# Never send 7z output to /dev/null: that rewrote two DIFFERENT real
	# errors into one misleading "possibly password-protected or corrupted".
	# $cpopt unquoted on purpose: empty or exactly one switch.
	if "$SEVENZ" x -p"" -o"$(win_path "$out")" -y $cpopt "$(win_path "$arc")" >>"$LOG" 2>&1; then
		echo "Extracted"
	else
		fail "Failed to extract $arc"
		rm -f "$pre"
		return 1
	fi

	[ "$depth" -lt "$MAX_DEPTH" ] && nested "$out" "$cp" "$depth" "$pre"
	rm -f "$pre"
	return 0
}

nested() {
	out="$1"; cp="$2"; depth="$3"; pre="$4"
	nd=$((depth + 1))
	# GNU find ships with Linux AND Git Bash. No "set --" here: it would
	# clobber the caller's "$@".
	find "$out" -maxdepth 1 -type f 2>/dev/null | while IFS= read -r n; do
		is_nested "$n" || continue
		grep -Fqx "$n" "$pre" 2>/dev/null && continue
		printf '  Nested: %s -> ' "$(basename "$n")"
		if extract "$n" "$cp" "$nd"; then
			rm -f "$n"
			echo "  Cleaned"
		else
			echo "  Skipped"
		fi
	done
}

create() {
	for item do
		dir=$(dirname "$item" | sed 's|[/\\]$||')
		name=$(sanitize "$(basename "$item")")
		[ -d "$item" ] || name=$(printf '%s' "$name" | sed 's/\.[^.]*$//')
		out="$dir/$name.zip"
		if [ -f "$out" ]; then
			printf "Overwrite '%s'? [y/N]: " "$(basename "$out")"
			read ans
			case "$ans" in
			y | Y | yes) rm -f "$out" ;;
			*) echo "Skipped"; continue ;;
			esac
		fi
		printf 'Creating %s ... ' "$(basename "$out")"
		: >"$LOG"
		if [ -d "$item" ]; then
			(cd "$item" && "$SEVENZ" a "$(win_path "$out")" .) >>"$LOG" 2>&1
		else
			"$SEVENZ" a "$(win_path "$out")" "$(win_path "$item")" >>"$LOG" 2>&1
		fi
		if [ $? -eq 0 ]; then
			echo "OK"
		else
			echo "Error"
			fail "create failed for $item"
			err=1
		fi
	done
}

if [ $# -eq 0 ]; then
	echo "Usage: $(basename "$0") [--dc|-a|--xc=CP|-o|--list=F] <files...>"
	exit 1
fi

mode=extract
cp=""
fm=0
list=""
while [ $# -gt 0 ]; do
	case "$1" in
	-a) mode=create; shift ;;
	--xc=*)
		cp="${1#--xc=}"
		# Numeric code pages are the portable spelling. NOTE: -mcp is reliable
		# on Windows 7-Zip; p7zip 16.02 silently ignores it and official 7zz on
		# Linux depends on locale/iconv. See the notes in the answer.
		case "$cp" in
		gbk | GBK | gb2312 | GB2312) cp=936 ;;
		big5 | BIG5) cp=950 ;;
		sjis | shift-jis | SHIFT-JIS) cp=932 ;;
		esac
		shift
		;;
	--dc) shift ;;
	--list=*) list="${1#--list=}"; shift ;;
	-o) fm=1; shift ;;
	--) shift; break ;;
	-*) echo "Error: Unknown option $1"; exit 1 ;;
	*) break ;;
	esac
done

# Older DC cannot emit %p{"}{"}: read a %L / %LQ selection list instead.
if [ -n "$list" ]; then
	[ -f "$list" ] || { echo "Error: list not found: $list"; exit 1; }
	set --
	while IFS= read -r line || [ -n "$line" ]; do
		line=$(printf '%s' "$line" | tr -d '\r')
		case "$line" in
		\"*\") line=${line#\"}; line=${line%\"} ;;
		esac
		[ -n "$line" ] && set -- "$@" "$line"
	done < "$list"
fi

[ $# -gt 0 ] || { echo "Error: No files specified"; exit 1; }
[ "$BATCH" = 1 ] && [ "$mode" = create ] && { echo "Error: --dc is extract-only"; exit 1; }

# No -a and no archive-looking input -> create (disabled by --dc).
if [ "$mode" = extract ] && [ "$fm" = 0 ] && [ "$FORCE_EXTRACT" = 0 ]; then
	all=1
	for f in "$@"; do
		is_archive "$f" && { all=0; break; }
	done
	[ "$all" = 1 ] && mode=create
fi

err=0
if [ "$fm" = 1 ]; then
	# 7z.exe has NO "fm" command. 7zFM.exe is Windows-only; on Linux fall
	# back to listing the archive instead of running a missing binary.
	if [ "$IS_WIN" = 1 ]; then
		fmcmd=$(command -v 7zFM || command -v 7zfm || command -v 7zFM.exe || printf '7zFM')
		for f in "$@"; do "$fmcmd" "$(win_path "$f")" || err=1; done
	else
		echo "Note: no 7-Zip File Manager on Linux; listing instead."
		for f in "$@"; do "$SEVENZ" l "$(win_path "$f")" || err=1; done
	fi
elif [ "$mode" = create ]; then
	[ "$BATCH" = 1 ] && { echo "Error: --dc is extract-only"; exit 1; }
	create "$@"
else
	for f in "$@"; do
		extract "$f" "$cp" 0 || err=1
	done
fi

if [ "$err" -ne 0 ]; then
	if [ -s "$LOG" ]; then
		echo "Failed. Log: $LOG"
	else
		echo "Failed."
	fi
elif [ "$BATCH" = 1 ]; then
	echo "All done."
elif [ -t 0 ]; then
	# dash (Debian/Ubuntu /bin/sh) has no "read -t"; bash (Git Bash) does.
	# Silence the error there and just return immediately.
	printf 'All done. Closing in 3s...'
	read -r -t 3 _ 2>/dev/null || true
	printf '\n'
else
	echo "All done."
fi

# Keep the log on failure: fail() printed its path for a reason.
[ "$err" -ne 0 ] || rm -f "$LOG"
exit $err
