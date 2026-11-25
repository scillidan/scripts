"""Convert clipboard text.

Text given on the command line replaces the clipboard; the result is printed (and also
copied to the clipboard when one is available).

Inspired by https://github.com/EhsanKia/Keypirinha-PuzzTools.

Usage: python puzz_transform.py <option> [text]
"""

import argparse
import re
import sys

from puzz_clip import get_clipboard, set_clipboard

if sys.platform == "win32":
    for stream in (sys.stdin, sys.stdout, sys.stderr):
        stream.reconfigure(encoding="utf-8")

GITHUB_REPO = r"https://github\.com/([^/]+)/([^/]+)(?:/.*)?"


def ghurlapi(text: str) -> str:
    """github.com/owner/repo -> api.github.com/repos/owner/repo (an api url stays as it is)"""
    return re.sub(
        r"^https://github\.com/(?:repos/)?", "https://api.github.com/repos/", text
    )


def scoopwhere(path: str) -> str:
    """C:\\Users\\User\\Scoop\\shims\\fzf.exe -> C:\\Users\\User\\Scoop\\apps\\fzf\\current\\fzf.exe"""
    leaf = re.split(r"\\", path)[-1]
    return path.replace("\\shims\\", "\\apps\\").replace(".exe", f"\\current\\{leaf}")


TRANSFORMS = {
    "delspace": lambda x: re.sub(r"[\s\xa0]+", "", x),
    "delquery": lambda x: x.split("?")[0],
    "ghcommitsatom": lambda x: re.sub(
        GITHUB_REPO, r"https://github.com/\1/\2/commits.atom", x
    ),
    "ghreleasesatom": lambda x: re.sub(
        GITHUB_REPO, r"https://github.com/\1/\2/releases.atom", x
    ),
    "ghurlapi": ghurlapi,
    "ghurlraw": lambda x: re.sub(
        r"https://github\.com/([^/]+)/([^/]+)/blob/([^/]+)/(.+)",
        r"https://raw.githubusercontent.com/\1/\2/refs/heads/\3/\4",
        x,
    ),
    "ghurlshorter": lambda x: re.sub(GITHUB_REPO, r"\1/\2", x),
    "linessplitbycomma": lambda x: ", ".join(x.splitlines()).lower(),
    "scoopwhere": scoopwhere,
    "unixlink": lambda x: x.replace("\\", "/"),
    "unixlink2": lambda x: x.replace("\\\\", "/"),
    "windowslink": lambda x: x.replace("/", "\\"),
    "windowslink2": lambda x: x.replace("\\", "\\\\"),
}


def main() -> int:
    parser = argparse.ArgumentParser(description="Convert clipboard URLs and paths.")
    parser.add_argument("transform", choices=sorted(TRANSFORMS))
    parser.add_argument(
        "text", nargs="?", default=None, help="input text (default: clipboard)"
    )
    parser.add_argument("-q", "--quiet", action="store_true", help="no summary output")
    args = parser.parse_args()

    text = args.text if args.text is not None else get_clipboard()
    result = str(TRANSFORMS[args.transform](text.rstrip("\r\n")))
    set_clipboard(result)

    if args.quiet:
        print(result)
    else:
        print(f"Puzz Transform: {args.transform}, {len(result)} chars")
        print(result)
    return 0


if __name__ == "__main__":
    sys.exit(main())
