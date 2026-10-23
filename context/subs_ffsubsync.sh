#!/bin/sh
# Sync subtitle timing to its video using ffsubsync
#
#   https://github.com/smacke/ffsubsync
#
# Usage:
#   Windows:
#     Create a .lnk shortcut to this script in the SendTo folder, then:
#     Select files > Right-click > Send To > subs_ffsubsync
#
#   Linux (Thunar):
#     Edit > Configure custom actions > Add action with command: /path/to/script.sh %F
#
#   Command line:
#     ./script.sh <sub1> <video1> ...
#
# Notes:
#   - Pass subtitle files, and each is paired with its video
#     (same-name: Movie.mkv + Movie.srt, or Movie.zh.srt style)
#   - Pass only videos, and matching subtitles are found next to each video
#   - Pass both, and only the selected files are paired

# ── File checks ──────────────────────────────────────────────────────────────

if [ $# -eq 0 ]; then
	echo "Error: No files selected"
	echo "Press Enter to exit..."
	read
	exit 1
fi

if ! command -v ffsubsync >/dev/null 2>&1; then
	echo "Error: ffsubsync not found (install with: pipx install ffsubsync)"
	echo "Press Enter to exit..."
	read
	exit 1
fi

if ! command -v ffmpeg >/dev/null 2>&1; then
	echo "Error: ffmpeg not found (required by ffsubsync)"
	echo "Press Enter to exit..."
	read
	exit 1
fi

# ── Extension helpers ────────────────────────────────────────────────────────

is_video() {
	case $(echo "$1" | sed 's/.*\.//' | tr '[:upper:]' '[:lower:]') in
	mp4 | mkv | avi | mov | wmv | flv | m4v | webm | ogv | ts | m2ts | vob) return 0 ;;
	*) return 1 ;;
	esac
}

is_sub() {
	case $(echo "$1" | sed 's/.*\.//' | tr '[:upper:]' '[:lower:]') in
	srt | ass | ssa | vtt | sub) return 0 ;;
	*) return 1 ;;
	esac
}

strip_ext() {
	basename "$1" | sed 's/\.[^.]*$//'
}

# Does sub basename match video basename?
# True for same-name, or <video>.<lang> style: successively strips trailing
# .segments from the sub base (Movie.zh.srt -> Movie) until it equals the
# video base. Case-insensitive. Longest match wins.
base_matches() {
	sub_base="$1"
	vid_base=$(echo "$2" | tr '[:upper:]' '[:lower:]')
	while :; do
		if [ "$(echo "$sub_base" | tr '[:upper:]' '[:lower:]')" = "$vid_base" ]; then
			return 0
		fi
		stripped=$(echo "$sub_base" | sed 's/\.[^.]*$//')
		if [ "$stripped" = "$sub_base" ]; then
			return 1
		fi
		sub_base="$stripped"
	done
}

# ── Classify selection ───────────────────────────────────────────────────────

sub_count=0
vid_count=0
for f in "$@"; do
	if is_sub "$f"; then
		sub_count=$((sub_count + 1))
	elif is_video "$f"; then
		vid_count=$((vid_count + 1))
	else
		echo "Skipping unsupported: $(basename "$f")"
	fi
done

if [ "$sub_count" -eq 0 ] && [ "$vid_count" -eq 0 ]; then
	echo "Error: No supported files found"
	echo "Subtitles: srt ass ssa vtt sub"
	echo "Videos:    mp4 mkv avi mov wmv flv m4v webm ogv ts m2ts vob"
	echo "Press Enter to exit..."
	read
	exit 1
fi

printf "Overwrite original subtitle files in place? [y/N]: "
read ow_answer
case "$ow_answer" in
y | Y) OVERWRITE=1 ;;
*) OVERWRITE=0 ;;
esac

# ── Sync one subtitle against one video ──────────────────────────────────────

# Writes to a temp file first, validates, then moves into place.
sync_pair() {
	video="$1"
	sub="$2"
	sub_dir=$(dirname "$sub")
	sub_base=$(strip_ext "$sub")
	sub_ext=$(echo "$sub" | sed 's/.*\.//')

	printf "\n--- %s\n    -> %s ---\n" "$(basename "$sub")" "$(basename "$video")"

	tmp_out="$sub_dir/.ffsubsync_$$.$sub_ext"
	tmp_log="$sub_dir/.ffsubsync_$$.log"
	rm -f "$tmp_out" "$tmp_log"

	ffsubsync "$video" -i "$sub" -o "$tmp_out" >"$tmp_log" 2>&1
	ff_rc=$?
	cat "$tmp_log"

	if [ $ff_rc -ne 0 ]; then
		echo "Error: ffsubsync failed for: $sub"
		rm -f "$tmp_out" "$tmp_log"
		error=1
		return 1
	fi

	# Negative score = no good alignment found; the applied offset is likely wrong
	score=$(sed -n 's/.*score: //p' "$tmp_log" | tail -1 | cut -d. -f1)
	rm -f "$tmp_log"
	if echo "$score" | grep -qE '^-?[0-9]+$' && [ "$score" -le 0 ]; then
		echo "Warning: low alignment score ($score); output is likely wrong, verify before using"
	fi

	if [ ! -s "$tmp_out" ]; then
		echo "Error: empty output for: $sub"
		rm -f "$tmp_out"
		error=1
		return 1
	fi

	if [ "$OVERWRITE" -eq 1 ]; then
		mv -f "$tmp_out" "$sub"
		echo "Synced: $sub"
		return 0
	fi

	dest="$sub_dir/$sub_base.synced.$sub_ext"
	if [ -f "$dest" ]; then
		printf "Overwrite existing %s? [y/N]: " "$(basename "$dest")"
		read ow_dest
		case "$ow_dest" in
		y | Y) rm -f "$dest" ;;
		*)
			echo "Skipped: $sub"
			rm -f "$tmp_out"
			return 1
			;;
		esac
	fi

	mv "$tmp_out" "$dest"
	echo "Synced: $dest"
}

error=0

# ── Case 1: subtitles selected ───────────────────────────────────────────────

if [ "$sub_count" -gt 0 ]; then
	for sub in "$@"; do
		is_sub "$sub" || continue
		sub_base=$(strip_ext "$sub")
		sub_dir=$(dirname "$sub")

		MATCHES=""
		# Prefer videos from the selection
		for f in "$@"; do
			is_video "$f" || continue
			if base_matches "$sub_base" "$(strip_ext "$f")"; then
				MATCHES="$MATCHES$f
"
			fi
		done
		# Fall back to scanning the subtitle's directory
		if [ -z "$MATCHES" ]; then
			for f in "$sub_dir"/*; do
				[ -f "$f" ] || continue
				is_video "$f" || continue
				if base_matches "$sub_base" "$(strip_ext "$f")"; then
					MATCHES="$MATCHES$f
"
				fi
			done
		fi

		count=$(printf '%s\n' "$MATCHES" | grep -c .)

		if [ "$count" -eq 0 ]; then
			echo "Error: No matching video found for: $(basename "$sub")"
			error=1
			continue
		fi

		if [ "$count" -eq 1 ]; then
			VIDEO=$(printf '%s\n' "$MATCHES" | sed -n 1p)
		else
			echo ""
			echo "Multiple videos match: $(basename "$sub")"
			n=0
			old_ifs=$IFS
			IFS='
'
			set -f
			for m in $MATCHES; do
				n=$((n + 1))
				printf "  %d) %s\n" "$n" "$(basename "$m")"
			done
			set +f
			IFS=$old_ifs
			printf "Choice [1]: "
			read choice
			choice=${choice:-1}
			VIDEO=$(printf '%s\n' "$MATCHES" | sed -n "${choice}p")
			if [ -z "$VIDEO" ]; then
				echo "Error: Invalid choice"
				error=1
				continue
			fi
		fi

		sync_pair "$VIDEO" "$sub" || continue
	done

# ── Case 2: only videos selected ─────────────────────────────────────────────

else
	for vid in "$@"; do
		is_video "$vid" || continue
		vid_base=$(strip_ext "$vid")
		vid_dir=$(dirname "$vid")

		found=0
		for f in "$vid_dir"/*; do
			[ -f "$f" ] || continue
			is_sub "$f" || continue
			case "$(basename "$f")" in
			*.synced.*) continue ;; # skip outputs of previous runs
			esac
			if base_matches "$(strip_ext "$f")" "$vid_base"; then
				sync_pair "$vid" "$f" || continue
				found=1
			fi
		done

		if [ "$found" -eq 0 ]; then
			echo "Error: No matching subtitle found for: $(basename "$vid")"
			error=1
		fi
	done
fi

if [ $error -ne 0 ]; then
	echo "Press Enter to exit..."
	read
fi

exit $error
