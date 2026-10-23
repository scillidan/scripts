#!/bin/sh
# Notes:
#   1. Clone and download all plugins written by comments.
#   2. Run this script to setup plugins and dotfiles (from https://github.com/scillidan/dotfiles/tree/main/.config/mpv).
#   3. Add mpvc.sh into PATH.
#   4. Usage as `mpvc video "$@"`

# Custom user environment variables here
case "$(uname -s)" in
MINGW* | MSYS*)
	# Windows (git bash). Native symlinks need Developer Mode or admin.
	export MSYS=winsymlinks:nativestrict
	WINDOWS=1
	MPV_CONF="$USERHOME/Share/dotfiles/.config/mpv"
	MPV_SRC="$USERHOME/Local/Source/mpv"
	MPV_DL="$USERHOME/Local/Download/mpv"
	DATA_ROOT="$USERHOME/Local/Data"
	MPV_DATA="$SCOOP/apps/mpv/current/portable_config"
	;;
*)
	MPV_CONF="$USERHOME/.config/_mpv"
	MPV_SRC="$USERHOME/Usr/Source/mpv"
	MPV_DL="$USERHOME/Usr/Download/mpv"
	DATA_ROOT="$USERHOME/Usr/Data"
	MPV_DOTDIR="$USERHOME/.config/mpv"
	;;
esac

MPVC_VIDEO="$DATA_ROOT/mpvc_video"
MPVC_MANGA="$DATA_ROOT/mpvc_manga"
MPVC_MUSIC="$DATA_ROOT/mpvc_music"
MPVC_ALL="$MPVC_VIDEO $MPVC_MANGA $MPVC_MUSIC"

rm_tree() {
	# cmd's rmdir is junction-aware; MSYS rm -rf would recurse into a
	# junction and delete the link target. NO_PATHCONV keeps /S /Q literal, so the
	# cmd invocation below must use /c (//c would no longer be converted).
	if [ -n "$WINDOWS" ]; then
		MSYS_NO_PATHCONV=1 cmd /c rmdir /S /Q "$(cygpath -w "$1")" 2>/dev/null
	else
		rm -rf "$1"
	fi
}

for d in $MPVC_ALL; do
	# Only recreate the managed subdirectories. Keep watch-later, screenshots,
	# chapters, fonts and logs intact between runs.
	for s in scripts script-modules script-opts shaders; do
		rm_tree "$d/$s"
		mkdir -p "$d/$s"
	done
	mkdir -p "$d/fonts" "$d/_screenshot"
done

INCLUDE="$MPV_CONF/include"
cat "$INCLUDE/global.conf" "$INCLUDE/video.conf" >"$MPVC_VIDEO/mpv.conf"
cat "$INCLUDE/global.conf" "$INCLUDE/music.conf" >"$MPVC_MUSIC/mpv.conf"
cat "$INCLUDE/global.conf" "$INCLUDE/manga.conf" >"$MPVC_MANGA/mpv.conf"

INPUT="$MPV_CONF/input"
cat "$INPUT/global.conf" >"$MPVC_VIDEO/input.conf"
cat "$INPUT/global.conf" >"$MPVC_MUSIC/input.conf"
cat "$INPUT/global.conf" "$INPUT/manga.conf" >"$MPVC_MANGA/input.conf"

CONFIG_GLOBAL="$MPVC_VIDEO $MPVC_MUSIC $MPVC_MANGA"
for d in $CONFIG_GLOBAL; do
	# 1. Get uosc.zip from https://github.com/tomasklaen/uosc/releases.
	# 2. Decompress to `uosc/`.
	# 3. Install `uosc/fonts/*.ttf`.
	ln -s "$MPV_DL/uosc/scripts/uosc" "$d/scripts/uosc"
	ln -s "$MPV_CONF/script-opts/uosc.conf" "$d/script-opts/uosc.conf"

	# git clone --depth=1 https://github.com/po5/thumbfast
	ln -s "$MPV_SRC/thumbfast/thumbfast.lua" "$d/scripts/thumbfast.lua"
	ln -s "$MPV_SRC/thumbfast/thumbfast.conf" "$d/script-opts/thumbfast.conf"

	# 1. Get HDR-Toys.zip from https://github.com/natural-harmonia-gropius/hdr-toys/releases.
	# 2. Decompress to `hdr-toys/`.
	# The git clone only ships the JS variant, so the release zip is the source.
	ln -s "$MPV_SRC/hdr-toys/shaders/hdr-toys" "$d/shaders/hdr-toys"
	ln -s "$MPV_DL/hdr-toys/scripts/hdr-toys-helper.lua" "$d/scripts/hdr-toys-helper.lua"
	cat "$MPV_DL/hdr-toys/hdr-toys.conf" >>"$d/mpv.conf"
	cat "$INCLUDE/hdr-toys-override.conf" >>"$d/mpv.conf"

	# git clone --depth=1 https://github.com/hhirtz/mpv-retro-shaders
	ln -s "$MPV_SRC/mpv-retro-shaders" "$d/shaders/mpv-retro-shaders"
	cat "$MPV_SRC/mpv-retro-shaders/all.conf" >>"$d/mpv.conf"

	echo File

	# git clone --depth=1 https://github.com/cogentredtester/mpv-scripts mpv-scripts@cogentredtester
	ln -s "$MPV_SRC/mpv-scripts@cogentredtester/editions-notification.lua" "$d/scripts/editions-notification.lua"

	# git clone --depth=1 https://github.com/Hill-98/mpv-config mpv-config@Hill-98
	ln -s "$MPV_SRC/mpv-config@Hill-98/scripts/format-filename.js" "$d/scripts/format-filename.js"

	# git clone --depth=1 https://github.com/sibwaf/mpv-scripts mpv-scripts@sibwaf
	ln -s "$MPV_SRC/mpv-scripts@sibwaf/fuzzydir.lua" "$d/scripts/fuzzydir.lua"
	ln -s "$MPV_SRC/mpv-scripts@sibwaf/reload.lua" "$d/scripts/reload.lua"

	# git clone --depth=1 https://github.com/Kayizoku/mpv-rename
	ln -s "$MPV_SRC/mpv-rename/Rename.lua" "$d/scripts/Rename.lua"
	# git clone --depth=1 https://github.com/CogentRedTester/mpv-user-input
	ln -s "$MPV_SRC/mpv-user-input/user-input.lua" "$d/scripts/user-input.lua"
	ln -s "$MPV_SRC/mpv-user-input/user-input-module.lua" "$d/script-modules/user-input-module.lua"

	echo Play

	# Get auto-save-state.lua from https://github.com/AN3223/dotfiles/blob/master/.config/mpv/scripts/auto-save-state.lua.
	ln -s "$MPV_DL/auto-save-state.lua" "$d/scripts/auto-save-state.lua"

	# git clone --depth=1 https://github.com/po5/memo
	ln -s "$MPV_SRC/memo/memo.lua" "$d/scripts/memo.lua"
	ln -s "$MPV_CONF/script-opts/memo.conf" "$d/script-opts/memo.conf"

	# git clone --depth=1 https://github.com/sibwaf/mpv-scripts mpv-scripts@sibwaf
	ln -s "$MPV_CONF/scripts/blackout.lua" "$d/scripts/blackout.lua"

	# git clone --depth=1 https://github.com/zc62/mpv-scripts mpv-scripts@zc62
	ln -s "$MPV_SRC/mpv-scripts@zc62/exit-fullscreen.lua" "$d/scripts/exit-fullscreen.lua"

	# git clone --depth=1 https://github.com/wishyu/mpv-ontop-window
	ln -s "$MPV_SRC/mpv-ontop-window/ontop-window.lua" "$d/scripts/ontop-window.lua"

	# git clone --depth=1 https://github.com/mpv-player/mpv
	ln -s "$MPV_SRC/mpv/TOOLS/lua/ontop-playback.lua" "$d/scripts/ontop-playback.lua"

	echo Chapter

	# git clone --depth=1 https://github.com/mar04/chapters_for_mpv
	ln -s "$MPV_SRC/chapters_for_mpv/chapters.lua" "$d/scripts/chapters.lua"
	ln -s "$MPV_CONF/script-opts/chapters.conf" "$d/script-opts/chapters.conf"

	# git clone --depth=1 https://github.com/dyphire/mpv-scripts mpv-scripts@dyphire
	ln -s "$MPV_SRC/mpv-scripts@dyphire/chapter-make-read.lua" "$d/scripts/chapter-make-read.lua"

	echo Subtitle

	# git clone --depth=1 https://github.com/joaquintorres/autosubsync-mpv
	ln -s "$MPV_SRC/autosubsync-mpv" "$d/scripts/autosubsync-mpv"
	ln -s "$MPV_CONF/script-opts/autosubsync.conf" "$d/script-opts/autosubsync.conf"

	# git clone --depth=1 https://github.com/zenwarr/mpv-config mpv-config@zenwarr
	# ln -s "$MPV_SRC/mpv-config@zenwarr/scripts/restore-subtitles.lua" "$d/scripts/restore-subtitles.lua"

	# git clone --depth=1 https://github.com/pzim-devdata/mpv-scripts mpv-scripts@pzim-devdata
	ln -s "$MPV_SRC/mpv-scripts@pzim-devdata/mpv-sub_not_forced_not_sdh.lua" "$d/scripts/mpv-sub_not_forced_not_sdh.lua"

	# git clone --depth=1 https://github.com/magnum357i/mpv-dualsubtitles
	ln -s "$MPV_SRC/mpv-dualsubtitles/dualsubtitles.lua" "$d/scripts/dualsubtitles.lua"
	ln -s "$MPV_CONF/script-opts/dualsubtitles.conf" "$d/script-opts/dualsubtitles.conf"

	# git clone --depth=1 https://github.com/genfu94/mpv-subtitle-retimer
	ln -s "$MPV_SRC/mpv-subtitle-retimer/src" "$d/scripts/mpv-subtitle-retimer"

	# git clone --depth=1 https://github.com/christoph-heinrich/mpv-subtitle-lines
	ln -s "$MPV_SRC/mpv-subtitle-lines/subtitle-lines.lua" "$d/scripts/subtitle-lines.lua"

	# git clone --depth=1 https://github.com/magnum357i/mpv-sidebarsubtitles
	ln -s "$MPV_SRC/mpv-sidebarsubtitles/sidebarsubtitles" "$d/scripts/sidebarsubtitles"

	echo Stream

	# git clone --depth=1 https://github.com/mpv-player/mpv
	ln -s "$MPV_SRC/mpv/TOOLS/lua/autoload.lua" "$d/scripts/autoload.lua"
	ln -s "$MPV_CONF/script-opts/autoload.conf" "$d/script-opts/autoload.conf"

	# git clone --depth=1 https://github.com/mrxdst/webtorrent-mpv-hook
	ln -s "$MPV_SRC/webtorrent-mpv-hook/build/webtorrent.js" "$d/scripts/webtorrent.js"
	ln -s "$MPV_CONF/script-opts/webtorrent.conf" "$d/script-opts/webtorrent.conf"

	echo Other

	# git clone --depth=1 https://github.com/CogentRedTester/mpv-scroll-list
	ln -s "$MPV_SRC/mpv-scroll-list/scroll-list.lua" "$d/script-modules/scroll-list.lua"

	# git clone --depth=1 https://github.com/shadax1/mpv_segment_length
	ln -s "$MPV_SRC/mpv_segment_length/mpv_segment_length.lua" "$d/scripts/mpv_segment_length.lua"

	# git clone --depth=1 https://github.com/cogentredtester/mpv-scripts mpv-scripts@cogentredtester
	ln -s "$MPV_SRC/mpv-scripts@cogentredtester/show-errors.lua" "$d/scripts/show-errors.lua"
done

for d in $MPVC_VIDEO; do
	# git clone --depth=1 https://github.com/po5/celebi
	ln -s "$MPV_SRC/celebi/celebi.lua" "$d/scripts/celebi.lua"
	ln -s "$MPV_CONF/script-opts/celebi.conf" "$d/script-opts/celebi.conf"

	# git clone --depth=1 https://github.com/ctlaltdefeat/mpv-open-imdb-page
	ln -s "$MPV_SRC/mpv-open-imdb-page" "$d/scripts/mpv-open-imdb-page"
done

echo music config

for d in $MPVC_MUSIC; do
	# git clone --depth=1 https://github.com/thinkmcflythink/mpv-loudnorm
	ln -s "$MPV_SRC/mpv-loudnorm" "$d/scripts/real_loudnorm"

	# git clone --depth=1 https://github.com/cogentredtester/mpv-coverart
	ln -s "$MPV_SRC/mpv-coverart/coverart.lua" "$d/scripts/coverart.lua"
	ln -s "$MPV_CONF/script-opts/coverart.conf" "$d/script-opts/coverart.conf"

	# git clone --depth=1 https://github.com/cogentredtester/mpv-scripts mpv-scripts@cogentredtester
	ln -s "$MPV_SRC/mpv-scripts@cogentredtester/save-playlist.lua" "$d/scripts/save-playlist.lua"
done

CONFIG_DIR_MANGA="$MPVC_MANGA"
for d in $CONFIG_DIR_MANGA; do
	# git clone --depth=1 https://github.com/occivink/mpv-gallery-view
	ln -s "$MPV_SRC/mpv-gallery-view/script-modules/gallery.lua" "$d/script-modules/gallery.lua"
	ln -s "$MPV_SRC/mpv-gallery-view/scripts/gallery-thumbgen.lua" "$d/scripts/gallery-thumbgen.lua"
	ln -s "$MPV_SRC/mpv-gallery-view/scripts/playlist-view.lua" "$d/scripts/playlist-view.lua"
	ln -s "$MPV_CONF/script-opts/playlist_view.conf" "$d/script-opts/playlist_view.conf"

	# git clone --depth=1 https://github.com/guidocella/mpv-image-config
	ln -s "$MPV_SRC/mpv-image-config/scripts/image-bindings.lua" "$d/scripts/image-bindings.lua"
	ln -s "$MPV_CONF/script-opts/image_bindings.conf" "$d/script-opts/image_bindings.conf"
	# mpv-image-config starts with global options, so return to global scope
	# first (manga.conf ends with the [silent] profile).
	printf '[default]\n' >>"$d/mpv.conf"
	cat "$MPV_SRC/mpv-image-config/mpv.conf" >>"$d/mpv.conf"
	cat "$MPV_SRC/mpv-image-config/input.conf" >>"$d/input.conf"

	# git clone --depth=1 https://github.com/occivink/mpv-image-viewer
	ln -s "$MPV_SRC/mpv-image-viewer/scripts/freeze-window.lua" "$d/scripts/freeze-window.lua"
	ln -s "$MPV_SRC/mpv-image-viewer/scripts/image-positioning.lua" "$d/scripts/image-positioning.lua"
	ln -s "$MPV_SRC/mpv-image-viewer/scripts/minimap.lua" "$d/scripts/minimap.lua"
	ln -s "$MPV_SRC/mpv-image-viewer/scripts/status-line.lua" "$d/scripts/status-line.lua"
	ln -s "$MPV_SRC/mpv-image-viewer/scripts/detect-image.lua" "$d/scripts/detect-image.lua"
	ln -s "$MPV_CONF/script-opts/image_positioning.conf" "$d/script-opts/image_positioning.conf"
	ln -s "$MPV_CONF/script-opts/minimap.conf" "$d/script-opts/minimap.conf"
	ln -s "$MPV_CONF/script-opts/status_line.conf" "$d/script-opts/status_line.conf"
	ln -s "$MPV_CONF/script-opts/detect_image.conf" "$d/script-opts/detect_image.conf"
	cat "$INCLUDE/manga-override.conf" >>"$d/mpv.conf"

	# git clone --depth=1 https://github.com/dudemanguy/mpv-manga-reader
	ln -s "$MPV_SRC/mpv-manga-reader/manga-reader.lua" "$d/scripts/manga-reader.lua"

	# git clone --depth=1 https://github.com/jonniek/mpv-nextfile
	ln -s "$MPV_SRC/mpv-nextfile/nextfile.lua" "$d/scripts/nextfile.lua"
done

if [ -n "$WINDOWS" ]; then
	# Only remove the link itself. Never recurse here: a wrong path must not wipe a real directory.
	if [ -e "$MPV_DATA" ] || [ -L "$MPV_DATA" ]; then
		MSYS_NO_PATHCONV=1 cmd /c rmdir "$(cygpath -w "$MPV_DATA")"
	fi
	MSYS_NO_PATHCONV=1 cmd /c mklink /J "$(cygpath -w "$MPV_DATA")" "$(cygpath -w "$MPVC_VIDEO")"
else
	rm -rf "$MPV_DOTDIR"
	cp -r "$MPVC_VIDEO" "$MPV_DOTDIR"
fi
