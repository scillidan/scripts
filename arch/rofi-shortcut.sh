#!/bin/bash

# Refer to https://github.com/Zeioth/rofi-shortcuts

cat ~/Local/File/file_cheatsheets/{shortcut,shortcut_arch,shortcut_dev}/*.conf | sort -u | rofi -i -dmenu -p 'shortcut'