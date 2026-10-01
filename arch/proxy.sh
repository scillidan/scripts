#!/usr/bin/env sh
# Minimal local http/https proxy switcher.

set -e
set -u

PROXY_HOST="${PROXY_HOST:-127.0.0.1}"
PROXY_PORT="${PROXY_PORT:-7890}"

case "${1:-help}" in
on)
	port="${2:-$PROXY_PORT}"
	url="http://${PROXY_HOST}:${port}"
	export http_proxy="$url" https_proxy="$url" HTTP_PROXY="$url" HTTPS_PROXY="$url"
	echo "proxy: on ($url)"
	;;
off)
	unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY
	echo "proxy: off"
	;;
status)
	echo "http_proxy  = ${http_proxy:-<unset>}"
	echo "https_proxy = ${https_proxy:-<unset>}"
	echo "HTTP_PROXY  = ${HTTP_PROXY:-<unset>}"
	echo "HTTPS_PROXY = ${HTTPS_PROXY:-<unset>}"
	exit 0
	;;
help | --help | -h | *)
	cat <<'EOF'
Usage:
  source proxy.sh on [port]   enable proxy in current shell (default 7890)
  source proxy.sh off         disable proxy in current shell
  proxy.sh status             show proxy env vars

Environment:
  PROXY_HOST   default 127.0.0.1
  PROXY_PORT   default 7890
EOF
	exit 0
	;;
esac
