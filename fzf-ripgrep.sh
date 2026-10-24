#!/bin/bash
# Interactive grep launcher: fzf + ripgrep (+ bat preview).
# Port of win/fzf-ripgrep.cmd; runs on Linux and on Windows via git bash.
# Dependences: rg, fzf, bat.  Optional: subl, nvim.
# Extra rg filters via env, e.g.  FZF_RG_EXTRA="-g *.py -g !**/dist/**" fzf-ripgrep.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/fzf_bind.sh"

TQDIR="${TMPDIR:-/tmp}/fzf-ripgrep"

# --tq MODE QUERY: transform-query helper for rg<->fzf mode switching.
# Saves the current mode's query, prints the other mode's last query.
tq() {
	local new="$1" q="${2:-}" old=f
	[[ "$new" == "f" ]] && old=r
	mkdir -p "$TQDIR"
	# shortcut: strips exactly one outer single-quote pair (fzf's {q} quoting);
	# a query with interior quotes keeps them.
	if [[ ${#q} -ge 2 && "${q:0:1}" == "'" && "${q: -1}" == "'" ]]; then
		q="${q:1:${#q}-2}"
	fi
	printf '%s\n' "$q" > "$TQDIR/$old.tmp"
	if [[ -f "$TQDIR/$new.tmp" ]]; then
		head -n1 "$TQDIR/$new.tmp"
	fi
}

if [[ "${1:-}" == "--tq" ]]; then
	tq "${2:-f}" "${3:-}"
	exit 0
fi

# -- rg flags (2>&1 surfaces option errors inside fzf).
RG="rg --hidden --follow --glob !.git --column --line-number --no-heading --color=always --smart-case 2>&1"
[[ -n "${FZF_RG_EXTRA:-}" ]] && RG="$RG $FZF_RG_EXTRA"

# -- Reload guard: "echo {q} |" is exactly 2 chars when empty; grep '..' needs 3+.
RELOAD="echo {q} | grep -q .. && $RG {q} || true"

# -- fzf on top, preview at the bottom, filling the whole terminal.
FLAG="--ansi --disabled --delimiter : --height 100% --layout=reverse --border none --preview-border none --no-scrollbar --no-separator --inline-info"
PREVIEW="--preview 'bat --force-colorization --style=numbers --highlight-line {2} {1}'"
PREVIEW_WINDOW="--preview-window 'down,60%,border-top,+{2}+3/3,~2'"

# -- Mode switching (CTRL-F = fzf filter, CTRL-R = ripgrep); --tq remembers
#    each mode's query.  fzf mode starts with an empty query.
BIND_MODE="--bind 'start:reload($RELOAD)+unbind(ctrl-r)' --bind 'change:reload($RELOAD)'"
BIND_MODE="$BIND_MODE --bind 'ctrl-f:unbind(change,ctrl-f)+change-prompt(fzf> )+enable-search+rebind(ctrl-r)+transform-query(bash $SCRIPT_DIR/fzf-ripgrep.sh --tq f {q})'"
BIND_MODE="$BIND_MODE --bind 'ctrl-r:unbind(ctrl-r)+change-prompt(rg> )+disable-search+rebind(change,ctrl-f)+transform-query(bash $SCRIPT_DIR/fzf-ripgrep.sh --tq r {q})+reload($RELOAD)'"
BIND_ENTER="--bind 'enter:execute(subl -a {1}:{2})' --bind 'alt-enter:execute(subl -a {1}:{2})+abort'"
BIND_NAV="--bind 'ctrl-o:execute(nvim +{2} {1})+abort,ctrl-k:preview-up,ctrl-j:preview-down,ctrl-h:preview-page-up,ctrl-l:preview-page-down'"
BIND_TOGGLE="--bind 'ctrl-\\:change-preview-window(right,60%,wrap,+{2}+3/3,~2|down,60%,border-top,+{2}+3/3,~2)'"

FZF_CMD="fzf $FLAG --prompt 'rg> ' --query '$*' $PREVIEW $PREVIEW_WINDOW $BIND_MODE $BIND_ENTER $BIND_NVIM $BIND_SUBL $BIND_NAV $BIND_TOGGLE"

rm -rf "$TQDIR"
eval "$FZF_CMD"
