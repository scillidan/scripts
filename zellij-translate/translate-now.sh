#!/bin/bash
# Translate the pane you came from, keeping its layout, then wait for Enter.
#
#   translate-now.sh <source-pane-id>
#
# The source id is mandatory: focus is on this pane once it opens, so a plain
# dump-screen would read itself.
#
# Format is preserved on purpose: dump-screen gives plain text with the original
# line breaks and column layout (no colours), and that text is handed to the LLM
# untouched apart from trailing whitespace. The result is printed as-is so the
# two panes line up.

set -euo pipefail

pane_id="${1:-}"
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

fail() {
	echo "translate-pane: $*" >&2
	read -r -p "--- enter to close ---" _ || true
	exit 1
}

[ -n "${pane_id}" ] || fail "source pane id missing (got none)"

tmp="${TMPDIR:-/tmp}"
dump="${tmp}/zellij-translate-dump.txt"

# Viewport only: no --full, so the scrollback is not pulled in.
zellij action dump-screen --pane-id "${pane_id}" --path "${dump}" || fail "dump-screen --pane-id ${pane_id} failed"

if ! grep -q '[^[:space:]]' "${dump}" 2>/dev/null; then
	fail "pane ${pane_id} is empty (dump kept at ${dump})"
fi

sed -e 's/\r$//' -e 's/[[:space:]]*$//' "${dump}" >"${dump}.txt"

if ! bash "${here}/../llm-translate.sh" --stdin <"${dump}.txt"; then
	echo
	echo "translate-pane: llm-translate failed (is 127.0.0.1:8010 serving?)" >&2
fi

echo
read -r -p "--- enter to close ---" _ || true
