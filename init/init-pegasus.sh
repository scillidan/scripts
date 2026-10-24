#!/bin/sh
# Personal setup script

case "$(uname -s)" in
MINGW* | MSYS*)
	# Windows (git bash). Native symlinks need Developer Mode or admin.
	export MSYS=winsymlinks:nativestrict
	WINDOWS=1
	PEGASUS_HOME="$SCOOP/apps/pegasus/current"
	RETROARCH_HOME="$SCOOP/apps/retroarch/current"
	PEGASUS_CONF="$USERHOME/Local/File/file_pegasus-frontend"
	PEGASUS_SRC="$USERHOME/Local/Source/pegasus"
	PEGASUS_DL="$USERHOME/Local/Download/pegasus"
	;;
*)
	PEGASUS_HOME="$USERHOME/<path_to>/pegasus"
	RETROARCH_HOME="$USERHOME/<path_to>/retroarch"
	PEGASUS_CONF="$USERHOME/Usr/File/file_pegasus-frontend"
	PEGASUS_SRC="$USERHOME/Usr/Source/pegasus"
	PEGASUS_DL="$USERHOME/Usr/Download/pegasus"
	;;
esac

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

link_dir() {
	if [ -n "$WINDOWS" ]; then
		MSYS_NO_PATHCONV=1 cmd /c mklink /J "$(cygpath -w "$2")" "$(cygpath -w "$1")"
	else
		ln -s "$1" "$2"
	fi
}

link_file() {
	if [ -n "$WINDOWS" ]; then
		MSYS_NO_PATHCONV=1 cmd /c mklink "$(cygpath -w "$2")" "$(cygpath -w "$1")"
	else
		ln -s "$1" "$2"
	fi
}

# RetroArch
rm_tree "$PEGASUS_HOME/RetroArch"
link_dir "$RETROARCH_HOME" "$PEGASUS_HOME/RetroArch"
for s in cheats config cores downloads system; do
	rm_tree "$PEGASUS_HOME/RetroArch/$s"
	link_dir "$PEGASUS_DL/pegasus-g/RetroArch/$s" "$PEGASUS_HOME/RetroArch/$s"
done

# Config
rm_tree "$PEGASUS_HOME/config"
mkdir -p "$PEGASUS_HOME/config/themes"
link_file "$PEGASUS_CONF/config/game_dirs.txt" "$PEGASUS_HOME/config/game_dirs.txt"
link_file "$PEGASUS_CONF/config/settings.txt" "$PEGASUS_HOME/config/settings.txt"
for i in "$PEGASUS_SRC/"*; do
	if [ -d "$i" ]; then
		link_dir "$i" "$PEGASUS_HOME/config/themes/$(basename "$i")"
	fi
done

# Roms
rm_tree "$PEGASUS_HOME/Roms"
link_dir "$PEGASUS_DL/pegasus-g/Roms" "$PEGASUS_HOME/Roms"
for d in "$PEGASUS_HOME/Roms/"*; do
	if [ -d "$d" ]; then
		rm -f "$d/metadata.pegasus.txt"
		metadata_file="$PEGASUS_CONF/metadata/$(basename "$d")/metadata.pegasus.txt"
		if [ -e "$metadata_file" ]; then
			link_file "$metadata_file" "$d/metadata.pegasus.txt"
		fi
	fi
done
