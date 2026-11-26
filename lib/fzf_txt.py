"""fzf text launcher: JSON format plugins, terminal-width layout, one action."""

from __future__ import annotations

import argparse
import base64
import fnmatch
import json
import os
from pathlib import Path
import re
import shlex
import shutil
import subprocess
import sys
import unicodedata
import urllib.parse
import webbrowser
from dataclasses import dataclass


@dataclass(slots=True)
class Entry:
    display: str
    value: str


@dataclass(slots=True)
class Rule:
    regex: re.Pattern
    value: str
    display: str | None
    left: str | None
    right: str | None
    guard: str | None


@dataclass(slots=True)
class FormatSpec:
    id: str
    title: str
    includes: tuple[str, ...]
    comment_prefixes: tuple[str, ...]
    rules: tuple[Rule, ...]
    header: dict
    action: str


def expand_path(value: str) -> str:
    return os.path.expanduser(os.path.expandvars(value))


def display_width(text: str) -> int:
    return sum(2 if unicodedata.east_asian_width(ch) in "WF" else 1 for ch in text)


def clip(text: str, width: int) -> str:
    if display_width(text) <= width:
        return text
    if width <= 1:
        return "…"[:width]
    out: list[str] = []
    used = 0
    for ch in text:
        size = 2 if unicodedata.east_asian_width(ch) in "WF" else 1
        if used + size > width - 1:
            break
        out.append(ch)
        used += size
    return "".join(out) + "…"


def fit(left: str, right: str, width: int) -> str:
    if not right:
        return clip(left, width)
    room = width - display_width(right) - 2
    if room <= 0:
        return clip(right, width)
    left = clip(left, room)
    pad = width - display_width(left) - display_width(right)
    return left + " " * max(2, pad) + right


def terminal_width() -> int:
    # fzf uses two columns for the pointer and needs a small right gutter.
    return max(40, shutil.get_terminal_size((80, 24)).columns - 4)


def excluded(path: str, patterns: list[str]) -> bool:
    normalized = os.path.normpath(path).casefold().replace("\\", "/")
    basename = os.path.basename(normalized)
    segments = normalized.split("/")
    for raw in patterns:
        pattern = raw.strip().casefold()
        if not pattern:
            continue
        if pattern.endswith("/"):
            if pattern.rstrip("/") in segments:
                return True
        elif any(ch in pattern for ch in "*?["):
            if fnmatch.fnmatch(basename, pattern):
                return True
        elif basename == pattern or fnmatch.fnmatch(basename, pattern + "*") or pattern in segments[:-1]:
            return True
    return False


def included(name: str, patterns: list[str]) -> bool:
    return any(fnmatch.fnmatch(name.casefold(), pattern.casefold()) for pattern in patterns)


def discover_files(files: list[str], directories: list[str], includes: list[str],
                   excludes: list[str], allow_missing: bool) -> list[str]:
    result: list[str] = []
    seen: set[str] = set()

    def add(path: str) -> None:
        key = os.path.normpath(path).casefold()
        if key not in seen:
            seen.add(key)
            result.append(path)

    for raw in files:
        path = expand_path(raw)
        if not os.path.isfile(path):
            raise FileNotFoundError(f"Input file not found: {path}")
        if not excluded(path, excludes):
            add(path)
    for raw in directories:
        directory = expand_path(raw)
        if not os.path.isdir(directory):
            if allow_missing:
                continue
            raise FileNotFoundError(f"Input directory not found: {directory}")
        found: list[str] = []
        for root, _, names in os.walk(directory):
            for name in names:
                path = os.path.join(root, name)
                if included(name, includes) and not excluded(path, excludes):
                    found.append(path)
        for path in sorted(found, key=str.casefold):
            add(path)
    return result


def read_lines(path: str):
    with open(path, "r", encoding="utf-8-sig") as handle:
        for line in handle:
            yield line.rstrip("\r\n")


def clean_field(text: str) -> str:
    return text.replace("\t", " ").replace("\r", " ").replace("\n", " ")


def normalize_fzf_args(values: list[str]) -> list[str]:
    out: list[str] = []
    for value in values:
        if not value.strip():
            continue
        if any(ch.isspace() for ch in value):
            try:
                out.extend(shlex.split(value))
            except ValueError:
                out.extend(value.split())
        else:
            out.append(value)
    return out


def select(entries: list[Entry], args: argparse.Namespace, prompt: str) -> list[str]:
    if not entries:
        return []
    executable = os.environ.get("FZF_BIN", "fzf")
    if not shutil.which(executable):
        raise RuntimeError("fzf was not found; install fzf or set FZF_BIN")
    rows = ["\t".join((clean_field(e.display), clean_field(e.value))) for e in entries]
    fzf_args = normalize_fzf_args(args.fzf_arg)
    multi = args.multi or any(a in ("--multi", "-m") or a.startswith("--multi=") for a in fzf_args)
    command = [
        executable, "--height=80%", "--layout=reverse", "-i",
        "--delimiter=\t", "--with-nth=1", f"--prompt={prompt}",
        "--query=" + " ".join(args.query).strip(),
    ]
    if args.exact:
        command.append("--exact")
    if multi and not any(a in ("--multi", "-m") for a in fzf_args):
        command.append("--multi")
    if args.no_sort:
        command.append("--no-sort")
    command.extend(fzf_args)
    process = subprocess.run(command, input="\n".join(rows) + "\n", text=True,
                             encoding="utf-8", errors="replace", capture_output=True)
    if process.returncode in (1, 130):
        return []
    if process.returncode:
        raise RuntimeError(process.stderr.strip() or f"fzf exited with status {process.returncode}")
    return [line.split("\t", 1)[1] for line in process.stdout.splitlines() if "\t" in line]


def _powershell_clipboard(text: str, executable: str) -> bool:
    payload = base64.b64encode(text.encode("utf-8")).decode("ascii")
    script = ("$t=[Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('" + payload + "'));"
              "Set-Clipboard -Value $t")
    options: dict = {"check": True, "stdout": subprocess.DEVNULL, "stderr": subprocess.DEVNULL}
    if os.name == "nt":
        options["creationflags"] = getattr(subprocess, "CREATE_NO_WINDOW", 0)
    try:
        subprocess.run([executable, "-NoProfile", "-NonInteractive", "-Command", script], **options)
        return True
    except (OSError, subprocess.CalledProcessError):
        return False


def copy_clipboard(text: str) -> None:
    if os.name == "nt" and _powershell_clipboard(text, "powershell"):
        return
    if os.name != "nt" and shutil.which("powershell.exe") and _powershell_clipboard(text, "powershell.exe"):
        return
    candidates: list[list[str]] = []
    if os.name == "nt":
        candidates.append(["clip"])
    else:
        if shutil.which("clip.exe"):
            candidates.append(["clip.exe"])
        if sys.platform == "darwin":
            candidates.append(["pbcopy"])
        if os.environ.get("WAYLAND_DISPLAY"):
            candidates.append(["wl-copy"])
        candidates.extend([["xclip", "-selection", "clipboard"], ["xsel", "--clipboard", "--input"]])
    for command in candidates:
        if not shutil.which(command[0]):
            continue
        try:
            subprocess.run(command, input=text, text=True, encoding="utf-8", errors="replace",
                           check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            return
        except (OSError, subprocess.CalledProcessError):
            pass
    raise RuntimeError("No clipboard tool found")


def open_target(target: str) -> None:
    if not target.casefold().startswith("file://"):
        webbrowser.open(target)
        return
    import urllib.request

    parsed = urllib.parse.urlparse(target)
    path = urllib.request.url2pathname(urllib.parse.unquote(parsed.path))
    if parsed.netloc and parsed.netloc.lower() != "localhost":
        path = "//" + parsed.netloc + path
    path = os.path.normpath(path)
    if os.name == "nt":
        os.startfile(path)  # type: ignore[attr-defined]
    elif sys.platform == "darwin":
        subprocess.Popen(["open", path], stdin=subprocess.DEVNULL,
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    else:
        subprocess.Popen(["xdg-open", path], stdin=subprocess.DEVNULL,
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


class _Fields(dict):
    def __missing__(self, key: str) -> str:
        return ""


def render(template: str, fields: dict) -> str:
    try:
        return template.format_map(_Fields(fields))
    except (KeyError, ValueError, IndexError):
        return template


META_RE = re.compile(r"^\s*#\s*(?P<key>[^:]+?)\s*:\s*(?P<rest>.+?)\s*$")


@dataclass(frozen=True, slots=True)
class FileMeta:
    values: dict[str, frozenset[str]]


EMPTY_META = FileMeta({})


def parse_file_meta(lines) -> FileMeta:
    found: dict[str, set[str]] = {}
    for line in lines:
        match = META_RE.match(line)
        if not match:
            continue
        key = match.group("key").strip().casefold()
        found.setdefault(key, set()).update(
            item.strip().casefold() for item in match.group("rest").split(",") if item.strip()
        )
    return FileMeta({key: frozenset(values) for key, values in found.items()})


def group_allowed(meta: FileMeta, header: dict, group: str) -> bool:
    key = group.strip().casefold()
    include = meta.values.get(header.get("include", "").casefold(), frozenset())
    exclude = meta.values.get(header.get("exclude", "").casefold(), frozenset())
    return (not include or key in include) and key not in exclude


def fields_for_line(line: str, rule: Rule) -> dict | None:
    match = rule.regex.match(line)
    if not match:
        return None
    return {key: (value or "") for key, value in match.groupdict().items()}


def eval_line(line: str, fmt: FormatSpec, meta: FileMeta, width: int) -> Entry | None:
    text = line.strip()
    if not text or any(prefix and text.startswith(prefix) for prefix in fmt.comment_prefixes):
        return None
    for rule in fmt.rules:
        fields = fields_for_line(text, rule)
        if fields is None:
            continue
        if rule.guard and not group_allowed(meta, fmt.header, fields.get(rule.guard, "")):
            return None
        fields["line"] = line
        value = render(rule.value, fields).strip()
        if not value:
            return None
        if rule.left is not None:
            display = fit(render(rule.left, fields), render(rule.right or "", fields), width)
        else:
            display = render(rule.display or "{line}", fields)
        return Entry(display, value)
    return None


def action_copy(values: list[str]) -> None:
    copy_clipboard("\n".join(values))


def action_open_url(values: list[str]) -> None:
    for url in values:
        open_target(url)


ACTIONS = {"copy": action_copy, "open_url": action_open_url}


def compile_format(raw: dict) -> FormatSpec:
    rules = []
    for item in raw["rules"]:
        rules.append(Rule(
            regex=re.compile(item["match"]),
            value=item["value"],
            display=item.get("display"),
            left=item.get("left"),
            right=item.get("right"),
            guard=item.get("guard"),
        ))
    return FormatSpec(
        id=raw["id"],
        title=raw.get("title", raw["id"]),
        includes=tuple(raw.get("includes", ["*.txt"])),
        comment_prefixes=tuple(raw.get("comment_prefixes", ["#"])),
        rules=tuple(rules),
        header=dict(raw.get("header", {})),
        action=raw.get("action", "copy"),
    )


def load_formats(extra: list[str]) -> dict[str, FormatSpec]:
    formats: dict[str, FormatSpec] = {}
    directories = [str(Path(__file__).resolve().parent / "formats")]
    directories.extend(expand_path(item) for item in extra)
    for directory in directories:
        folder = Path(directory)
        if not folder.is_dir():
            continue
        for path in sorted(folder.glob("*.json")):
            raw = json.loads(path.read_text(encoding="utf-8-sig"))
            formats[raw["id"]] = compile_format(raw)
    return formats


def add_common_options(parser: argparse.ArgumentParser) -> None:
    parser.add_argument("query", nargs="*")
    parser.add_argument("-f", "--file", dest="files", action="append", default=[])
    parser.add_argument("-d", "--directory", dest="directories", action="append", default=[])
    parser.add_argument("--exclude", dest="excludes", action="append", default=[])
    parser.add_argument("--print", dest="print_only", action="store_true")
    parser.add_argument("--exact", action="store_true")
    parser.add_argument("--multi", action="store_true")
    parser.add_argument("--no-sort", action="store_true")
    parser.add_argument("--fzf-arg", action="append", default=[])
    parser.add_argument("--list-files", action="store_true")


def files_from_options(args: argparse.Namespace, fmt: FormatSpec, count_line) -> list[str]:
    directories = args.directories
    used_default = False
    if not args.files and not directories:
        base = os.environ.get("USERHOME") or str(Path.home())
        directories = [os.path.join(base, "Share", "files", fmt.id)]
        used_default = True
    paths = discover_files(args.files, directories, list(fmt.includes), args.excludes, used_default)
    if args.list_files:
        for path in paths:
            with open(path, "r", encoding="utf-8-sig") as handle:
                lines = [line.rstrip("\r\n") for line in handle]
            print(f"{len(lines):>6} lines  valid={sum(1 for line in lines if count_line(line, path))}  {path}")
        print(f"-- {len(paths)} file(s) discovered")
        raise SystemExit(0)
    return paths


def run(fmt: FormatSpec, argv: list[str]) -> int:
    parser = argparse.ArgumentParser(prog=f"fzf_txt.py {fmt.id}", description=fmt.title)
    add_common_options(parser)
    args = parser.parse_intermixed_args(argv)
    width = terminal_width()
    cache: dict[str, FileMeta] = {}

    def meta_for(path: str) -> FileMeta:
        if path not in cache:
            try:
                with open(path, "r", encoding="utf-8-sig") as handle:
                    cache[path] = parse_file_meta(line.rstrip("\r\n") for line in handle)
            except OSError:
                cache[path] = EMPTY_META
        return cache[path]

    try:
        files = files_from_options(
            args, fmt, lambda line, path: eval_line(line, fmt, meta_for(path), width) is not None
        )
        entries: list[Entry] = []
        for path in files:
            for line in read_lines(path):
                entry = eval_line(line, fmt, meta_for(path), width)
                if entry:
                    entries.append(entry)
        if not entries:
            raise RuntimeError(f"No {fmt.id} entries found")
        values = select(entries, args, f"{fmt.title}> ")
        if not values:
            return 0
        if args.print_only:
            print("\n".join(values))
        else:
            ACTIONS[fmt.action](values)
        return 0
    except SystemExit as exc:
        return int(exc.code or 0)
    except (OSError, RuntimeError, ValueError) as exc:
        print(f"Error: {exc}", file=sys.stderr)
        return 1


def pre_scan(argv: list[str]) -> tuple[list[str], list[str]]:
    extra: list[str] = []
    rest: list[str] = []
    index = 0
    while index < len(argv):
        item = argv[index]
        if item == "--formats" and index + 1 < len(argv):
            extra.append(argv[index + 1])
            index += 2
        elif item.startswith("--formats="):
            extra.append(item.split("=", 1)[1])
            index += 1
        else:
            rest.append(item)
            index += 1
    return extra, rest


def main() -> int:
    extra, argv = pre_scan(sys.argv[1:])
    formats = load_formats(extra)
    if argv and argv[0] in ("-h", "--help", "--list-formats"):
        if argv[0] == "--list-formats":
            for name, spec in sorted(formats.items()):
                print(f"{name:<14} {len(spec.rules)} rules  action={spec.action}")
            return 0
        print("Usage: fzf_txt.py {bookmarks|cheatsheets|commands|shortcuts} [args...]")
        print("Formats: " + ", ".join(sorted(formats)))
        return 0
    if not argv:
        print("Usage: fzf_txt.py {bookmarks|cheatsheets|commands|shortcuts} [args...]", file=sys.stderr)
        return 2
    fmt = formats.get(argv[0])
    if fmt is None:
        print(f"Unknown format: {argv[0]}. Available: {', '.join(sorted(formats))}", file=sys.stderr)
        return 2
    return run(fmt, argv[1:])


if __name__ == "__main__":
    raise SystemExit(main())
