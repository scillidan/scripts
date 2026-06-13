#!/bin/bash
# Personal setup script

PEGASUS_HOME="$HOME/<path_to>/pegasus"
RETROARCH_HOME="$HOME/<path_to>/retroarch"
PEGASUS_CONF="$HOME/Usr/File/file_pegasus-frontend"
PEGASUS_SRC="$HOME/Usr/Source/pegasus"
PEGASUS_DL="$HOME/Usr/Download/pegasus"

rm -rf "$PEGASUS_HOME/RetroArch"
ln -s "$RETROARCH_HOME" "$PEGASUS_HOME/RetroArch"
rm -rf "$PEGASUS_HOME/RetroArch"/{cheats,config,cores,downloads,system}
ln -s "$PEGASUS_DL/pegasus-g/RetroArch/cheats" "$PEGASUS_HOME/RetroArch/cheats"
ln -s "$PEGASUS_DL/pegasus-g/RetroArch/config" "$PEGASUS_HOME/RetroArch/config"
ln -s "$PEGASUS_DL/pegasus-g/RetroArch/cores" "$PEGASUS_HOME/RetroArch/cores"
ln -s "$PEGASUS_DL/pegasus-g/RetroArch/downloads" "$PEGASUS_HOME/RetroArch/downloads"
ln -s "$PEGASUS_DL/pegasus-g/RetroArch/system" "$PEGASUS_HOME/RetroArch/system"

rm -rf "$PEGASUS_HOME/config"
mkdir "$PEGASUS_HOME/config"
ln -s "$PEGASUS_CONF/config/game_dirs.txt" "$PEGASUS_HOME/config/game_dirs.txt"
ln -s "$PEGASUS_CONF/config/settings.txt" "$PEGASUS_HOME/config/settings.txt"

mkdir "$PEGASUS_HOME/config/themes"
for i in "$PEGASUS_SRC/"*; do
    if [ -d "$i" ]; then
        ln -s "$i" "$PEGASUS_HOME/config/themes/$(basename "$i")"
    fi
done

rm -rf "$PEGASUS_HOME/Roms"
ln -s "$PEGASUS_DL/pegasus-g/Roms" "$PEGASUS_HOME/Roms"
find "$PEGASUS_HOME/Roms/" -name "metadata.pegasus.txt" -delete
for d in "$PEGASUS_HOME/Roms/"*; do
    if [ -d "$d" ]; then
        metadata_file="$PEGASUS_CONF/metadata/$(basename "$d")/metadata.pegasus.txt"
        if [ -e "$metadata_file" ]; then
            ln -s "$metadata_file" "$d/metadata.pegasus.txt"
        fi
    fi
done

read -p "Press [Enter] key to continue..."