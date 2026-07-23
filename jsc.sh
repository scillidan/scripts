#!/usr/bin/env bash
# https://github.com/rodrigo-sys/jsc
# Cross-platform: works on Linux/macOS and Git Bash on Windows.
# column is used for table alignment when available (common in Git Bash).
# numfmt is optional; awk is used as a fallback for human-readable sizes.

api_key='YOUR_API_KEY_HERE'
export FZF_DEFAULT_OPTS="--header-lines 1 --reverse --nth 4.. --with-nth=2.. --multi -i"

while getopts "s:t:nc:" o; do case "${o}" in
	s) search_term=${OPTARG};;
	t) tracker=${OPTARG};;
	n) nointeractive='1';;
	c) columns=${OPTARG};;
	*) printf "Invalid option: -%s\\n" "$OPTARG" && exit 1 ;;
esac done

[ $OPTIND -eq 1 ] && search_term="$*"
[ -z "$columns" ] && columns='[if .MagnetUri == null then .Link else .MagnetUri end, .Seeders, .Size, .TrackerId, .Title]'

url="http://127.0.0.1:9117/api/v2.0/indexers/all/results?apikey=$api_key"
# tracker="$tracker"'1337x,rarbg'
[ -n "$tracker" ] && url="$url""&Tracker%5B%5D=$tracker"

raw_torrents_data=$(curl -s -G --data-urlencode "Query=$search_term" "$url")
torrents_data="$(echo "$raw_torrents_data" | jq '.Results | sort_by(.Seeders) | reverse')"

# Print a Windows-style path when running under Git Bash/MSYS2/Cygwin,
# otherwise keep the Unix path. This makes .torrent file output usable
# with native Windows clients.
normalize_path() {
  if command -v cygpath >/dev/null 2>&1; then
    cygpath -w "$1"
  else
    printf '%s\n' "$1"
  fi
}

# Use numfmt for size formatting when available; otherwise fall back to awk.
human_size() {
  if command -v numfmt >/dev/null 2>&1; then
    numfmt --to=iec --field 3 -d$'\t'
  else
    awk -F'\t' 'BEGIN { OFS="\t"; split("B KB MB GB TB PB", units) }
    {
      size = $3 + 0
      u = 1
      while (size >= 1024 && u < 6) { size /= 1024; u++ }
      if (u == 1) $3 = size " B"
      else $3 = sprintf("%.2f %s", size, units[u])
      print
    }'
  fi
}

torrents_table=$(
  echo "$torrents_data" |
  jq -r '.[] | '"$columns"' | @tsv' |
  human_size |
  column --table-columns "MOL,Seeder,Size,Tracker,Title" --table --separator $'\t'
)

[ "$nointeractive" = 1 ] && { echo "$torrents_table" ; exit ; }

selected_torrents="$(echo "$torrents_table" | fzf)"

echo "$selected_torrents" | awk '{print $1}' |
while read -r magnet_or_link; do
  if echo "$magnet_or_link" | grep -q '^magnet:'; then
    echo "$magnet_or_link"
  else
    magnet="$(wget -O /dev/null "$magnet_or_link" --server-response 2>&1 | grep 'Location:' -m 1 | sed 's|\s\sLocation:\s||')"
    if [ -n "$magnet" ]; then
      echo "$magnet"
    else
      torrent_file=$(mktemp /tmp/jsc_XXXXXX.torrent)
      wget -O "$torrent_file" "$magnet_or_link" 2>/dev/null
      normalize_path "$torrent_file"
    fi
  fi
done
