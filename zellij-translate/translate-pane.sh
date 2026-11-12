#!/bin/bash
# Spawn a neighbouring pane that translates the pane you are looking at.
#
#   translate-pane.sh [right|down]   default: right
#
# Bound in config.kdl as `Alt-t`. It launches a short runner through Zellij's
# `Run`; the runner replaces itself with the translation pane, so the screen ends
# up with two panes: the source on the left and the translation on the right.

set -euo pipefail

direction="${1:-right}"
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

exec zellij action new-pane --in-place --close-replaced-pane --direction "${direction}" \
	-- bash "${here}/translate-now.sh"
