#!/usr/bin/env bash

expand_path() {
	local p="$1"
	p="${p/#~/${HOME}}"
	p=$(eval echo "$p")
	echo "${p//\\//}"
}
ugrep -iRQ --fuzzy=best --split "$(expand_path "$1")"