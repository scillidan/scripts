@echo off

alacritty --config-file "%USERHOME%\Share\dotfiles.win\.config\alacritty\alacritty.toml"  --working-directory "%USERHOME%" --command %*