#!/usr/bin/env bash
# https://dev.to/helderberto/integrating-tldr-with-fzf-2377

tldr --list \
  | fzf \
      --border=none \
      --preview-border=none \
      --no-scrollbar \
      --layout=reverse \
      --preview 'tldr --color always {}' \
      --preview-window=right,80%,~2 \
  | xargs -r tldr