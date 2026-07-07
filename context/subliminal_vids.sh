#!/bin/sh
# Download subtitles for video files using subliminal
#
#   https://github.com/Diaoul/subliminal
#
# Usage:
#   Windows:
#     Create a .lnk shortcut to this script in the SendTo folder, then:
#     Select files > Right-click > Send To > subliminal_vids
#
#   Linux (Thunar):
#     Edit > Configure custom actions > Add action with command: /path/to/script.sh %F
#
#   Command line:
#     ./script.sh <vid1> <vid2> ...
#
#   Non-interactive (skip menu):
#     ./script.sh --title="Movie Name (2023)" --langs=zh,en <file.mp4>
#     SUBLIMINAL_TITLE="Movie Name (2023)" SUBLIMINAL_LANGS=zh,en ./script.sh <file.mp4>

# ── Default provider ──────────────────────────────────────────────────────────
# Empty = use all default providers; specify one like "opensubtitlescom"
PROVIDER=""

# ── Parse --args ─────────────────────────────────────────────────────────────

arg_title=""
arg_langs=""

while [ $# -gt 0 ]; do
	case "$1" in
	--title=*)
		arg_title="${1#--title=}"
		shift
		;;
	--langs=*)
		arg_langs="${1#--langs=}"
		shift
		;;
	*)
		break
		;;
	esac
done

# ── File checks ──────────────────────────────────────────────────────────────

if [ $# -eq 0 ]; then
	echo "Error: No files selected"
	echo "Press Enter to exit..."
	read
	exit 1
fi

if ! command -v subliminal >/dev/null 2>&1; then
	echo "Error: subliminal not found (install with: pipx install subliminal)"
	echo "Press Enter to exit..."
	read
	exit 1
fi

# ── Supported video extensions ───────────────────────────────────────────────

SUPPORTED_EXT="\.mp4$\|\.mkv$\|\.avi$\|\.mov$\|\.wmv$\|\.flv$\|\.m4v$\|\.webm$\|\.ogv$\|\.ts$\|\.m2ts$\|\.vob$"

# ── Language lists (IETF alpha2 codes, with region variants) ────────────────
# Subliminal CLI accepts IETF codes: en, zh-CN, pt-BR, etc.
# zho is a macro-language; zh-CN and zh-TW are the common variants.

COMMON_LANGUAGES="en:English zho:Chinese ja:Japanese ko:Korean es:Spanish fr:French de:German ru:Russian it:Italian pt:Portuguese pt-BR:Portuguese-(Brazil) ar:Arabic hi:Hindi nl:Dutch pl:Polish tr:Turkish vi:Vietnamese th:Thai id:Indonesian uk:Ukrainian cs:Czech sv:Swedish da:Danish fi:Finnish el:Greek he:Hebrew hu:Hungarian ro:Romanian nb:Norwegian-Bokmal"

OTHER_LANGUAGES="aa:Afar ab:Abkhazian af:Afrikaans ak:Akan sq:Albanian am:Amharic an:Aragonese hy:Armenian as:Assamese av:Avaric ae:Avestan ay:Aymara az:Azerbaijani bm:Bambara ba:Bashkir eu:Basque be:Belarusian bn:Bengali bh:Bihari bi:Bislama bs:Bosnian br:Breton bg:Bulgarian my:Burmese ca:Catalan ch:Chamorro ce:Chechen cu:Church-Slavic cv:Chuvash kw:Cornish co:Corsican cr:Cree hr:Croatian dv:Divehi dz:Dzongkha eo:Esperanto et:Estonian ee:Ewe fo:Faroese fj:Fijian fy:Western-Frisian ff:Fulah gd:Scottish-Gaelic ga:Irish gl:Galician gv:Manx gn:Guarani gu:Gujarati ht:Haitian ha:Hausa hz:Herero ho:Hiri-Motu ig:Igbo is:Icelandic io:Ido ia:Interlingua ie:Interlingue iu:Inuktitut ik:Inupiaq jv:Javanese kl:Kalaallisut kn:Kannada ks:Kashmiri kr:Kanuri kk:Kazakh km:Central-Khmer ki:Kikuyu rw:Kinyarwanda ky:Kirghiz kv:Komi kg:Kongo kj:Kuanyama ku:Kurdish lo:Lao la:Latin lv:Latvian lt:Lithuanian li:Limburgan ln:Lingala lb:Luxembourgish lu:Luba-Katanga lg:Ganda mk:Macedonian ml:Malayalam ms:Malay mg:Malagasy mt:Maltese mi:Maori mr:Marathi mh:Marshallese mn:Mongolian na:Nauru nv:Navajo nd:North-Ndebele ng:Ndonga ne:Nepali se:Northern-Sami nn:Norwegian-Nynorsk oc:Occitan oj:Ojibwa or:Oriya os:Ossetian om:Oromo pi:Pali pa:Panjabi fa:Persian ps:Pushto qu:Quechua rm:Raeto-Romance rn:Rundi sm:Samoan sg:Sango sa:Sanskrit sr:Serbian sh:Serbo-Croatian st:Southern-Sotho tn:Tswana sn:Shona sd:Sindhi si:Sinhala sk:Slovak sl:Slovenian so:Somali su:Sundanese sw:Swahili ss:Swati tl:Tagalog ty:Tahitian tg:Tajik ta:Tamil tt:Tatar te:Telugu bo:Tibetan ti:Tigrinya to:Tonga ts:Tsonga tk:Turkmen tw:Twi ug:Uighur ur:Urdu uz:Uzbek ve:Venda vo:Volapuk wa:Walloon cy:Welsh wo:Wolof xh:Xhosa yi:Yiddish yo:Yoruba za:Zhuang zu:Zulu"

show_languages() {
	list="$1"
	s_cols=0
	s_num=1
	for entry in $list; do
		name="${entry#*:}"
		printf "%3d) %-18s" "$s_num" "$name"
		s_cols=$((s_cols + 1))
		if [ $((s_cols % 3)) -eq 0 ]; then
			printf "\n"
		fi
		s_num=$((s_num + 1))
	done
	printf "%3d) %-18s\n" "$s_num" "Other-Languages..."
	if [ $((s_cols % 3)) -ne 0 ]; then
		printf "\n"
	fi
}

show_other_languages() {
	o_cols=0
	o_num=1
	for entry in $OTHER_LANGUAGES; do
		name="${entry#*:}"
		printf "%3d) %-18s" "$o_num" "$name"
		o_cols=$((o_cols + 1))
		if [ $((o_cols % 3)) -eq 0 ]; then
			printf "\n"
		fi
		o_num=$((o_num + 1))
	done
	if [ $((o_cols % 3)) -ne 0 ]; then
		printf "\n"
	fi
}

select_other_language() {
	while true; do
		echo ""
		echo "Language (Other Languages)"
		echo "----------------------------------------"
		show_other_languages
		total=$(echo "$OTHER_LANGUAGES" | wc -w)
		echo ""
		printf "Enter number or code (e.g. en, eng, English): "
		read choice

		if [ -z "$choice" ]; then
			echo "Error: Selection required"
			continue
		fi

		if echo "$choice" | grep -qE '^[0-9]+$'; then
			if [ "$choice" -ge 1 ] && [ "$choice" -le "$total" ]; then
				SELECTED=$(echo "$OTHER_LANGUAGES" | cut -d' ' -f"$choice" | cut -d: -f1)
				return 0
			fi
		fi

		SELECTED="$choice"
		return 0
	done
}

select_language() {
	prompt="$1"
	allow_empty="$2"

	while true; do
		echo ""
		echo "$prompt"
		echo "----------------------------------------"
		show_languages "$COMMON_LANGUAGES"
		total=$(echo "$COMMON_LANGUAGES" | wc -w)
		total=$((total + 1))
		echo ""
		printf "Enter number or code (e.g. en, eng, English): "
		read choice

		if [ -z "$choice" ]; then
			if [ "$allow_empty" = "1" ]; then
				SELECTED=""
				return 0
			fi
			echo "Error: Selection required"
			continue
		fi

		if echo "$choice" | grep -qE '^[0-9]+$'; then
			if [ "$choice" -ge 1 ] && [ "$choice" -le "$(echo "$COMMON_LANGUAGES" | wc -w)" ]; then
				SELECTED=$(echo "$COMMON_LANGUAGES" | cut -d' ' -f"$choice" | cut -d: -f1)
				return 0
			fi

			if [ "$choice" -eq "$total" ]; then
				select_other_language
				return $?
			fi
		fi

		SELECTED="$choice"
		return 0
	done
}

select_languages() {
	while true; do
		echo ""
		echo "Subtitle language(s)"
		echo "----------------------------------------"
		show_languages "$COMMON_LANGUAGES"
		total=$(echo "$COMMON_LANGUAGES" | wc -w)
		total=$((total + 1))
		echo ""
		printf "Enter number(s) or code(s), comma-separated (e.g. 1,2,6 or en,zh-CN): "
		read choice

		if [ -z "$choice" ]; then
			echo "Error: Selection required"
			continue
		fi

		result=""
		IFS=','
		for part in $choice; do
			part=$(echo "$part" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
			[ -z "$part" ] && continue

			if echo "$part" | grep -qE '^[0-9]+$'; then
				if [ "$part" -ge 1 ] && [ "$part" -le "$(echo "$COMMON_LANGUAGES" | wc -w)" ]; then
					code=$(echo "$COMMON_LANGUAGES" | cut -d' ' -f"$part" | cut -d: -f1)
					if [ -n "$result" ]; then
						result="$result,$code"
					else
						result="$code"
					fi
				elif [ "$part" -eq "$total" ]; then
					select_other_language
					if [ -n "$result" ] && [ -n "$SELECTED" ]; then
						result="$result,$SELECTED"
					elif [ -n "$SELECTED" ]; then
						result="$SELECTED"
					fi
				else
					echo "Warning: Invalid number $part, skipping"
				fi
			else
				if [ -n "$result" ]; then
					result="$result,$part"
				else
					result="$part"
				fi
			fi
		done
		unset IFS

		if [ -z "$result" ]; then
			echo "Error: No valid selections"
			continue
		fi
		SELECTED_LANGS="$result"
		return 0
	done
}

# ── Title extraction helpers ─────────────────────────────────────────────────

# Extract a clean "Movie Name (Year)" from a filename.
# Removes common noise: dots, release groups, source tags, codecs, resolution, etc.
clean_filename() {
	name="$1"
	# Replace dots/underscores with spaces (but keep dots in numbers like 1995)
	cleaned=$(echo "$name" | sed 's/[_.]/ /g')
	# Remove common release patterns (case-insensitive)
	cleaned=$(echo "$cleaned" | sed 's/  */ /g' |
		sed -E 's/(Blu[ -]?[Rr]ay|BRRip|BDRip|BluRay)//g' |
		sed -E 's/(WEB[ -]?[Dd][Ll]|WEBRip|WEBDL|WEB)//g' |
		sed -E 's/(HDTV|DVDRip|DVD[ -]?[Rr]ip|HDTC|TC|CAM|TELESYNC|TeleSync)//g' |
		sed -E 's/(HDRip|HDLight|H264|H265|x264|x265|HEVC|AVC|AV1|XviD|DivX)//g' |
		sed -E 's/(720p|1080p|2160p|480p|4K|2K|UHD|HD|SD|FullHD)//g' |
		sed -E 's/(10bit|8bit|10-bit|8-bit)//g' |
		sed -E 's/(AMZN|NF|DSNP|HBO|HMAX|DDP?[0-9.]*|AAC[0-9.]*|Atmos|TrueHD|DTS[ -]?[A-Za-z0-9.]*|FLAC[0-9.]*|AC3[0-9.]*)//g' |
		sed -E 's/(\[[^]]*\])//g' |
		sed -E 's/(\([^)]*\))/\1/g' |
		sed -E 's/([0-9]{4})/\1 /g' |
		sed 's/  */ /g' | sed 's/^ *//;s/ *$//')
	echo "$cleaned"
}

# Extract metadata from video using mediainfo or ffprobe
extract_metadata() {
	file="$1"
	meta_title=""
	meta_year=""

	if command -v mediainfo >/dev/null 2>&1; then
		meta_title=$(mediainfo --Language=raw --Output="General;%Movie%" "$file" 2>/dev/null)
		if [ -z "$meta_title" ]; then
			meta_title=$(mediainfo --Language=raw --Output="General;%Title%" "$file" 2>/dev/null)
		fi
		if [ -z "$meta_title" ]; then
			meta_title=$(mediainfo --Language=raw --Output="General;%Album%" "$file" 2>/dev/null)
		fi
		meta_year=$(mediainfo --Language=raw --Output="General;%Released_Date%" "$file" 2>/dev/null | sed 's/-.*//')
		if [ -z "$meta_year" ]; then
			meta_year=$(mediainfo --Language=raw --Output="General;%Original_Released_Date%" "$file" 2>/dev/null | sed 's/-.*//')
		fi
	fi

	if [ -z "$meta_title" ] && command -v ffprobe >/dev/null 2>&1; then
		meta_title=$(ffprobe -v error -show_entries format_tags=title \
			-of default=noprint_wrappers=1:nokey=1 "$file" 2>/dev/null | head -1)
	fi

	if [ -z "$meta_year" ] && command -v ffprobe >/dev/null 2>&1; then
		raw_date=$(ffprobe -v error -show_entries format_tags=date \
			-of default=noprint_wrappers=1:nokey=1 "$file" 2>/dev/null | head -1)
		meta_year=$(echo "$raw_date" | sed 's/-.*//')
	fi

	META_TITLE="$meta_title"
	META_YEAR="$meta_year"

	# If title already contains (YYYY) matching META_YEAR, clear META_YEAR to avoid duplication
	if [ -n "$META_YEAR" ] && [ -n "$META_TITLE" ]; then
		embedded_year=$(echo "$META_TITLE" | sed -n 's/.*(\([0-9]\{4\}\)).*/\1/p')
		if [ "$embedded_year" = "$META_YEAR" ]; then
			META_YEAR=""
		fi
	fi
}

# ── Title selection ──────────────────────────────────────────────────────────

select_title() {
	file="$1"

	extract_metadata "$file"

	name_noext=$(basename "$file" | sed 's/\.[^.]*$//')
	cleaned_name=$(clean_filename "$name_noext")

	# Build metadata display
	meta_display="<none>"
	if [ -n "$META_TITLE" ] && [ -n "$META_YEAR" ]; then
		meta_display="$META_TITLE ($META_YEAR)"
	elif [ -n "$META_TITLE" ]; then
		meta_display="$META_TITLE"
	elif [ -n "$META_YEAR" ]; then
		meta_display="(year: $META_YEAR)"
	fi

	echo ""
	echo "Title for: $(basename "$file")"
	echo "----------------------------------------"
	echo "  1) From metadata: $meta_display"
	echo "  2) From filename: $cleaned_name"
	echo "  3) Custom (edit as 'Movie Name (year)')"
	echo ""

	printf "Choice [1]: "
	read choice
	choice=${choice:-1}

	case "$choice" in
	1)
		if [ -n "$META_TITLE" ] && [ -n "$META_YEAR" ]; then
			SELECTED_TITLE="$META_TITLE ($META_YEAR)"
		elif [ -n "$META_TITLE" ]; then
			SELECTED_TITLE="$META_TITLE"
		elif [ -n "$META_YEAR" ]; then
			SELECTED_TITLE="$cleaned_name ($META_YEAR)"
		else
			echo "Warning: No metadata found, falling back to cleaned filename"
			SELECTED_TITLE="$cleaned_name"
		fi
		;;
	2)
		SELECTED_TITLE="$cleaned_name"
		;;
	3)
		printf "Enter title: "
		read -r -e -i "$cleaned_name" user_title
		SELECTED_TITLE="${user_title:-$cleaned_name}"
		;;
	*)
		SELECTED_TITLE="$cleaned_name"
		;;
	esac
}

# ════════════════════════════════════════════════════════════════════════════
# Main
# ════════════════════════════════════════════════════════════════════════════

# ── Filter to supported video files ──────────────────────────────────────────

vid_count=0
for f in "$@"; do
	ext=$(echo "$f" | sed 's/.*\.//' | tr '[:upper:]' '[:lower:]')
	case "$ext" in
	mp4 | mkv | avi | mov | wmv | flv | m4v | webm | ogv | ts | m2ts | vob)
		eval "vid_$vid_count=\$f"
		vid_count=$((vid_count + 1))
		;;
	*)
		echo "Skipping unsupported: $(basename "$f")"
		;;
	esac
done

if [ "$vid_count" -eq 0 ]; then
	echo "Error: No supported video files found"
	echo "Supported: mp4 mkv avi mov wmv flv m4v webm ogv ts m2ts vob"
	echo "Press Enter to exit..."
	read
	exit 1
fi

# ── Title ────────────────────────────────────────────────────────────────────

if [ -n "$arg_title" ]; then
	TITLE="$arg_title"
elif [ -n "$SUBLIMINAL_TITLE" ]; then
	TITLE="$SUBLIMINAL_TITLE"
else
	# Use first video to pick title
	eval "first=\$vid_0"
	select_title "$first"
	TITLE="$SELECTED_TITLE"
fi

# ── Languages ────────────────────────────────────────────────────────────────

if [ -n "$arg_langs" ]; then
	LANGS="$arg_langs"
elif [ -n "$SUBLIMINAL_LANGS" ]; then
	LANGS="$SUBLIMINAL_LANGS"
else
	while true; do
		select_languages
		if [ $? -eq 0 ]; then
			LANGS="$SELECTED_LANGS"
			break
		fi
	done
fi

download_and_move() {
	file="$1"
	dir=$(dirname "$file")
	lang_args="$2"

	tmpdir=$(mktemp -d)

	provider_args=""
	if [ -n "$PROVIDER" ]; then
		provider_args="-p $PROVIDER"
	fi

	printf "Downloading subtitles...\n"

	subliminal download \
		$provider_args \
		$lang_args \
		-n "$TITLE" \
		--force-embedded-subtitles \
		-d "$tmpdir" \
		"$file" || true

	sub_count=0
	for sub in "$tmpdir"/*; do
		[ -f "$sub" ] || continue
		sub_count=$((sub_count + 1))
		sub_name=$(basename "$sub")
		dest="$dir/$sub_name"

		if [ -f "$dest" ]; then
			echo "Warning: $sub_name already exists"
			printf "Overwrite? [y/N]: "
			read ow_choice
			case "$ow_choice" in
			y | Y)
				rm -f "$dest"
				mv "$sub" "$dest"
				echo "Overwritten: $dest"
				;;
			*)
				counter=1
				while [ -f "$dir/${sub_name} (${counter})" ]; do
					counter=$((counter + 1))
				done
				mv "$sub" "$dir/${sub_name} (${counter})"
				echo "Saved as: $dir/${sub_name} (${counter})"
				;;
			esac
		else
			mv "$sub" "$dest"
			echo "Saved: $dest"
		fi
	done

	rm -rf "$tmpdir"
	return $sub_count
}

build_lang_args() {
	lang_args=""
	IFS=','
	for lang in $LANGS; do
		lang=$(echo "$lang" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
		[ -z "$lang" ] && continue
		lang_args="$lang_args -l $lang"
	done
	unset IFS
	echo "$lang_args"
}

echo ""
echo "Title:     $TITLE"
echo "Languages: $LANGS"
if [ -n "$PROVIDER" ]; then
	echo "Provider:  $PROVIDER"
else
	echo "Provider:  all defaults"
fi
echo ""

i=0
while [ "$i" -lt "$vid_count" ]; do
	eval "file=\$vid_$i"

	while true; do
		printf "\n--- %s ---\n" "$(basename "$file")"

		lang_args=$(build_lang_args)

		download_and_move "$file" "$lang_args"
		sub_count=$?

		echo ""
		if [ "$sub_count" -eq 0 ]; then
			echo "No subtitles found."
		else
			echo "$sub_count subtitle(s) downloaded."
		fi

		echo ""
		echo "Options:"
		echo "  1) Retry / download more with different language"
		echo "  2) Change title and retry"
		echo "  3) Next video"
		echo "  4) Exit"
		echo ""
		printf "Choice [3]: "
		read next_choice
		next_choice=${next_choice:-3}

		case "$next_choice" in
		1)
			select_languages
			if [ $? -eq 0 ]; then
				LANGS="$SELECTED_LANGS"
				echo ""
				echo "Languages: $LANGS"
				echo ""
			fi
			continue
			;;
		2)
			select_title "$file"
			TITLE="$SELECTED_TITLE"
			echo ""
			echo "Title: $TITLE"
			echo ""
			continue
			;;
		3)
			break
			;;
		4)
			exit 0
			;;
		*)
			break
			;;
		esac
	done

	i=$((i + 1))
done
