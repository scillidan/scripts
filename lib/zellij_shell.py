#!/usr/bin/env python3
"""Start the platform's interactive shell inside a Zellij pane."""

import os
import subprocess
import sys


def main():
    if os.name == "nt":
        userhome = os.environ.get("USERHOME") or os.environ.get("USERPROFILE")
        if len(sys.argv) > 1 and sys.argv[1] in ("-c", "/c"):
            sys.exit(subprocess.call(["cmd.exe", "/c", " ".join(sys.argv[2:])]))
        init = os.path.join(
            userhome, "Share", "dotfiles.win", "Scoop", "clink", "init.cmd"
        )
        if os.path.exists(init):
            sys.exit(subprocess.call(["cmd.exe", "/k", init]))
        sys.exit(subprocess.call(["cmd.exe"]))
    else:
        shell = os.environ.get("SHELL") or "/bin/bash"
        os.execvp(shell, [shell] + sys.argv[1:])


if __name__ == "__main__":
    main()
