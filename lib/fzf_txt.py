"""Shared helpers for the text-based fzf commands."""

from __future__ import annotations

import argparse
import base64
import codecs
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


GLOB_CHARS = frozenset("*?[")


def nonnegative_int(value: str) -> int:
    try:
        number = int(value)
    except ValueError as exc:
        raise argparse.ArgumentTypeError("expected a non-negative integer") from exc
    if number < 0:
        raise argparse.ArgumentTypeError("expected a non-negative integer, got " + value)
    return number


def expand_path(value: str) -> str:
    return os.path.expandvars(os.path.expanduser(value))


def add_common_options(parser: argparse.ArgumentParser) -> None:
    parser.add_argument("query", nargs="*", help="Initial fzf query (may be mixed with options; use -- to start a query with a dash)")
    parser.add_argument("-f", "--file", dest="files", action="append", default=[], help="Input file; repeatable. Still subject to --exclude, but exempt from --include globs")
    parser.add_argument("-d", "--directory", dest="directories", action="append", default=[], help="Recursive input directory; repeatable. A missing directory is an error")
    parser.add_argument("--include", dest="includes", action="append", metavar="GLOB", help="Additional filename glob; repeatable. Adds to the defaults; use --no-default-includes to replace them")
    parser.add_argument("--no-default-includes", action="store_true", help="Make --include replace (instead of extend) the default filename globs")
    parser.add_argument("--exclude", dest="excludes", action="append", default=[], metavar="GLOB", help="Excluded name: a glob, a bare NAME (matches NAME, NAME* and any directory named NAME), or NAME/ (directory only); repeatable")
    parser.add_argument("--exact", action="store_true", help="Use exact substring matching instead of fuzzy matching")
    parser.add_argument("--multi", action="store_true", help="Allow multiple selections")
    parser.add_argument("--no-sort", action="store_true", help="Preserve input order instead of fzf ranking")
    parser.add_argument("--max-desc-length", type=nonnegative_int, default=50, metavar="N", help="Per-field character limit for every displayed field (title, URL, tags, shortcut); 0 disables truncation")
    parser.add_argument("--print", dest="print_only", action="store_true", help="Print selected values instead of acting; with --add/--format acts as a dry run")
    parser.add_argument("--notify", action="store_true", help="Show a desktop notification after the action (not in dry-run mode)")
    parser.add_argument("--fzf-arg", action="append", default=[], metavar="ARG", help="Additional fzf argument; repeatable. Values containing spaces are split into separate argv entries; prefer --fzf-arg=KEY=VALUE")


def files_from_options(
    args: argparse.Namespace,
    default_directory: Path,
    default_includes: list[str],
    allow_missing: bool = False,
) -> list[str]:
    directories = args.directories
    used_default = False
    if not args.files and not directories:
        directories = [str(default_directory)]
        used_default = True
    includes: list[str] = [] if args.no_default_includes else list(default_includes)
    for pattern in args.includes or []:
        if pattern.casefold() not in {existing.casefold() for existing in includes}:
            includes.append(pattern)
    if not includes:
        raise ValueError("--no-default-includes requires at least one --include GLOB")
    # A missing *explicit* -d is an error. The implicit default directory (and --add,
    # which is about to create it) are allowed not to exist yet.
    return discover_files(
        args.files, directories, includes, args.excludes,
        allow_missing=allow_missing or used_default,
    )


def _exclude_patterns(patterns: Iterable[str]) -> list[tuple[str, str]]:
    parsed: list[tuple[str, str]] = []
    for pattern in patterns:
        pattern = pattern.strip().casefold()
        if not pattern:
            continue
        if pattern.endswith("/"):
            parsed.append(("dir", pattern.rstrip("/")))
        elif any(char in pattern for char in GLOB_CHARS):
            parsed.append(("glob", pattern))
        else:
            parsed.append(("bare", pattern))
    return parsed


def excluded(path: str, patterns: Iterable[str]) -> bool:
    normalized = os.path.normpath(path).casefold().replace("\\", "/")
    basename = os.path.basename(normalized)
    segments = normalized.split("/")
    for kind, pattern in _exclude_patterns(patterns):
        if kind == "dir":
            if pattern in segments:
                return True
        elif kind == "glob":
            if fnmatch.fnmatch(basename, pattern):
                return True
        else:
            # A bare name means "this file, files starting with it, or a directory named it".
            if basename == pattern or fnmatch.fnmatch(basename, pattern + "*"):
                return True
            if pattern in segments[:-1]:
                return True
    return False


def directory_excluded(name: str, patterns: Iterable[str]) -> bool:
    name = name.casefold()
    for kind, pattern in _exclude_patterns(patterns):
        if kind in ("dir", "bare") and name == pattern:
            return True
        if kind == "glob" and fnmatch.fnmatch(name, pattern):
            return True
    return False


def included(name: str, patterns: Iterable[str]) -> bool:
    name = name.casefold()
    return any(fnmatch.fnmatch(name, pattern.casefold()) for pattern in patterns)


def discover_files(files: Iterable[str], directories: Iterable[str], includes: list[str], excludes: list[str], allow_missing: bool = False) -> list[str]:
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
        if excluded(path, excludes):
            continue
        add(path)
    for raw_directory in directories:
        directory = expand_path(raw_directory)
        if not os.path.isdir(directory):
            if allow_missing:
                continue
            raise FileNotFoundError(f"Input directory not found: {directory}")
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


def normalize_fzf_args(values: Iterable[str]) -> list[str]:
    """Split values containing spaces into separate argv entries (fzf wants argv, not a shell line)."""
    result: list[str] = []
    for value in values:
        if not value.strip():
            continue
        if any(char.isspace() for char in value):
            try:
                parts = shlex.split(value, posix=True)
            except ValueError:
                parts = value.split()
            result.extend(parts or [value])
        else:
            result.append(value)
    return result


def select(entries: list[Entry], args: argparse.Namespace, prompt: str) -> list[str]:
    if not entries:
        return []
    executable = os.environ.get("FZF_BIN", "fzf")
    if not shutil.which(executable):
        raise RuntimeError("fzf was not found; install fzf or set FZF_BIN")
    fzf_args = normalize_fzf_args(args.fzf_arg)
    fzf_has_multi = any(arg in ("--multi", "-m") or arg.startswith("--multi=") for arg in fzf_args)
    multi = bool(args.multi) or fzf_has_multi
    rows = ["\t".join((clean_field(entry.display), clean_field(entry.value))) for entry in entries]
    command = [
        executable,
        "--height=80%",
        "--layout=reverse",
        "-i",
        "--delimiter=\t",
        "--with-nth=1",
        f"--prompt={prompt}",
        "--header=Enter: select | Esc: quit" + (" | Tab: multi-select" if multi else ""),
        "--query=" + " ".join(args.query).strip(),
    ]
    if args.exact:
        command.append("--exact")
    if multi and not fzf_has_multi:
        command.append("--multi")
    if args.no_sort:
        command.append("--no-sort")
    command.extend(fzf_args)
    process = subprocess.run(
        command,
        input="\n".join(rows) + "\n",
        text=True,
        encoding="utf-8",
        errors="replace",
        capture_output=True,
    )
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


def _merge_windows_exe(parts: list[str]) -> list[str]:
    """Recover an unquoted Windows exe path containing spaces that shlex split apart."""
    for index in range(len(parts), 0, -1):
        candidate = " ".join(parts[:index])
        if os.path.isfile(candidate) or shutil.which(candidate):
            return [candidate] + parts[index:]
    return parts


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
    if os.name == "nt":
        parts = _merge_windows_exe(parts)
    parts[0] = expand_path(parts[0].strip('"'))
    return parts


def launch(command: list[str]) -> None:
    if not command:
        raise RuntimeError("The command is empty")
    executable = command[0]
    if not (os.path.isfile(executable) or shutil.which(executable)):
        raise RuntimeError(f"Executable not found: {executable}")
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


def _powershell_set_clipboard(text: str, executable: str) -> bool:
    """Send pure-ASCII base64 through argv so Unicode/newlines survive CP936 consoles."""
    payload = base64.b64encode(text.encode("utf-8")).decode("ascii")
    script = (
        "$t=[Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('" + payload + "'));"
        "Set-Clipboard -Value $t"
    )
    options: dict = {"check": True, "stdout": subprocess.DEVNULL, "stderr": subprocess.DEVNULL}
    if os.name == "nt":
        options["creationflags"] = getattr(subprocess, "CREATE_NO_WINDOW", 0)
    try:
        subprocess.run(
            [executable, "-NoProfile", "-NonInteractive", "-Command", script],
            **options,
        )
        return True
    except (OSError, subprocess.CalledProcessError):
        return False


def copy_clipboard(text: str) -> None:
    if os.name == "nt" and _powershell_set_clipboard(text, "powershell"):
        return
    if os.name != "nt" and shutil.which("powershell.exe") and _powershell_set_clipboard(text, "powershell.exe"):
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
            subprocess.run(
                command,
                input=text,
                text=True,
                encoding="utf-8",
                errors="replace",
                check=True,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
            )
            return
        except (OSError, subprocess.CalledProcessError):
            pass
    raise RuntimeError("No clipboard tool found; use PowerShell Set-Clipboard, clip, pbcopy, wl-copy, xclip, or xsel")


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
    """Write already-normalised text verbatim (newline="" avoids a second CRLF conversion)."""
    if content == original:
        return False
    backup = path + ".bak"
    try:
        with open(backup, "w", encoding="utf-8", newline="") as handle:
            handle.write(original)
        with open(path, "w", encoding="utf-8", newline="") as handle:
            handle.write(content)
    except OSError:
        try:
            shutil.copyfile(backup, path)
        except OSError as exc:
            raise RuntimeError(f"Failed to restore {path}: {exc}") from exc
        raise
    return True
