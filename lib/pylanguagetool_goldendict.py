# /// script
# requires-python = ">=3.12"
# dependencies = [
#     "pyperclip",
# ]
# ///

# pylanguagetool_goldendict - LanguageTool API wrapper for GoldenDict
# Derived from pylanguagetool (https://pylanguagetool.lw1.at/)
# Authors: GLM-5.1🧙‍♂️, scillidan🤡
#
# Usage:
#   # Plain text (no color)
#   uv run pylanguagetool_goldendict.py --api-url "http://localhost:8040/v2/" --lang en-US "The quikc brown fox"
#
#   # ANSI colored (for terminal)
#   uv run pylanguagetool_goldendict.py --api-url "http://localhost:8040/v2/" --lang en-US --ansi "The quikc brown fox"
#
#   # HTML colored (for GoldenDict, requires monospace font)
#   uv run pylanguagetool_goldendict.py --api-url "http://localhost:8040/v2/" --lang en-US --html "The quikc brown fox"
#
#   # Clipboard input
#   uv run pylanguagetool_goldendict.py --api-url "http://localhost:8040/v2/" --lang en-US --clipboard --html
#
#   # Read from stdin
#   echo "The quikc brown fox" | uv run pylanguagetool_goldendict.py --api-url "http://localhost:8040/v2/" --lang en-US --html
#
# Changelog:
# - v2: Direct API calls instead of wrapping pylanguagetool CLI (colorama
#   strips ANSI in non-TTY pipes on Windows). Add --ansi, --clipboard.
# - v1: Initial wrapper around pylanguagetool CLI.

import argparse
import html
import json
import os
import sys
import urllib.parse
import urllib.request

os.environ["PYTHONUTF8"] = "1"
sys.stdout.reconfigure(encoding="utf-8", errors="replace")
sys.stderr.reconfigure(encoding="utf-8", errors="replace")

import pyperclip


def lt_check(text, api_url, lang, **kwargs):
    data = {"text": text, "language": lang}
    for key in (
        "mother_tongue", "preferred_variants", "enabled_rules",
        "disabled_rules", "enabled_categories", "disabled_categories",
    ):
        if key in kwargs and kwargs[key]:
            data[key] = kwargs[key]
    if kwargs.get("enabled_only"):
        data["enabledOnly"] = "true"
    if kwargs.get("picky"):
        data["picky"] = "true"
    encoded = urllib.parse.urlencode(data).encode("utf-8")
    req = urllib.request.Request(api_url, data=encoded)
    with urllib.request.urlopen(req) as resp:
        return json.loads(resp.read().decode("utf-8"))


def _render_error_blocks(response):
    matches = response.get("matches", [])
    if not matches:
        return []

    blocks = []
    for error in matches:
        ctx = error["context"]
        text = ctx["text"]
        offset = ctx["offset"]
        length = ctx["length"]
        end = offset + length

        bad = text[offset:end]
        before = text[:offset]
        after = text[end:]
        replacements = [r["value"] for r in error.get("replacements", [])[:5]]

        blocks.append((before, bad, after, offset, length, replacements))
    return blocks


def format_html(response):
    parts: list[str] = []
    blocks = _render_error_blocks(response)
    if not blocks:
        parts.append('<span style="color:green;font-weight:bold">\u2713</span> No errors found.')
        return "<br>".join(parts)

    for before, bad, after, offset, length, replacements in blocks:
        b_esc = html.escape(before)
        bad_esc = html.escape(bad)
        a_esc = html.escape(after)

        line = (
            f'<span style="color:red;font-weight:bold">\u2717</span> '
            f'{b_esc}<span style="color:red;font-weight:bold">{bad_esc}</span>{a_esc}'
        )
        caret = "&nbsp;" * (offset + 2) + '<span style="color:red;font-weight:bold">' + "^" * length + "</span>"

        parts.append(line)
        parts.append(caret)

        for rv in replacements:
            rv_esc = html.escape(rv)
            good_line = (
                f'<span style="color:green;font-weight:bold">\u2713</span> '
                f'{b_esc}<span style="color:green;font-weight:bold">{rv_esc}</span>{a_esc}'
            )
            parts.append(good_line)

        parts.append("")

    return "<br>".join(parts)


def format_ansi(response):
    R = "\033[91m"
    G = "\033[92m"
    B = "\033[1m"
    X = "\033[0m"

    lines: list[str] = []
    blocks = _render_error_blocks(response)
    if not blocks:
        lines.append(f"{G}{B}\u2713{X} No errors found.")
        return "\n".join(lines)

    for before, bad, after, offset, length, replacements in blocks:
        line = f"{R}{B}\u2717{X} {before}{R}{B}{bad}{X}{after}"
        caret = " " * (offset + 2) + f"{R}{B}" + "^" * length + X
        lines.append(line)
        lines.append(caret)

        for rv in replacements:
            good_line = f"{G}{B}\u2713{X} {before}{G}{B}{rv}{X}{after}"
            lines.append(good_line)

        lines.append("")

    return "\n".join(lines).strip()


def format_plain(response):
    lines: list[str] = []
    blocks = _render_error_blocks(response)
    if not blocks:
        lines.append("\u2713 No errors found.")
        return "\n".join(lines)

    for before, bad, after, offset, length, replacements in blocks:
        line = f"\u2717 {before}{bad}{after}"
        caret = " " * (offset + 2) + "^" * length
        lines.append(line)
        lines.append(caret)

        for rv in replacements:
            lines.append(f"\u2713 {before}{rv}{after}")

        lines.append("")

    return "\n".join(lines).strip()


def main() -> None:
    parser = argparse.ArgumentParser(description="LanguageTool API wrapper for GoldenDict")
    parser.add_argument("--api-url", required=True,
                        help="LanguageTool API URL, e.g. http://localhost:8040/v2/")
    parser.add_argument("--lang", required=True)
    parser.add_argument("--html", action="store_true",
                        help="Output colored HTML (for GoldenDict, requires monospace font)")
    parser.add_argument("--ansi", action="store_true",
                        help="Output ANSI colored text (for terminal)")
    parser.add_argument("--clipboard", action="store_true",
                        help="Read input from system clipboard")
    parser.add_argument("--mother-tongue", default=None)
    parser.add_argument("--preferred-variants", default=None)
    parser.add_argument("--enabled-rules", default=None)
    parser.add_argument("--disabled-rules", default=None)
    parser.add_argument("--enabled-categories", default=None)
    parser.add_argument("--disabled-categories", default=None)
    parser.add_argument("--enabled-only", action="store_true")
    parser.add_argument("--picky", action="store_true")
    parser.add_argument("text", nargs="*",
                        help="Text to check (reads from stdin if not provided)")
    args = parser.parse_args()

    if args.clipboard:
        try:
            input_text = pyperclip.paste().strip()
        except pyperclip.PyperclipException as e:
            print(f"Clipboard error: {e}", file=sys.stderr)
            sys.exit(1)
    elif args.text:
        input_text = " ".join(args.text).strip()
    else:
        input_text = sys.stdin.read().strip()

    if not input_text:
        print("No input text provided.", file=sys.stderr)
        sys.exit(1)

    api_url = args.api_url.rstrip("/")
    if not api_url.endswith("/check"):
        api_url += "/check"

    response = lt_check(
        input_text,
        api_url,
        args.lang,
        mother_tongue=args.mother_tongue,
        preferred_variants=args.preferred_variants,
        enabled_rules=args.enabled_rules,
        disabled_rules=args.disabled_rules,
        enabled_categories=args.enabled_categories,
        disabled_categories=args.disabled_categories,
        enabled_only=args.enabled_only,
        picky=args.picky,
    )

    if args.html:
        print(format_html(response))
    elif args.ansi:
        print(format_ansi(response))
    else:
        print(format_plain(response))


if __name__ == "__main__":
    main()
