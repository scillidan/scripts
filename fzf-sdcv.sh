#!/bin/bash
# Base on https://github.com/Dushistov/sdcv#integration-with-fzf

# sdcv.exe on Windows outputs GBK in -n mode, needs conversion
if [[ "$(uname -s)" == MINGW* ]] || [[ "$(uname -s)" == MSYS* ]]; then
    SDCV_PREVIEW='sdcv {q} -n --use-dict={} | iconv -f gbk -t utf-8'
else
    SDCV_PREVIEW='sdcv {q} -n --use-dict={}'
fi

echo "start typing to search" | fzf \
    --border=none \
    --preview-border=none \
    --no-scrollbar \
    --layout=reverse \
    --disabled \
    --bind "change:reload:sdcv {q} -n --json | jq [.[].dict] -r | jq unique[] -r" \
    --preview "$SDCV_PREVIEW | sed 1,4d" \
    --preview-window=down:90%:wrap,~2
