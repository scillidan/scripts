#!/usr/bin/env python3
"""Attach to a Zellij session, creating it from a layout if it does not exist.

Usage:
    zellij-session                 # session "session", layout "user" (tmuxp replacement)
    zellij-session <name>          # named session, layout "project"
    zellij-session <dir>           # session named after the directory, cwd = <dir>
    zellij-session <name> <layout> # explicit layout
"""

import os
import re
import subprocess
import sys

ZELLIJ = os.environ.get("ZELLIJ_BIN", "zellij")


def session_names():
    try:
        out = subprocess.run(
            [ZELLIJ, "list-sessions", "--short", "--no-formatting"],
            capture_output=True,
            text=True,
            timeout=5,
        )
    except (OSError, subprocess.SubprocessError):
        return set()
    return {line.strip() for line in out.stdout.splitlines() if line.strip()}


def main():
    target = sys.argv[1] if len(sys.argv) > 1 else "session"
    layout = sys.argv[2] if len(sys.argv) > 2 else None

    path = os.path.expanduser(target)
    if os.path.isdir(path):
        os.chdir(path)
        name = os.path.basename(os.path.abspath(path))
    else:
        name = target

    name = re.sub(r"[^A-Za-z0-9_-]+", "-", name).strip("-") or "session"
    if layout is None:
        layout = "user" if name == "session" else "project"

    if name in session_names():
        args = [ZELLIJ, "attach", name]
    else:
        args = [ZELLIJ, "--session", name, "--layout", layout]

    if os.name == "nt":
        sys.exit(subprocess.call(args))
    os.execvp(ZELLIJ, args)


if __name__ == "__main__":
    main()
