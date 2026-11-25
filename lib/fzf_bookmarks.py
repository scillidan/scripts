# /// script
# requires-python = ">=3.10"
# dependencies = []
# ///

"""Search, open, add, and format plain-text bookmarks with fzf."""

from __future__ import annotations

import argparse
import os
from pathlib import Path
import re
import sys
import urllib.parse
from dataclasses import dataclass

from fzf_txt import (
    Entry,
    add_common_options,
    expand_path,
    files_from_options,
    launch,
    notify,
    open_target,
    read_lines,
    select,
    split_command,
    truncate,
    write_with_backup,
)


URL_RE = re.compile(r"(\w+://\S+)")
DEFAULT_DIRECTORY = Path.home() / ".bookmarks"


@dataclass(slots=True)
class Bookmark:
    url: str
    title: str
    tags: list[str]


def parse_bookmark(line: str, comment_prefix: str) -> Bookmark | None:
    line = line.strip()
    if not line or (comment_prefix and line.startswith(comment_prefix)):
        return None
    match = URL_RE.search(line)
    if not match:
        return None
    url = match.group(1)
    before = line[:match.start()].strip()
    after = line[match.end():]
    title_after = after.strip()
    tags: list[str] = []
    separator = after.rfind(" - ")
    if separator >= 0:
        possible_tags = after[separator + 3:].strip()
        if possible_tags and re.fullmatch(r"[^,\s]+(,[^,\s]+)*", possible_tags):
            title_after = after[:separator].strip()
            tags = [tag.strip() for tag in possible_tags.split(",") if tag.strip()]
    title = " ".join(part for part in (before, title_after) if part).replace("\\-", "-")
    return Bookmark(url, title or re.sub(r"^\w+://", "", url), tags)


def load_bookmarks(files: list[str], comment_prefix: str) -> list[Bookmark]:
    bookmarks: list[Bookmark] = []
    for path in files:
        for line in read_lines(path):
            bookmark = parse_bookmark(line, comment_prefix)
            if bookmark:
                bookmarks.append(bookmark)
    return bookmarks


def make_entries(bookmarks: list[Bookmark], args: argparse.Namespace) -> list[Entry]:
    entries: list[Entry] = []
    for bookmark in bookmarks:
        shown_url = bookmark.url if args.show_scheme else re.sub(r"^https?://", "", bookmark.url)
        if bookmark.tags:
            shown_url += " (" + ", ".join(bookmark.tags) + ")"
        title = truncate(bookmark.title, args.max_desc_length)
        entries.append(Entry(f"{title}  |  {shown_url}", bookmark.url))
    return entries


def parse_scheme_openers(values: list[str]) -> dict[str, str]:
    openers: dict[str, str] = {}
    for value in values:
        scheme, separator, command = value.partition("=")
        if not separator or not scheme.strip() or not command.strip():
            raise ValueError("--scheme-opener expects SCHEME=COMMAND")
        openers[scheme.strip().casefold()] = command.strip()
    return openers


def open_bookmark(url: str, opener: str | None, scheme_openers: dict[str, str]) -> None:
    scheme = urllib.parse.urlparse(url).scheme.casefold()
    command = scheme_openers.get(scheme) or opener
    if command:
        launch(split_command(command) + [url])
    else:
        open_target(url)


def format_file(path: str, comment_prefix: str, descending: bool) -> bool:
    with open(path, "r", encoding="utf-8-sig") as handle:
        original = handle.read()
    comments: list[str] = []
    entries: list[tuple[tuple[str, str, str], str]] = []
    others: list[str] = []
    for raw_line in original.splitlines():
        line = raw_line.strip()
        if not line:
            continue
        if comment_prefix and line.startswith(comment_prefix):
            comments.append(line)
            continue
        match = URL_RE.search(line)
        if not match:
            others.append(line)
            continue
        url = match.group(1)
        before = line[:match.start()].strip()
        formatted = url + ("  " + before if before else "") + line[match.end():]
        bookmark = parse_bookmark(formatted, comment_prefix)
        key = ("", "", "")
        if bookmark:
            key = (",".join(bookmark.tags).casefold(), bookmark.title.casefold(), bookmark.url.casefold())
        entries.append((key, formatted))
    if not entries and not others:
        return False
    comments.sort(reverse=descending)
    entries.sort(key=lambda entry: entry[0], reverse=descending)
    content = "\n".join(comments + [entry[1] for entry in entries] + others) + "\n"
    return write_with_backup(path, original, content)


def add_bookmark(args: argparse.Namespace, files: list[str]) -> None:
    if not URL_RE.fullmatch(args.add):
        raise ValueError("--add requires a URI such as https://... or file:///...")
    title = args.title.strip().replace("\\-", "-").replace("-", "\\-")
    tags = ",".join(tag.strip().replace(" ", "") for tag in args.tags.split(",") if tag.strip())
    line = args.add + ("  " + title if title else "") + (" - " + tags if tags else "")
    if args.output:
        output = expand_path(args.output)
    elif files:
        output = files[0]
    elif args.directories:
        output = os.path.join(expand_path(args.directories[0]), "bookmarks.bkm")
    else:
        output = str(DEFAULT_DIRECTORY / "bookmarks.bkm")
    os.makedirs(os.path.dirname(os.path.abspath(output)), exist_ok=True)
    with open(output, "a", encoding="utf-8", newline="\n") as handle:
        handle.write(line + "\n")
    print(f"Added to {output}: {line}")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    add_common_options(parser)
    parser.add_argument("--comment-prefix", default="#", help="Lines starting with this prefix are ignored")
    parser.add_argument("--show-scheme", action="store_true", help="Show http:// and https:// in results")
    parser.add_argument("--opener", help="Command used to open selected URLs; the URL is appended")
    parser.add_argument("--scheme-opener", action="append", default=[], metavar="SCHEME=COMMAND", help="Per-scheme opener; repeatable")
    parser.add_argument("--format", action="store_true", help="Format all discovered bookmark files and exit")
    parser.add_argument("--descending", action="store_true", help="Sort formatted bookmarks in descending order")
    parser.add_argument("--add", metavar="URL", help="Add a bookmark and exit")
    parser.add_argument("--title", default="", help="Title used with --add")
    parser.add_argument("--tags", default="", help="Comma-separated tags used with --add")
    parser.add_argument("--output", help="Destination file used with --add")
    return parser


def main() -> int:
    args = build_parser().parse_args()
    try:
        files = files_from_options(args, DEFAULT_DIRECTORY, ["*.bkm", "*.txt"])
        if args.add:
            add_bookmark(args, files)
            return 0
        if args.format:
            if not files:
                raise RuntimeError("No bookmark files found")
            changed = sum(format_file(path, args.comment_prefix, args.descending) for path in files)
            message = f"Formatted {changed} of {len(files)} bookmark files"
            print(message)
            if args.notify:
                notify("Bookmarks", message)
            return 0
        bookmarks = load_bookmarks(files, args.comment_prefix)
        if not bookmarks:
            raise RuntimeError("No bookmarks found")
        scheme_openers = parse_scheme_openers(args.scheme_opener)
        selected = select(make_entries(bookmarks, args), args, "Bookmarks> ")
        for url in selected:
            if args.print_only:
                print(url)
            else:
                open_bookmark(url, args.opener, scheme_openers)
        return 0
    except (OSError, RuntimeError, ValueError) as exc:
        print(f"Error: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
