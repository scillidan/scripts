#!/bin/sh

# Custom user environment variables here
case "$(uname -s)" in
MINGW* | MSYS*)
	WINDOWS=1
	DATA_ROOT="$USERHOME/Local/Data"
	;;
*)
	DATA_ROOT="$USERHOME/Usr/Data"
	;;
esac

MPVC_VIDEO="$DATA_ROOT/mpvc_video"
MPVC_MUSIC="$DATA_ROOT/mpvc_music"
MPVC_MANGA="$DATA_ROOT/mpvc_manga"

case "$1" in
video) CONFIG_DIR="$MPVC_VIDEO" ;;
music) CONFIG_DIR="$MPVC_MUSIC" ;;
manga) CONFIG_DIR="$MPVC_MANGA" ;;
*)
	echo "Invalid config"
	exit 1
	;;
esac
shift

if [ -n "$WINDOWS" ]; then
	# Detach like `start` does in cmd, so the terminal stays usable.
	# Use mpv.exe, not "mpv": the scoop mpv dir ships an mpv\ subdirectory,
	# and bash PATH lookup skips the .exe/.com fallback once a bare-name match
	# exists, so plain "mpv" is unresolvable here (cmd's PATHEXT search is immune).
	(mpv.exe --idle --config-dir="$CONFIG_DIR" --force-window --keep-open=yes "$@" </dev/null &)
else
	mpv --idle --config-dir="$CONFIG_DIR" --force-window --keep-open=yes "$@"
fi

exit 0
