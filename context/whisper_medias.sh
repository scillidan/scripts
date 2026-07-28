#!/bin/sh
# Transcribe audio/video files to SRT using whisper.cpp
#
# Models:
#   Default: https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3-turbo.bin
#   Chinese: https://huggingface.co/BELLE-2/Belle-whisper-large-v3-turbo-zh-ggml
#
# Supported formats:
#   Audio: mp3, wav, flac, ogg, m4a, m4b, aac, wma, ape, opus
#   Video: mp4, mkv, webm, avi, mov, wmv, flv, m4v
#
# Install:
#   1. With CPU: scoop install whisper-cpp
#   2. With GPU (e.g. CUDA v12.9 ):
#     1. git clone https://github.com/ggerganov/whisper.cpp
#     2. cd whisper.cpp
#     3. cmake -S . -B build -DGGML_CUDA=ON -DCMAKE_CUDA_ARCHITECTURES=89 -DCUDAToolkit_ROOT="C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v12.9"
#     4. cmake --build build --config Release
#     5. Add `<path_to>\whisper.cpp\build\bin\Release` into PATH
#
# Usage:
#   Windows:
#     Create a .lnk shortcut to this script in the SendTo folder, then:
#     Select files > Right-click > Send To > whisper_medias
#
#   Linux (Thunar):
#     Edit > Configure custom actions > Add action with command: /path/to/script.sh %F
#
#   Command line:
#     ./script.sh <file1> <file2> ...

MODEL_DIR="$USERHOME/Local/Model/whisper-cpp"
MODEL_DEFAULT="$MODEL_DIR/ggml-large-v3-turbo.bin"
MODEL_ZH="$MODEL_DIR/Belle-whisper-large-v3-turbo-zh-ggml.bin"

SCRIPT_DIR=$(dirname "$(readlink -f "$0" 2>/dev/null || echo "$0")")

# Whisper supported languages (99 total):
# https://github.com/openai/whisper/blob/main/whisper/tokenizer.py
COMMON_LANGUAGES="Arabic:ar Belarusian:be Bulgarian:bg Catalan:ca Czech:cs Danish:da German:de Greek:el English:en Spanish:es Estonian:et Persian:fa Finnish:fi French:fr Galician:gl Croatian:hr Hungarian:hu Indonesian:id Italian:it Japanese:ja Korean:ko Latin:la Lithuanian:lt Malagasy:mg Malay:ml Mongolian:mn Dutch:nl Norwegian:no Polish:pl Portuguese:pt Romanian:ro Russian:ru Slovak:sk Albanian:sq Serbian:sr Swahili:sw Swedish:sv Tamil:ta Telugu:te Thai:th Tagalog:tl Turkish:tr Ukrainian:uk Urdu:ur Vietnamese:vi Yoruba:yo Simplified-Chinese:zh Traditional-Chinese:zh-tw"

OTHER_LANGUAGES="Afrikaans:af Amharic:am Assamese:as Azerbaijani:az Bashkir:ba Bosnian:bs Breton:br Tibetan:bo Welsh:cy Esperanto:eo Basque:eu Faroese:fo Gujarati:gu Hausa:ha Hawaiian:haw Haitian:ht Armenian:hy Icelandic:is Javanese:jw Georgian:ka Kazakh:kk Khmer:km Kannada:kn Luxembourgish:lb Lingala:ln Lao:lo Latvian:lv Maori:mi Macedonian:mk Marathi:mr Maltese:mt Myanmar:my Nepali:ne Norwegian-Nynorsk:nn Occitan:oc Panjabi:pa Pashto:ps Sanskrit:sa Sindhi:sd Sinhala:si Slovenian:sn Somali:so Sundanese:su Tajik:tg Turkmen:tk Tatar:tt Uighur:ug Uzbek:uz Yiddish:yi"

show_languages() {
	cols=0
	num=1
	for entry in $COMMON_LANGUAGES; do
		name="${entry%%:*}"
		code="${entry#*:}"
		printf "%3d) %-24s %s" "$num" "$name" "$code"
		cols=$((cols + 1))
		if [ $((cols % 2)) -eq 0 ]; then
			printf "\n"
		fi
		num=$((num + 1))
	done

	if [ $((cols % 2)) -ne 0 ]; then
		printf "\n"
	fi

	printf "%3d) %s\n" "$num" "Other-Languages..."
}

show_other_languages() {
	cols=0
	num=1
	for entry in $OTHER_LANGUAGES; do
		name="${entry%%:*}"
		code="${entry#*:}"
		printf "%3d) %-24s %s" "$num" "$name" "$code"
		cols=$((cols + 1))
		if [ $((cols % 2)) -eq 0 ]; then
			printf "\n"
		fi
		num=$((num + 1))
	done

	if [ $((cols % 2)) -ne 0 ]; then
		printf "\n"
	fi
}

select_other_language() {
	prompt="$1"

	while true; do
		echo ""
		echo "$prompt (Other Languages)"
		echo "----------------------------------------"
		echo "WARNING: Transcription quality not guaranteed for these languages"
		echo ""
		show_other_languages
		echo ""
		printf "Enter number or code (e.g. af, bo, jw): "
		read choice

		if [ -z "$choice" ]; then
			echo "Error: Selection required"
			continue
		fi

		if echo "$choice" | grep -qE '^[0-9]+$'; then
			if [ "$choice" -ge 1 ] && [ "$choice" -le "$(echo "$OTHER_LANGUAGES" | wc -w)" ]; then
				SELECTED=$(echo "$OTHER_LANGUAGES" | cut -d' ' -f"$choice" | cut -d: -f2)
				return 0
			fi
		fi

		SELECTED="$choice"
		return 0
	done
}

select_language() {
	prompt="$1"

	while true; do
		echo ""
		echo "$prompt"
		echo "----------------------------------------"
		show_languages
		common_total=$(echo "$COMMON_LANGUAGES" | wc -w)
		echo ""
		printf "Enter number or code (e.g. en, zh): "
		read choice

		if [ -z "$choice" ]; then
			echo "Error: Selection required"
			continue
		fi

		if echo "$choice" | grep -qE '^[0-9]+$'; then
			if [ "$choice" -ge 1 ] && [ "$choice" -le "$common_total" ]; then
				SELECTED=$(echo "$COMMON_LANGUAGES" | cut -d' ' -f"$choice" | cut -d: -f2)
				return 0
			fi

			if [ "$choice" -eq "$((common_total + 1))" ]; then
				select_other_language "$prompt"
				return $?
			fi
		fi

		SELECTED="$choice"
		return 0
	done
}

if [ $# -eq 0 ]; then
	echo "Error: No files selected"
	echo "Press Enter to exit..."
	read
	exit 1
fi

if ! command -v whisper-cli >/dev/null 2>&1; then
	echo "Error: whisper-cli not found"
	echo "Press Enter to exit..."
	read
	exit 1
fi

select_language "Transcription Language"
LANG="$SELECTED"

if [ "$LANG" = "zh-tw" ] || [ "$LANG" = "zh_tw" ] || [ "$LANG" = "zh-TW" ] || [ "$LANG" = "zh_TW" ]; then
	MODEL="$MODEL_ZH"
	PROMPT="使用繁體中文，正確使用標點符號。"
elif [ "$LANG" = "zh" ] || [ "$LANG" = "zh-cn" ] || [ "$LANG" = "zh_CN" ]; then
	MODEL="$MODEL_ZH"
	PROMPT="使用简体中文，正确使用标点符号。"
else
	MODEL="$MODEL_DEFAULT"
	PROMPT="Transcribe with proper punctuation, capitalize proper nouns."
fi

select_output_mode() {
	echo ""
	echo "Output Mode"
	echo "----------------------------------------"
	echo "1) Only .srt (default)"
	echo "2) .srt + _no-punc.srt (punctuation -> spaces)"
	printf "Enter choice (1/2, default: 1): "
	read mode_choice
	if [ -z "$mode_choice" ] || [ "$mode_choice" = "1" ]; then
		OUTPUT_MODE=1
	else
		OUTPUT_MODE=2
	fi
}
select_output_mode

if [ ! -f "$MODEL" ]; then
	echo "Error: Model not found: $MODEL"
	echo "Press Enter to exit..."
	read
	exit 1
fi

printf "\nTranscribing with language: %s\n" "$LANG"
printf "Model: %s\n" "$(basename "$MODEL")"

error=0
total=$#
n=0

for file in "$@"; do
	n=$((n + 1))
	dir=$(dirname "$file")
	basename_noext=$(basename "$file" | sed 's/\.[^.]*$//')
	outbase="$dir/$basename_noext.[whisper].$LANG"

	ext="${file##*.}"
	case "$ext" in
	flac | mp3 | ogg | wav)
		audio_file="$file"
		cleanup=0
		;;
	*)
		if ! command -v ffmpeg >/dev/null 2>&1; then
			echo "[$n/$total] Warning: ffmpeg not found, $ext not supported natively"
			echo "Skipping: $file"
			error=1
			continue
		fi
		audio_file="$dir/$basename_noext._tmp.wav"
		printf "[%d/%d] Converting to wav..." "$n" "$total"
		if ! ffmpeg -nostdin -i "$file" -vn -acodec pcm_s16le -ar 16000 -ac 1 -y "$audio_file" 2>/dev/null; then
			echo ""
			echo "[$n/$total] Error: Failed to convert $file to wav"
			error=1
			continue
		fi
		printf " done."
		cleanup=1
		;;
	esac

	printf "\n[%d/%d] %s\n" "$n" "$total" "$(basename "$file")"

	if ! whisper-cli \
		-m "$MODEL" \
		-t 16 \
		-of "$outbase" \
		-osrt \
		-ml 30 \
		--prompt "$PROMPT" \
		-sns \
		-l "$LANG" \
		-f "$audio_file" \
		>/dev/null; then
		[ "$cleanup" = 1 ] && rm -f "$audio_file"
		echo "[$n/$total] Error: Failed to transcribe $file"
		error=1
		continue
	fi

	[ "$cleanup" = 1 ] && rm -f "$audio_file"

	printf "[%d/%d] Done: %s.srt\n" "$n" "$total" "$outbase"

	sed -i '1s/^\xEF\xBB\xBF//' "${outbase}.srt" 2>/dev/null
	printf '\xEF\xBB\xBF' | cat - "${outbase}.srt" >"${outbase}.srt.tmp" && mv "${outbase}.srt.tmp" "${outbase}.srt"

	sed -i 's/^[,，、。.！!？?；;：:]//' "${outbase}.srt" 2>/dev/null

	python "$SCRIPT_DIR/lib/whisper_medias.py" fix "${outbase}.srt" || {
		echo "[$n/$total] Error: Fix failed for ${outbase}.srt"
		error=1
	}

	if [ "$OUTPUT_MODE" = "2" ]; then
		python "$SCRIPT_DIR/lib/whisper_medias.py" nopunc "${outbase}.srt" "${outbase}_no-punc.srt" || {
			echo "[$n/$total] Error: nopunc failed for ${outbase}.srt"
			error=1
		}
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
