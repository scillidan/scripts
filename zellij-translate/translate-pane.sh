#!/bin/bash
# Open a new Zellij tab that translates the pane you are looking at.
#
#   translate-pane.sh
#
# Bound to Alt-t. The pane id is hard-wired to terminal_1: inside the freshly
# created tab, the source is pane 1 and Zellij's 1-row tab bar pane (bars
# plugin) is pane 2, so `dump-screen --pane-id terminal_1` reads the source from
# whichever pane runs this.
#
# Layout: the new tab has one full-height shell; the translation is spawned below
# it, so the source stays on top and the translation fills the bottom half.

set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
layout="${USERHOME:-$HOME}/Share/dotfiles/.config/zellij/config/layouts/translate.kdl"

zellij action new-tab --layout "${layout}"
zellij action new-pane --direction down -- bash "${here}/translate-now.sh" terminal_1
