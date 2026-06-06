@echo off
rem 1. Clone and download all plugins written by comments.
rem 2. Run this script to setup plugins and dotfiles (from https://github.com/scillidan/dotfiles/tree/main/.config/_mpv).
rem 3. Add https://github.com/scillidan/Shell/blob/main/_windows/mpvc.bat into PATH.
rem 4. Usage as `mpvc video %*`

setlocal

set "MPV_DATA=%SCOOP%\apps\mpv\current\portable_config"
rem Custom user environment variables here
set "MPV_CONF=%USERHOME%\Usr\Git\dotfiles\.config\_mpv"
set "MPV_SRC=%USERHOME%\Usr\Source\mpv"
set "MPV_DL=%USERHOME%\Usr\Download\mpv"

set "MPVC_VIDEO=%USERHOME%\Usr\Data\mpvc_video"
set "MPVC_MANGA=%USERHOME%\Usr\Data\mpvc_manga"
set "MPVC_MUSIC=%USERHOME%\Usr\Data\mpvc_music"
set "MPVC_ALL=%MPVC_GLOBAL% %MPVC_VIDEO% %MPVC_MANGA% %MPVC_MUSIC%"
for %%d in (%MPVC_ALL%) do (
    rmdir /S /Q "%%d"
    mkdir "%%d"
    mkdir "%%d\fonts"
    mkdir "%%d\scripts"
    mkdir "%%d\script-modules"
    mkdir "%%d\script-opts"
    mkdir "%%d\shaders"
)

set "INCLUDE=%MPV_CONF%\include"
type "%INCLUDE%\global.conf" "%INCLUDE%\video.conf" > "%MPVC_VIDEO%\mpv.conf"
type "%INCLUDE%\global.conf" "%INCLUDE%\music.conf" > "%MPVC_MUSIC%\mpv.conf"
type "%INCLUDE%\global.conf" "%INCLUDE%\manga.conf" > "%MPVC_MANGA%\mpv.conf"

set "INPUT=%MPV_CONF%\input"
type "%INPUT%\global.conf" > "%MPVC_VIDEO%\input.conf"
type "%INPUT%\global.conf" > "%MPVC_MUSIC%\input.conf"
type "%INPUT%\global.conf" "%INPUT%\manga.conf" > "%MPVC_MANGA%\input.conf"

set "CONFIG_GLOBAL=%MPVC_VIDEO% %MPVC_MUSIC% %MPVC_MANGA%"
for %%d in (%CONFIG_GLOBAL%) do (
    rem 1. Get uosc.zip from https://github.com/tomasklaen/uosc/releases.
    rem 2. Decompress to `uosc/`.
    rem 3. Install `uosc/fonts/*.ttf`.
    mklink /J "%%d\scripts\uosc" "%MPV_DL%\uosc\scripts\uosc"

    rem git clone --depth=1 https://github.com/po5/thumbfast
    mklink "%%d\scripts\thumbfast.lua" "%MPV_SRC%\thumbfast\thumbfast.lua"
    mklink "%%d\script-opts\thumbfast.conf" "%MPV_SRC%\thumbfast\thumbfast.conf"

    rem 1. Get HDR-Toys.zip from https://github.com/natural-harmonia-gropius/hdr-toys/releases.
    rem 2. Decompress to `hdr-toys/`.
    mklink /J "%%d\shaders\hdr-toys" "%MPV_SRC%\hdr-toys\shaders\hdr-toys"
    mklink "%%d\scripts\hdr-toys-helper.lua" "%MPV_DL%\hdr-toys\scripts\hdr-toys-helper.lua"
    type "%MPV_DL%\hdr-toys\hdr-toys.conf" >> "%%d\mpv.conf"

    rem git clone --depth=1 https://github.com/hhirtz/mpv-retro-shaders
    mklink /J "%%d\shaders\mpv-retro-shaders" "%MPV_SRC%\mpv-retro-shaders"
    type "%MPV_SRC%\mpv-retro-shaders\all.conf" >> "%%d\mpv.conf"

    echo File

    rem git clone --depth=1 https://github.com/cogentredtester/mpv-scripts mpv-scripts@cogentredtester
    mklink "%%d\scripts\editions-notification.lua" "%MPV_SRC%\mpv-scripts@cogentredtester\editions-notification.lua"

    rem git clone --depth=1 https://github.com/Hill-98/mpv-config mpv-config@Hill-98
    mklink "%%d\scripts\format-filename.js" "%MPV_SRC%\mpv-config@Hill-98\scripts\format-filename.js"

    rem git clone --depth=1 https://github.com/sibwaf/mpv-scripts mpv-scripts@sibwaf
    mklink "%%d\scripts\fuzzydir.lua" "%MPV_SRC%\mpv-scripts@sibwaf\fuzzydir.lua"
    mklink "%%d\scripts\reload.lua" "%MPV_SRC%\mpv-scripts@sibwaf\reload.lua"

    rem git clone --depth=1 https://github.com/Kayizoku/mpv-rename
    mklink "%%d\scripts\Rename.lua" "%MPV_SRC%\mpv-rename\Rename.lua"
    rem git clone --depth=1 https://github.com/CogentRedTester/mpv-user-input
    mklink "%%d\scripts\user-input.lua" "%MPV_SRC%\mpv-user-input\user-input.lua"
    mklink "%%d\script-modules\user-input-module.lua" "%MPV_SRC%\mpv-user-input\user-input-module.lua"

    echo Play

    rem Get auto-save-state.lua from https://github.com/AN3223/dotfiles/blob/master/.config/mpv/scripts/auto-save-state.lua.
    mklink "%%d\scripts\auto-save-state.lua" "%MPV_DL%\auto-save-state.lua"

    rem git clone --depth=1 https://github.com/po5/memo
    mklink "%%d\scripts\memo.lua" "%MPV_SRC%\memo\memo.lua"
    mklink "%%d\script-opts\memo.conf" "%MPV_CONF%\script-opts\memo.conf"

    rem git clone --depth=1 https://github.com/sibwaf/mpv-scripts mpv-scripts@sibwaf
    mklink "%%d\scripts\blackout.lua" "%MPV_CONF%\scripts\blackout.lua"

    rem git clone --depth=1 https://github.com/zc62/mpv-scripts mpv-scripts@zc62
    mklink "%%d\scripts\exit-fullscreen.lua" "%MPV_SRC%\mpv-scripts@zc62\exit-fullscreen.lua"

    rem git clone --depth=1 https://github.com/wishyu/mpv-ontop-window
    mklink "%%d\scripts\ontop-window.lua" "%MPV_SRC%\mpv-ontop-window\ontop-window.lua"

    rem git clone --depth=1 https://github.com/mpv-player/mpv
    mklink "%%d\scripts\ontop-playback.lua" "%MPV_SRC%\mpv\TOOLS\lua\ontop-playback.lua"

    echo Chapter

    rem git clone --depth=1 https://github.com/mar04/chapters_for_mpv
    mklink "%%d\scripts\chapters.lua" "%MPV_SRC%\chapters_for_mpv\chapters.lua"

    rem git clone --depth=1 https://github.com/dyphire/mpv-scripts mpv-scripts@dyphire
    mklink "%%d\scripts\chapter-make-read.lua" "%MPV_SRC%\mpv-scripts@dyphire\chapter-make-read.lua"

    echo Subtitle

    rem git clone --depth=1 https://github.com/joaquintorres/autosubsync-mpv
    mklink /J "%%d\scripts\autosubsync-mpv" "%MPV_SRC%\autosubsync-mpv"
    mklink "%%d\script-opts\autosubsync.conf" "%MPV_CONF%\script-opts\autosubsync.conf"

    rem git clone --depth=1 https://github.com/zenwarr/mpv-config mpv-config@zenwarr
    mklink "%%d\scripts\restore-subtitles.lua" "%MPV_SRC%\mpv-config@zenwarr\scripts\restore-subtitles.lua"

    rem git clone --depth=1 https://github.com/pzim-devdata/mpv-scripts mpv-scripts@pzim-devdata
    mklink "%%d\scripts\mpv-sub_not_forced_not_sdh.lua" "%MPV_SRC%\mpv-scripts@pzim-devdata\mpv-sub_not_forced_not_sdh.lua"

    rem git clone --depth=1 https://github.com/magnum357i/mpv-dualsubtitles
    mklink "%%d\scripts\dualsubtitles.lua" "%MPV_SRC%\mpv-dualsubtitles\dualsubtitles.lua"
    mklink "%%d\script-opts\dualsubtitles.conf" "%MPV_CONF%\script-opts\dualsubtitles.conf"

    rem git clone --depth=1 https://github.com/dyphire/mpv-scripts mpv-scripts@dyphire
    mklink "%%d\scripts\sub_export.lua" "%MPV_SRC%\mpv-scripts@dyphire\sub_export.lua"

    rem git clone --depth=1 https://github.com/directorscut82/find_subtitles
    mklink "%%d\scripts\find_subtitles.lua" "%MPV_CONF%\scripts\find_subtitles.lua"

    rem git clone --depth=1 https://github.com/genfu94/mpv-subtitle-retimer
    mklink /J "%%d\scripts\mpv-subtitle-retimer" "%MPV_SRC%\mpv-subtitle-retimer\src"

    rem git clone --depth=1 https://github.com/christoph-heinrich/mpv-subtitle-lines
    mklink "%%d\scripts\subtitle-lines.lua" "%MPV_SRC%\mpv-subtitle-lines\subtitle-lines.lua"

    rem git clone --depth=1 https://github.com/magnum357i/mpv-sidebarsubtitles
    mklink /J "%%d\scripts\sidebarsubtitles" "%MPV_SRC%\mpv-sidebarsubtitles\sidebarsubtitles"

    echo Stream

    rem git clone --depth=1 https://github.com/mpv-player/mpv
    mklink "%%d\scripts\autoload.lua" "%MPV_SRC%\mpv\TOOLS\lua\autoload.lua"
    mklink "%%d\script-opts\autoload.conf" "%MPV_CONF%\script-opts\autoload.conf"

    rem git clone --depth=1 https://github.com/mrxdst/webtorrent-mpv-hook
    mklink "%%d\scripts\webtorrent.js" "%MPV_SRC%\webtorrent-mpv-hook\build\webtorrent.js"
    mklink "%%d\script-opts\webtorrent.conf" "%MPV_CONF%\script-opts\webtorrent.conf"

    echo Other

    rem git clone --depth=1 https://github.com/CogentRedTester/mpv-scroll-list
    mklink "%%d\script-modules\scroll-list.lua" "%MPV_SRC%\mpv-scroll-list\scroll-list.lua"

    rem git clone --depth=1 https://github.com/shadax1/mpv_segment_length
    mklink "%%d\scripts\mpv_segment_length.lua" "%MPV_SRC%\mpv_segment_length\mpv_segment_length.lua"

    rem git clone --depth=1 https://github.com/cogentredtester/mpv-scripts mpv-scripts@cogentredtester
    mklink "%%d\scripts\show-errors.lua" "%MPV_SRC%\mpv-scripts@cogentredtester\show-errors.lua"
)

for %%d in (%MPVC_VIDEO%) do (
    rem git clone --depth=1 https://github.com/po5/celebi
    mklink "%%d\scripts\celebi.lua" "%MPV_SRC%\celebi\celebi.lua"
    mklink "%%d\script-opts\celebi.conf" "%MPV_CONF%\script-opts\celebi.conf"

    rem git clone --depth=1 https://github.com/ctlaltdefeat/mpv-open-imdb-page
    mklink /J "%%d\scripts\mpv-open-imdb-page" "%MPV_SRC%\mpv-open-imdb-page"
)

echo music config

for %%d in (%MPVC_MUSIC%) do (
    rem git clone --depth=1 https://github.com/thinkmcflythink/mpv-loudnorm
    mklink /J "%%d\scripts\real_loudnorm" "%MPV_SRC%\mpv-loudnorm"

    rem git clone --depth=1 https://github.com/cogentredtester/mpv-coverart
    mklink "%%d\scripts\coverart.lua" "%MPV_SRC%\mpv-coverart\coverart.lua"
    mklink "%%d\script-opts\coverart.conf" "%MPV_CONF%\script-opts\coverart.conf"

    rem git clone --depth=1 https://github.com/cogentredtester/mpv-scripts mpv-scripts@cogentredtester
    mklink "%%d\scripts\save-playlist.lua" "%MPV_SRC%\mpv-scripts@cogentredtester\save-playlist.lua"
)

set "CONFIG_DIR_MANGA=%MPVC_MANGA%"
for %%d in (%CONFIG_DIR_MANGA%) do (
    rem git clone --depth=1 https://github.com/occivink/mpv-gallery-view
    mklink "%%d\script-modules\gallery.lua" "%MPV_SRC%\mpv-gallery-view\script-modules\gallery.lua"
    mklink "%%d\scripts\gallery-thumbgen.lua" "%MPV_SRC%\mpv-gallery-view\scripts\gallery-thumbgen.lua"
    mklink "%%d\scripts\playlist-view.lua" "%MPV_SRC%\mpv-gallery-view\scripts\playlist-view.lua"
    mklink "%%d\script-opts\playlist_view.conf" "%MPV_CONF%\script-opts\playlist_view.conf"

    rem git clone --depth=1 https://github.com/guidocella/mpv-image-config
    mklink "%%d\scripts\image-bindings.lua" "%MPV_SRC%\mpv-image-config\scripts\image-bindings.lua"
    mklink "%%d\script-opts\image_bindings.conf" "%MPV_CONF%\script-opts\image_bindings.conf"
    type "%MPV_SRC%\mpv-image-config\mpv.conf" >> "%%d\mpv.conf"
    type "%MPV_SRC%\mpv-image-config\input.conf" >> "%%d\input.conf"

    rem git clone --depth=1 https://github.com/occivink/mpv-image-viewer
    mklink "%%d\scripts\freeze-window.lua" "%MPV_SRC%\mpv-image-viewer\scripts\freeze-window.lua"
    mklink "%%d\scripts\image-positioning.lua" "%MPV_SRC%\mpv-image-viewer\scripts\image-positioning.lua"
    mklink "%%d\scripts\minimap.lua" "%MPV_SRC%\mpv-image-viewer\scripts\minimap.lua"
    mklink "%%d\scripts\status-line.lua" "%MPV_SRC%\mpv-image-viewer\scripts\status-line.lua"
    mklink "%%d\scripts\detect-image.lua" "%MPV_SRC%\mpv-image-viewer\scripts\detect-image.lua"
    mklink "%%d\script-opts\image_positioning.conf" "%MPV_CONF%\script-opts\image_positioning.conf"
    mklink "%%d\script-opts\minimap.conf" "%MPV_CONF%\script-opts\minimap.conf"
    mklink "%%d\script-opts\status_line.conf" "%MPV_CONF%\script-opts\status_line.conf"
    mklink "%%d\script-opts\detect_image.conf" "%MPV_CONF%\script-opts\detect_image.conf"

    rem git clone --depth=1 https://github.com/dudemanguy/mpv-manga-reader
    mklink "%%d\scripts\manga-reader.lua" "%MPV_SRC%\mpv-manga-reader\manga-reader.lua"

    rem git clone --depth=1 https://github.com/jonniek/mpv-nextfile
    mklink "%%d\scripts\nextfile.lua" "%MPV_SRC%\mpv-nextfile\nextfile.lua"
)

rmdir /S /Q %MPV_DATA%
rem mkdir %MPV_DATA%
rem fastcopy /open_window /auto_close "%MPVC_VIDEO%" /to="%MPV_DATA%"
mklink /J "%MPV_DATA%" "%MPVC_VIDEO%"

endlocal

pause