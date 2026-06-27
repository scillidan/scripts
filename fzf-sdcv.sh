#!/bin/bash
# https://github.com/Dushistov/sdcv#integration-with-fzf

fzf --prompt="Dict: " \
    --phony \
    --bind "enter:reload(sdcv {q} -n --json | jq '.[].dict' -r)" \
    --preview "sdcv {q} -en --use-dict={}" \
    --preview-window=right:70%:wrap