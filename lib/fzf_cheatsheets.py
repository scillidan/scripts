# /// script
# requires-python = ">=3.10"
# dependencies = []
# ///

"""Search plain-text cheatsheets with fzf and copy the selected shortcuts."""

from __future__ import annotations

import argparse
from pathlib import Path
import re
import sys
from dataclasses import dataclass

from fzf_txt import (
    Entry,
    add_common_options,
    copy_clipboard,
    files_from_options,
    notify,
    read_lines,
    select,
    truncate,
)


DEFAULT_DIRECTORY = Path.home() / ".cheatsheet"


@dataclass(slots=True)
class Cheat:
    description: str
    shortcut: str


def parse_cheat(line: str, comment_prefixes: list[str]) -> Cheat | None:
    line = line.strip()
    if not line or any(prefix and line.startswith(prefix) for prefix in comment_prefixes):
        return None
    parts = re.split(r"(?<!\\)\|", line, maxsplit=1)
    if len(parts) != 2:
        return None
    return Cheat(parts[0].strip(), parts[1].strip())


def load_cheats(files: list[str], comment_prefixes: list[str]) -> list[Cheat]:
    cheats: list[Cheat] = []
    for path in files:
        for line in read_lines(path):
            cheat = parse_cheat(line, comment_prefixes)
            if cheat:
                cheats.append(cheat)
    return cheats


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    add_common_options(parser)
    parser.add_argument("--comment-prefix", action="append", metavar="TEXT", help="Comment prefix; repeatable, default: #. Leading whitespace is stripped first")
    parser.add_argument("--unescape-pipes", action="store_true", help="Convert \\| to | before copying (applies to --print too)")
    return parser


def main() -> int:
    parser = build_parser()
    args = parser.parse_intermixed_args()
    try:
        files = files_from_options(args, DEFAULT_DIRECTORY, ["*.cht", "*.conf"])
        cheats = load_cheats(files, args.comment_prefix or ["#"])
        if not cheats:
            raise RuntimeError("No cheatsheets found")
        limit = args.max_desc_length
        entries = [
            Entry(
                f"{truncate(cheat.description, limit)} - {truncate(cheat.shortcut, limit)}",
                cheat.shortcut,
            )
            for cheat in cheats
        ]
        selected = select(entries, args, "Cheatsheets> ")
        if args.unescape_pipes:
            selected = [shortcut.replace("\\|", "|") for shortcut in selected]
        if not selected:
            return 0
        text = "\n".join(selected)
        if args.print_only:
            print(text)
        else:
            copy_clipboard(text)
            if args.notify:
                notify("Cheatsheets", "Copied: " + text)
        return 0
    except (OSError, RuntimeError, ValueError) as exc:
        print(f"Error: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
