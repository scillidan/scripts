#!/bin/bash

export XDG_CONFIG_HOME="$USERHOME/Local/Data"
export XDG_DATA_HOME="$USERHOME/Local/Data"

neovide --size=1250x720 --frame none --no-tabs --neovim-bin nvim $@