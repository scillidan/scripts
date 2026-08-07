#!/bin/bash
set -e

ugrep -iRQ --fuzzy=best --split \
    "$USERHOME/Share/projs-site/BYYA-site/content.zh/docs"/{jaffa,laguna,lyra-{a,b},nineveh,orion-a,sheet} \
    "$@"