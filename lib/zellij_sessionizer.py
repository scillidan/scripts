#!/usr/bin/env python3
"""Pick a directory with fzf and switch to its Zellij project session.

Usage:
    zellij-sessionizer              # fzf over zoxide directories
    zellij-sessionizer --dir PATH   # skip fzf (useful for scripts/tests)
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


def pick_directory():
    if len(sys.argv) > 2 and sys.argv[1] == "--dir":
        return sys.argv[2]

    try:
        zoxide = subprocess.run(
            ["zoxide", "query", "-l"],
            capture_output=True,
            text=True,
            timeout=5,
        )
        candidates = [
            line for line in zoxide.stdout.splitlines() if os.path.isdir(line)
        ]
    except (OSError, subprocess.SubprocessError):
        candidates = []

    if not candidates:
        candidates = [os.getcwd()]

    fzf = subprocess.run(
        ["fzf", "--height=100%", "--reverse", "--prompt=project> "],
        input="\n".join(candidates),
        stdout=subprocess.PIPE,
        text=True,
    )
    if fzf.returncode != 0:
        return None
    return fzf.stdout.strip()


def main():
    directory = pick_directory()
    if not directory:
        return

    name = re.sub(
        r"[^A-Za-z0-9_-]+", "-", os.path.basename(directory.rstrip("/\\"))
    ).strip("-")
    name = name or "session"

    args = [ZELLIJ, "action", "switch-session", name]
    if name not in session_names():
        args += ["-l", "project", "-c", directory]

    sys.exit(subprocess.call(args))


if __name__ == "__main__":
    main()
