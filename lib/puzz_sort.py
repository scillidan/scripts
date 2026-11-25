"""Sort clipboard lines: alphabetical, by length, reversed.

Text given on the command line replaces the clipboard; the result is printed (and also
copied to the clipboard when one is available).

Inspired by https://github.com/EhsanKia/Keypirinha-PuzzTools.

Usage: python puzz_sort.py <alphabetical|length|reverse> [text]
"""

import argparse
import sys

from puzz_clip import get_clipboard, set_clipboard

if sys.platform == "win32":
    for stream in (sys.stdin, sys.stdout, sys.stderr):
        stream.reconfigure(encoding="utf-8")

SORTS = {
    "alphabetical": lambda lines: list(sorted(lines)),
    "length": lambda lines: list(sorted(lines, key=len)),
    "reverse": lambda lines: list(reversed(lines)),
}


def main() -> int:
    parser = argparse.ArgumentParser(description="Sort clipboard lines.")
    parser.add_argument("sort", choices=sorted(SORTS))
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
    result = "\n".join(SORTS[args.sort](lines))
    set_clipboard(result)

    if args.quiet:
        print(result)
    else:
        print(f"Puzz Sort: {args.sort}, {len(result)} chars")
        print(result)
    return 0


if __name__ == "__main__":
    sys.exit(main())
