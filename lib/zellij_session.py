#!/usr/bin/env python3
"""Attach to a Zellij session, creating it when it does not exist.

Usage:
    zellij-session                 # session "session"
    zellij-session <name>          # named session
    zellij-session <dir>           # session named after the directory

Every session uses the default layout; only "session" is special, and only in
that it has no directory to name it after.
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
    if len(sys.argv) > 2:
        sys.exit("zellij-session: expected at most one argument")

    path = os.path.expanduser(target)
    if os.path.isdir(path):
        os.chdir(path)
        name = os.path.basename(os.path.abspath(path))
    else:
        name = target

    name = re.sub(r"[^A-Za-z0-9_-]+", "-", name).strip("-") or "session"

    if name in session_names():
        args = [ZELLIJ, "attach", name]
    elif os.name == "nt":
        # Scripted shells (no console) cannot create a Zellij session on Windows:
        # every creation route needs a live client or dies with its console.
        if not os.isatty(1):
            sys.exit(
                "zellij-session: run this from an interactive terminal "
                "(a script cannot create the session)"
            )
        args = [ZELLIJ, "attach", name, "--create"]
    else:
        args = [ZELLIJ, "--session", name]

    if os.name == "nt":
        sys.exit(subprocess.call(args))
    os.execvp(ZELLIJ, args)


if __name__ == "__main__":
    main()
