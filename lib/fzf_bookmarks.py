# /// script
# requires-python = ">=3.10"
# dependencies = []
# ///

"""Search, open, add, and format plain-text bookmarks with fzf."""

from __future__ import annotations

import argparse
import codecs
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
SCHEME_RE = re.compile(r"^[A-Za-z][A-Za-z0-9+.-]*://")
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
    limit = args.max_desc_length
    for bookmark in bookmarks:
        shown_url = bookmark.url if args.show_scheme else SCHEME_RE.sub("", bookmark.url)
        if bookmark.tags:
            shown_url += " (" + ", ".join(bookmark.tags) + ")"
        shown_url = truncate(shown_url, limit)
        title = truncate(bookmark.title, limit)
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


def format_text(text: str, comment_prefix: str, descending: bool) -> str:
    """Return a canonical layout, or "" for an empty file.

    Layout: comment block, blank line, sorted bookmark block, blank line, other lines.
    Blank lines in the source are normalised to these single separators instead of
    being silently dropped; BOM and the original newline style are handled by format_file.
    """
    comments: list[str] = []
    entries: list[tuple[tuple[str, str, str], str]] = []
    others: list[str] = []
    for raw_line in text.splitlines():
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
    if not comments and not entries and not others:
        return ""
    comments.sort(reverse=descending)
    entries.sort(key=lambda entry: entry[0], reverse=descending)
    blocks: list[str] = []
    if comments:
        blocks.append("\n".join(comments))
    if entries:
        blocks.append("\n".join(entry[1] for entry in entries))
    if others:
        blocks.append("\n".join(others))
    return "\n\n".join(blocks) + "\n"


def format_file(path: str, comment_prefix: str, descending: bool, dry_run: bool = False) -> tuple[bool, str]:
    raw = Path(path).read_bytes()
    had_bom = raw.startswith(codecs.BOM_UTF8)
    text = raw.decode("utf-8-sig")
    crlf = raw.count(b"\r\n")
    lf_only = raw.count(b"\n") - crlf
    newline = "\r\n" if crlf > lf_only else "\n"

    body = format_text(text, comment_prefix, descending)
    if not body:
        return False, ""
    content = body if newline == "\n" else body.replace("\n", newline)
    if had_bom:
        content = "\ufeff" + content
    original_equivalent = ("\ufeff" if had_bom else "") + text.replace("\r\n", "\n").replace("\n", newline)
    if content == original_equivalent:
        return False, content
    if dry_run:
        return True, content
    write_with_backup(path, original_equivalent, content)
    return True, content


def add_bookmark(args: argparse.Namespace, files: list[str], dry_run: bool = False) -> None:
    if not URL_RE.fullmatch(args.add):
        raise ValueError("--add requires a URI such as https://... or file:///...")
    title = args.title.strip().replace("\\-", "-").replace("-", "\\-")
    tags = ",".join(tag.strip().replace(" ", "") for tag in args.tags.split(",") if tag.strip())
    line = args.add + ("  " + title if title else "") + (" - " + tags if tags else "")
    if dry_run:
        print(line)
        return
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
    parser.add_argument("--comment-prefix", default="#", help="Lines starting with this prefix are ignored (leading whitespace is stripped first)")
    parser.add_argument("--show-scheme", action="store_true", help="Show the full URL including its scheme; by default the scheme of every URL (http://, https://, file://, ...) is hidden in the display only")
    parser.add_argument("--opener", help="Command used to open selected URLs; the URL is appended. An empty value falls back to the default opener")
    parser.add_argument("--scheme-opener", action="append", default=[], metavar="SCHEME=COMMAND", help="Per-scheme opener; repeatable. Takes precedence over --opener; validated in every mode")
    parser.add_argument("--format", action="store_true", help="Format all discovered bookmark files and exit. Preserves BOM and the dominant newline style; normalises blank lines to single block separators")
    parser.add_argument("--descending", action="store_true", help="Sort formatted bookmarks in descending order")
    parser.add_argument("--add", metavar="URL", help="Add a bookmark and exit")
    parser.add_argument("--title", default="", help="Title used with --add")
    parser.add_argument("--tags", default="", help="Comma-separated tags used with --add")
    parser.add_argument("--output", help="Destination file used with --add")
    return parser


def main() -> int:
    parser = build_parser()
    # parse_intermixed_args lets nargs="*" query words appear between options.
    args = parser.parse_intermixed_args()
    try:
        files = files_from_options(
            args, DEFAULT_DIRECTORY, ["*.bkm", "*.txt"], allow_missing=bool(args.add)
        )
        scheme_openers = parse_scheme_openers(args.scheme_opener)
        if args.add:
            add_bookmark(args, files, dry_run=args.print_only)
            return 0
        if args.format:
            if not files:
                raise RuntimeError("No bookmark files found")
            results = [format_file(path, args.comment_prefix, args.descending, dry_run=args.print_only) for path in files]
            changed = sum(1 for did_change, _ in results if did_change)
            if args.print_only:
                for path, (did_change, content) in zip(files, results):
                    marker = "would change" if did_change else "unchanged"
                    print(f"--- {path} ({marker}) ---")
                    if did_change:
                        print(content, end="")
                print(f"Would format {changed} of {len(files)} bookmark files")
                return 0
            message = f"Formatted {changed} of {len(files)} bookmark files"
            print(message)
            if args.notify:
                notify("Bookmarks", message)
            return 0
        bookmarks = load_bookmarks(files, args.comment_prefix)
        if not bookmarks:
            raise RuntimeError("No bookmarks found")
        selected = select(make_entries(bookmarks, args), args, "Bookmarks> ")
        for url in selected:
            if args.print_only:
                print(url)
            else:
                open_bookmark(url, args.opener, scheme_openers)
        if args.notify and not args.print_only:
            notify("Bookmarks", f"Opened {len(selected)} bookmark(s)")
        return 0
    except (OSError, RuntimeError, ValueError) as exc:
        print(f"Error: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
