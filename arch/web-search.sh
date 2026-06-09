#!/usr/bin/env bash
# https://github.com/miroslavvidovic/rofi-scripts/blob/master/web-search.sh
# -----------------------------------------------------------------------------
# Info:
#   author:    Miroslav Vidovic
#   file:      web-search.sh
#   created:   24.02.2017.-08:59:54
#   revision:  ---
#   version:   1.0
# -----------------------------------------------------------------------------
# Requirements:
#   rofi
# Description:
#   Use rofi to search the web.
# Usage:
#   web-search.sh
# -----------------------------------------------------------------------------
# Script:

declare -A URLS

URLS=(
	# Book
	["annas-archive.org"]="https://annas-archive.org/search?index=&page=1&sort=&display=&q="
	["douban.com"]="https://www.douban.com/search?q="
	["worldcat.org"]="https://search.worldcat.org/search?offset=1&q="
	# Dictionary
	["allacronyms.com"]="https://www.allacronyms.com/aa-searchme?q="
	["bosworthtoller.com"]="https://bosworthtoller.com/search?q="
	["emojikeyboard.io"]="https://emojikeyboard.io/search?query="
	["etymonline.com"]="https://www.etymonline.com/search?q="
	["skell.sketchengine.eu"]="https://skell.sketchengine.eu/#result?lang=en&f=concordance&query="
	["wordnik.com"]="https://www.wordnik.com/words/"
	# Document
	["aur.archlinux.org"]="https://aur.archlinux.org/packages?O=0&K="
	["cheatsheets.zip"]="https://cheatsheets.zip/?q="
	["devdocs.io"]="https://devdocs.io/#q="
	["mankier.com"]="https://www.mankier.com/1/"
	["typst-examples-book"]="https://sitandr.github.io/typst-examples-book/book/basics/index.html?search="
	["zealusercontributions"]="https://zealusercontributions.vercel.app/search?q="
	# Opt
	["alternativeto.net"]="https://alternativeto.net/browse/search/?q="
	["apkpure.com"]="https://apkpure.com/search?q="
	["fdroid.org"]="https://search.f-droid.org/?q="
	["filehippo.com"]="https://filehippo.com/search/?q="
	["flathub.org"]="https://flathub.org/apps/search?q="
	["portableapps.com"]="https://portableapps.com/search/node/"
	# Opt-Ext
	["ankiweb.net"]="https://ankiweb.net/shared/addons?search="
	["automa.site"]="https://www.automa.site/marketplace?search="
	["skills.sh"]="https://www.skills.sh/?q="
	["skillsmp.com"]="https://skillsmp.com/search?q="
	["ollama.com"]="https://ollama.com/library?q="
	["open-vsx.org"]="https://open-vsx.org/?sortBy=relevance&sortOrder=desc&search="
	["marketplace.visualstudio.com"]="https://marketplace.visualstudio.com/search?target=VSCode&category=All%20categories&sortBy=Relevance&term="
	["mcpmarket.com"]="https://mcpmarket.com/search?q="
	["mcpservers.org"]="https://mcpservers.org/https://mcpservers.org/search?query="
	# Video
	["animegarden"]="https://animes.garden/resources/1?search="
	["nyaa.si"]="https://nyaa.si/?f=0&c=3_0&q="
	["imdb.com"]="https://www.imdb.com/find?q="
	["jackett"]="http://localhost:9117/UI/Dashboard#filter=all&search="
	["bilibili.com"]="https://search.bilibili.com/all?keyword="
	["youtube.com"]="https://www.youtube.com/results?search_query="
	# Lib
	["ctan.org"]="https://www.ctan.org/search?phrase="
	["javascripting.com"]="https://www.javascripting.com/search?q="
	["jsdelivr.com"]="https://www.jsdelivr.com/?query="
	["typst.app"]="https://typst.app/universe/search/?q="
	# Search
	["google.com"]="https://www.google.com/search?q="
	["scira.ai"]="https://scira.ai/?query="
	["perplexity.ai"]="https://www.perplexity.ai/?q="
	# Subtitle
	["opensubtitles.org"]="https://www.opensubtitles.org/en/search2/sublanguageid-chi,eng/moviename-"
	["subhd.tv"]="https://subhd.tv/search/"
	["subtitlecat.com"]="https://www.subtitlecat.com/index.php?search="
	# Web
	["github"]="https://github.com/search?type=repositories&q="
	["github_action"]="https://github.com/marketplace?type=actions&query="
	["github_user"]="https://github.com/scillidan?tab=repositories&q="
	["gist"]="https://gist.github.com/search?ref=searchresults&q="
	# ["gist_user"]="https://gist.github.com/search?ref=searchresults&q=user%3Ascillidan+&"
	["hn.algolia.com"]="https://hn.algolia.com/?dateRange=all&page=0&prefix=false&sort=byPopularity&type=story&query="
	["hub.docker.com"]="https://hub.docker.com/search?q="
	["lib.rs"]="https://lib.rs/search?q="
	# Tool
	["dmns.app"]="https://dmns.app/domains?q="
	["ipaddress.com"]="https://www.ipaddress.com/website/"
	["virustotal.com"]="https://www.virustotal.com/gui/seach/"
	# Other
	["flickr.com"]="https://www.flickr.com/search/?license=2%2C3%2C4%2C5%2C6%2C9&text="
	["genius.com"]="https://genius.com/search?q="
	["ScoopInstaller/Extras/pulls"]="https://github.com/ScoopInstaller/Extras/pulls?q="
	# Cache
	#" [site/yomitan"]="= chrome-extension://likgccmbimhjbgkjambclfkhldnlhbnn/search.html?query="
	#" [site/linkding"]="= http://127.0.0.1:8060/bookmarks?q="
	#" [site/msys2.org"]="= https://packages.msys2.org/search?q="
)

# List for rofi
gen_list() {
	for i in "${!URLS[@]}"; do
		echo "$i"
	done
}

main() {
	# Pass the list to rofi
	platform=$( (gen_list) | rofi -dmenu -matching fuzzy -no-custom -location 0 -p "Search > ")

	if [[ -n "$platform" ]]; then
		query=$( (echo) | rofi -dmenu -matching fuzzy -location 0 -p "Query > ")

		if [[ -n "$query" ]]; then
			url=${URLS[$platform]}$query
			xdg-open "$url"
		else
			exit
		fi

	else
		exit
	fi
}

main

exit 0
