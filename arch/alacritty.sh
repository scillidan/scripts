#!/usr/bin/env bash
set -euo pipefail

CONFIG="$USERHOME/Share/dotfiles/.config/alacritty/alacritty.toml"

exec alacritty-theme \
	--config-file "$CONFIG" \
	--working-directory "$USERHOME/Downloads" \
	"$@" \
	--command "${SHELL:-/bin/bash}" -l
