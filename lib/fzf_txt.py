"""Shared helpers for the text-based fzf commands."""

from __future__ import annotations

import argparse
import fnmatch
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import sys
import urllib.parse
import urllib.request
import webbrowser
from dataclasses import dataclass
from typing import Iterable, Iterator


@dataclass(slots=True)
class Entry:
    display: str
    value: str


def expand_path(value: str) -> str:
    return os.path.expandvars(os.path.expanduser(value))


def add_common_options(parser: argparse.ArgumentParser) -> None:
    parser.add_argument("query", nargs="*", help="Initial fzf query")
    parser.add_argument("-f", "--file", dest="files", action="append", default=[], help="Input file; repeatable")
    parser.add_argument("-d", "--directory", dest="directories", action="append", default=[], help="Recursive input directory; repeatable")
    parser.add_argument("--include", dest="includes", action="append", metavar="GLOB", help="Included filename glob; repeatable")
    parser.add_argument("--exclude", dest="excludes", action="append", default=[], metavar="GLOB", help="Excluded filename glob, or NAME/ for a directory; repeatable")
    parser.add_argument("--exact", action="store_true", help="Use exact substring matching instead of fuzzy matching")
    parser.add_argument("--multi", action="store_true", help="Allow multiple selections")
    parser.add_argument("--no-sort", action="store_true", help="Preserve input order instead of fzf ranking")
    parser.add_argument("--max-desc-length", type=int, default=50, metavar="N", help="Description character limit; 0 disables truncation")
    parser.add_argument("--print", dest="print_only", action="store_true", help="Print selected values instead of executing an action")
    parser.add_argument("--notify", action="store_true", help="Show a desktop notification after an action")
    parser.add_argument("--fzf-arg", action="append", default=[], metavar="ARG", help="Additional fzf argument; repeatable")


def files_from_options(args: argparse.Namespace, default_directory: Path, default_includes: list[str]) -> list[str]:
    directories = args.directories
    if not args.files and not directories:
        directories = [str(default_directory)]
    return discover_files(
        args.files,
        directories,
        args.includes or default_includes,
        args.excludes,
    )


def excluded(path: str, patterns: Iterable[str]) -> bool:
    normalized = os.path.normpath(path).casefold().replace("\\", "/")
    basename = os.path.basename(normalized)
    for pattern in patterns:
        pattern = pattern.strip().casefold()
        if not pattern:
            continue
        if pattern.endswith("/"):
            if pattern.rstrip("/") in normalized.split("/"):
                return True
        elif fnmatch.fnmatch(basename, pattern):
            return True
    return False


def directory_excluded(name: str, patterns: Iterable[str]) -> bool:
    name = name.casefold()
    return any(p.strip().casefold().endswith("/") and name == p.strip().casefold().rstrip("/") for p in patterns)


def included(name: str, patterns: Iterable[str]) -> bool:
    name = name.casefold()
    return any(fnmatch.fnmatch(name, pattern.casefold()) for pattern in patterns)


def discover_files(files: Iterable[str], directories: Iterable[str], includes: list[str], excludes: list[str]) -> list[str]:
    result: list[str] = []
    seen: set[str] = set()

    def add(path: str) -> None:
        key = os.path.normpath(path).casefold()
        if key not in seen:
            seen.add(key)
            result.append(path)

    for raw_path in files:
        path = expand_path(raw_path)
        if not os.path.isfile(path):
            raise FileNotFoundError(f"Input file not found: {path}")
        add(path)
    for raw_directory in directories:
        directory = expand_path(raw_directory)
        if not os.path.isdir(directory):
            continue
        discovered: list[str] = []
        for root, dirs, filenames in os.walk(directory):
            dirs[:] = sorted(name for name in dirs if not directory_excluded(name, excludes))
            for filename in filenames:
                path = os.path.join(root, filename)
                if included(filename, includes) and not excluded(path, excludes):
                    discovered.append(path)
        for path in sorted(discovered, key=str.casefold):
            add(path)
    return result


def read_lines(path: str) -> Iterator[str]:
    with open(path, "r", encoding="utf-8-sig") as handle:
        for line in handle:
            yield line.rstrip("\r\n")


def truncate(text: str, limit: int) -> str:
    if limit <= 0 or len(text) <= limit:
        return text
    if limit <= 3:
        return text[:limit]
    return text[:limit - 3] + "..."


def clean_field(text: str) -> str:
    return text.replace("\t", " ").replace("\r", " ").replace("\n", " ")


def select(entries: list[Entry], args: argparse.Namespace, prompt: str) -> list[str]:
    if not entries:
        return []
    executable = os.environ.get("FZF_BIN", "fzf")
    if not shutil.which(executable):
        raise RuntimeError("fzf was not found; install fzf or set FZF_BIN")
    rows = ["\t".join((clean_field(entry.display), clean_field(entry.value))) for entry in entries]
    command = [
        executable,
        "--height=80%",
        "--layout=reverse",
        "-i",
        "--delimiter=\t",
        "--with-nth=1",
        f"--prompt={prompt}",
        "--header=Enter: select | Esc: quit" + (" | Tab: multi-select" if args.multi else ""),
        "--query=" + " ".join(args.query).strip(),
    ]
    if args.exact:
        command.append("--exact")
    if args.multi:
        command.append("--multi")
    if args.no_sort:
        command.append("--no-sort")
    command.extend(args.fzf_arg)
    process = subprocess.run(command, input="\n".join(rows) + "\n", text=True, capture_output=True)
    if process.returncode in (1, 130):
        return []
    if process.returncode != 0:
        raise RuntimeError(process.stderr.strip() or f"fzf exited with status {process.returncode}")
    values: list[str] = []
    for line in process.stdout.splitlines():
        fields = line.split("\t")
        if len(fields) >= 2:
            values.append(fields[1])
    return values


def split_command(command: str) -> list[str]:
    expanded = expand_path(command)
    try:
        parts = shlex.split(expanded, posix=os.name != "nt")
    except ValueError:
        parts = expanded.split()
    if os.name == "nt":
        parts = [part.strip('"') for part in parts]
    if not parts:
        raise RuntimeError("The command is empty")
    parts[0] = expand_path(parts[0].strip('"'))
    return parts


def launch(command: list[str]) -> None:
    options: dict = {"stdin": subprocess.DEVNULL, "stdout": subprocess.DEVNULL, "stderr": subprocess.DEVNULL}
    if os.name == "nt":
        options["creationflags"] = getattr(subprocess, "CREATE_NO_WINDOW", 0)
    else:
        options["start_new_session"] = True
    subprocess.Popen(command, **options)


def file_url_to_path(url: str) -> str:
    parsed = urllib.parse.urlparse(url)
    path = urllib.request.url2pathname(urllib.parse.unquote(parsed.path))
    if parsed.netloc and parsed.netloc.lower() != "localhost":
        path = "//" + parsed.netloc + path
    return os.path.normpath(path)


def open_path(path: str) -> None:
    if os.name == "nt":
        os.startfile(path)  # type: ignore[attr-defined]
    elif sys.platform == "darwin":
        launch(["open", path])
    else:
        launch(["xdg-open", path])


def open_target(target: str) -> None:
    if target.casefold().startswith("file://"):
        open_path(file_url_to_path(target))
    else:
        webbrowser.open(target)


def copy_clipboard(text: str) -> None:
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
            subprocess.run(command, input=text, text=True, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            return
        except (OSError, subprocess.CalledProcessError):
            pass
    raise RuntimeError("No clipboard tool found; use clip, pbcopy, wl-copy, xclip, or xsel")


def notify(title: str, message: str) -> None:
    try:
        if os.name == "nt":
            safe_title = title.replace("'", "''")
            safe_message = message.replace("'", "''")
            script = (
                "Add-Type -AssemblyName System.Windows.Forms;"
                "$n=New-Object System.Windows.Forms.NotifyIcon;"
                "$n.Icon=[System.Drawing.SystemIcons]::Information;$n.Visible=$true;"
                f"$n.ShowBalloonTip(3000,'{safe_title}','{safe_message}','Info');"
                "Start-Sleep 4;$n.Dispose()"
            )
            subprocess.Popen(
                ["powershell", "-NoProfile", "-NonInteractive", "-WindowStyle", "Hidden", "-Command", script],
                creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0),
            )
        elif sys.platform == "darwin":
            safe_title = title.replace("\\", "\\\\").replace('"', '\\"')
            safe_message = message.replace("\\", "\\\\").replace('"', '\\"')
            subprocess.Popen(["osascript", "-e", f'display notification "{safe_message}" with title "{safe_title}"'])
        elif shutil.which("notify-send"):
            subprocess.Popen(["notify-send", title, message])
        else:
            print(f"[{title}] {message}", file=sys.stderr)
    except OSError:
        print(f"[{title}] {message}", file=sys.stderr)


def write_with_backup(path: str, original: str, content: str) -> bool:
    if content == original:
        return False
    backup = path + ".bak"
    try:
        with open(backup, "w", encoding="utf-8") as handle:
            handle.write(original)
        with open(path, "w", encoding="utf-8", newline="\n") as handle:
            handle.write(content)
    except OSError:
        try:
            shutil.copyfile(backup, path)
        except OSError as exc:
            raise RuntimeError(f"Failed to restore {path}: {exc}") from exc
        raise
    return True
