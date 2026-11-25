#!/usr/bin/env python3
"""Sort clipboard lines: alphabetical, by length, reversed.

Ported from PuzzTools _SORTS (Keypirinha plugin, transforms.py).
Text given on the command line replaces the clipboard; the result goes back to it.

Usage: python puzz_sort.py <alphabetical|length|reverse> [text]
"""

import argparse
import sys

from puzz_clip import get_clipboard, set_clipboard

if sys.platform == "win32":
    for stream in (sys.stdin, sys.stdout, sys.stderr):
        stream.reconfigure(encoding="utf-8")

OPS = {
    "alphabetical": lambda lines: list(sorted(lines)),
    "length": lambda lines: list(sorted(lines, key=len)),
    "reverse": lambda lines: list(reversed(lines)),
}


def main() -> int:
    parser = argparse.ArgumentParser(description="Sort clipboard lines.")
    parser.add_argument("op", choices=sorted(OPS))
    parser.add_argument(
        "text", nargs="?", default=None, help="input text (default: clipboard)"
    )
    parser.add_argument("-q", "--quiet", action="store_true", help="no summary output")
    args = parser.parse_args()

    text = args.text if args.text is not None else get_clipboard()
    text = text.replace("\r\n", "\n").replace("\r", "\n")
    lines = text.split("\n")
    if len(lines) > 1 and lines[-1] == "":  # trailing line break, same as the original
        lines.pop()
    result = "\n".join(OPS[args.op](lines))
    set_clipboard(result)

    if not args.quiet:
        print(f"Puzz Sort: {args.op}, {len(result)} chars")
    return 0


if __name__ == "__main__":
    sys.exit(main())
