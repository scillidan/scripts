#!/bin/sh
# Play MIDI files with FluidSynth, supporting fzf selection of
# soundfonts and MIDI files, with optional WAV output.
#
# Prerequisites: fluidsynth, fzf
#
# Usage:
#   Windows:
#     Create a .lnk shortcut to this script in the SendTo folder, then:
#     Select files > Right-click > Send To > fluintsynth_mids
#
#   Linux (Thunar):
#     Edit > Configure custom actions > Add action with command: /path/to/script.sh %F
#
#   Command line:
#     ./script.sh <file1> <file2> ...
#
#     With a .mid file, fzf-pick a .sf2/.sf3/.sf4 soundfont from
#     $SOUNDFONT_PATH (default ~/.soundfonts), play, ask for optional
#     WAV output filename (default: same as input .mid file), then exit.

SOUNDFONT_PATH="${SOUNDFONT_PATH:-$HOME/.soundfonts}"
MID_PATH="${MID_PATH:-$HOME/.mids}"

if ! command -v fluidsynth >/dev/null 2>&1; then
    echo "Error: fluidsynth not found in PATH"
    exit 1
fi

if ! command -v fzf >/dev/null 2>&1; then
    echo "Error: fzf not found in PATH"
    exit 1
fi

SF_EXTS="sf2 sf3 sf4 sfz dls gig"
MID_EXTS="mid midi smf"

is_sf() {
    ext="${1##*.}"
    ext_lower=$(echo "$ext" | tr '[:upper:]' '[:lower:]')
    for e in $SF_EXTS; do
        [ "$ext_lower" = "$e" ] && return 0
    done
    return 1
}

is_mid() {
    ext="${1##*.}"
    ext_lower=$(echo "$ext" | tr '[:upper:]' '[:lower:]')
    for e in $MID_EXTS; do
        [ "$ext_lower" = "$e" ] && return 0
    done
    return 1
}

select_sf() {
    if [ ! -d "$SOUNDFONT_PATH" ]; then
        echo "Error: SOUNDFONT_PATH not found: $SOUNDFONT_PATH"
        return 1
    fi
    choice=$(find "$SOUNDFONT_PATH" -maxdepth 1 -type f \( -iname "*.sf2" -o -iname "*.sf3" -o -iname "*.sf4" -o -iname "*.sfz" -o -iname "*.dls" -o -iname "*.gig" \) 2>/dev/null | fzf --prompt="SoundFont > " --preview="echo {}")
    if [ -n "$choice" ]; then
        echo "$choice"
        return 0
    fi
    return 1
}

select_mid() {
    if [ ! -d "$MID_PATH" ]; then
        echo "Error: MID_PATH not found: $MID_PATH"
        return 1
    fi
    choice=$(find "$MID_PATH" -maxdepth 1 -type f \( -iname "*.mid" -o -iname "*.midi" -o -iname "*.smf" \) 2>/dev/null | fzf --prompt="MIDI > " --preview="echo {}")
    if [ -n "$choice" ]; then
        echo "$choice"
        return 0
    fi
    return 1
}

detect_audio_driver() {
    if command -v pactl >/dev/null 2>&1 || command -v pw-cli >/dev/null 2>&1; then
        echo "pulseaudio"
    elif [ -e /dev/snd/seq ] 2>/dev/null; then
        echo "alsa"
    elif command -v clip.exe >/dev/null 2>&1; then
        echo "dsound"
    else
        echo "pulseaudio"
    fi
}

if [ $# -eq 0 ]; then
    echo "Error: No input files"
    echo "Press Enter to exit..."
    read dummy
    exit 1
fi

input="$1"

if is_mid "$input"; then
    mid="$input"
    sf=$(select_sf) || { echo "Press Enter to exit..."; read dummy; exit 1; }
elif is_sf "$input"; then
    sf="$input"
    mid=$(select_mid) || { echo "Press Enter to exit..."; read dummy; exit 1; }
else
    echo "Error: Unsupported file type: $input"
    echo "Expected: .mid/.midi/.smf or .sf2/.sf3/.sf4/.sfz/.dls/.gig"
    echo "Press Enter to exit..."
    read dummy
    exit 1
fi

basename_noext=$(basename "$mid" | sed 's/\.[^.]*$//')
dir=$(dirname "$mid")
out_wav="${dir}/${basename_noext}.wav"

printf "SoundFont: %s\n" "$sf"
printf "MIDI:      %s\n" "$mid"

printf "\nOutput WAV (Enter for default: %s): " "$out_wav"
read custom_out
if [ -n "$custom_out" ]; then
    case "$custom_out" in
        *.wav) out_wav="$dir/$custom_out" ;;
        *) out_wav="$dir/$custom_out.wav" ;;
    esac
fi

audio_driver=$(detect_audio_driver)

printf "\nPlaying...\n"

fluidsynth -a "$audio_driver" -r 48000 -c 2 -z 1024 -g 2 -F "$out_wav" "$sf" "$mid" 2>&1 | while IFS= read -r line; do
    printf "\r%s" "$line"
done

printf "\nDone.\n"
