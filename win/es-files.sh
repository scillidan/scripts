#!/bin/bash
# Everything-GUI-style file finder: live es.exe (Everything CLI) search in fzf.
# Auto-starts Everything minimized if not running, so the GUI never needs to open.
# Honors Everything's own config: index exclusions (folders/filters) are applied
# at index time; hidden/system exclusion is applied at search time (see ES_GUI_FILTER).
# Dependences: es.exe, everything.exe, fzf, fzf_bind.sh, fzf_preview.sh, fzf_open.sh

set -euo pipefail

THIS_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_DIR="$(cd "$THIS_SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/fzf_bind.sh"

MAX_RESULTS=5000
IPC_WAIT_SECONDS=60

win2posix() {
	sed -E 's#^([A-Za-z]):#/\L\1\E#; s#\\#/#g'
}

# Everything GUI config: Index -> Exclude hidden/system files and folders (On).
# Applied at search time so results match the GUI even if the index includes them.
ES_GUI_FILTER=("!attrib:h" "!attrib:s")

# --list mode: print matches (called by fzf reload on every keystroke)
if [[ "${1:-}" == "--list" ]]; then
	shift
	[[ $# -eq 0 ]] && exit 0
	args=()
	[[ -n "${ES_PATH:-}" ]] && args+=(-path "$ES_PATH")
	es.exe -n "$MAX_RESULTS" "${args[@]}" "$@" "${ES_GUI_FILTER[@]}" 2>/dev/null | win2posix || true
	exit 0
fi

FLAG="--multi --layout=reverse --border none --preview-border none --no-scrollbar --no-separator --inline-info --ansi"
BIND_NAVIGATE="--bind 'alt-p:preview-page-up,alt-n:preview-page-down'"
BIND_SELECT="--bind 'tab:select+down,btab:deselect+down,ctrl-a:select-all,ctrl-d:deselect-all'"
BIND_ENTER="--bind 'enter:execute(bash \"${SCRIPT_DIR}/fzf_open.sh\" {+})+abort'"
BIND_RELOAD="--bind 'change:reload(bash \"${THIS_SCRIPT_DIR}/es-files.sh\" --list {q})'"
BIND_TOGGLE_PREVIEW="--bind 'ctrl-\\:change-preview-window(up,60%,border-bottom,+{2}+3/3,~2|right,60%,wrap,~2)'"
PREVIEW="--preview 'bash ${SCRIPT_DIR}/fzf_preview.sh {}'"
PREVIEW_WINDOW="--preview-window 'right,60%,wrap,~2'"

# Start Everything hidden (no GUI window) if its IPC is not answering.
ensure_everything() {
	if es.exe -timeout 500 -get-everything-version >/dev/null 2>&1; then
		return 0
	fi
	# shortcut: assume scoop install, no PATH probing (keeps startup fast)
	local ev="${SCOOP:-$HOME/scoop}"
	ev="${ev//\\//}/apps/everything/current/Everything.exe"
	if [[ ! -f "$ev" ]]; then
		echo "Error: everything.exe not found: $ev (set SCOOP if your scoop root differs)" >&2
		return 1
	fi
	"$ev" -minimized >/dev/null 2>&1 &
	local i
	for ((i = 0; i < IPC_WAIT_SECONDS; i++)); do
		if es.exe -timeout 1000 -get-everything-version >/dev/null 2>&1; then
			return 0
		fi
		sleep 1
	done
	echo "Error: Everything did not respond within ${IPC_WAIT_SECONDS}s" >&2
	return 1
}

expand_path() {
	local path="$1"
	path="${path/#~/${HOME}}"
	path=$(eval echo "$path")
	path="${path//\\//}"
	echo "$path"
}

get_target_dir() {
	local raw_dir="${1:-}"
	if [[ -z "$raw_dir" ]]; then
		return 0
	fi
	local dir
	dir=$(expand_path "$raw_dir")
	if [[ -d "$dir" ]]; then
		echo "$dir"
	else
		echo "Error: Directory does not exist: $dir" >&2
		return 1
	fi
}

show_usage() {
	echo "Usage: es-files.sh [<directory>]"
	echo ""
	echo "Arguments:"
	echo "  <dir>    Restrict search to directory (default: entire Everything index)"
	echo ""
	echo "Everything is auto-started minimized if not running — no GUI needed."
	echo ""
	echo "Key Bindings:"
	echo "  Enter        Open selected (dirs: Double Commander; multiple: copy paths to clipboard)"
	echo "  Ctrl-T       Open in Double Commander"
	echo "  Ctrl-E       Open in Sublime Text"
	echo "  Ctrl-O       Open in Neovim"
	echo "  Tab/Shift-Tab    Select/deselect"
	echo "  Ctrl-A/D     Select all / deselect all"
	echo "  Alt-P/N      Preview page up/down"
	echo "  Ctrl-\       Toggle preview position"
}

main() {
	if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
		show_usage
		exit 0
	fi

	local target_dir
	target_dir=$(get_target_dir "${1:-}") || exit 1
	ensure_everything
	if [[ -n "$target_dir" ]]; then
		export ES_PATH="$(cygpath -w "$target_dir" 2>/dev/null || echo "$target_dir")"
	fi

	# Empty query: recently modified files, like a fresh Everything window
	local initial
	if [[ -n "${ES_PATH:-}" ]]; then
		initial="$(es.exe -n 300 -sort date-modified-descending -path "$ES_PATH" "${ES_GUI_FILTER[@]}" 2>/dev/null | win2posix || true)"
	else
		initial="$(es.exe -n 300 -sort date-modified-descending "${ES_GUI_FILTER[@]}" 2>/dev/null | win2posix || true)"
	fi

	FZF_CMD="fzf $FLAG $BIND_NAVIGATE $BIND_SELECT $BIND_ENTER $BIND_NVIM $BIND_SUBL $BIND_DCMD $BIND_RELOAD $BIND_TOGGLE_PREVIEW $PREVIEW $PREVIEW_WINDOW"
	if [[ -n "$initial" ]]; then
		printf '%s\n' "$initial" | eval "$FZF_CMD"
	else
		eval "$FZF_CMD < /dev/null"
	fi
}

main "$@"
