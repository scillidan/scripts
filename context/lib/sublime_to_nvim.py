# /// script
# requires-python = ">=3.9"
# ///
import argparse
import json
import os
import re
import xml.etree.ElementTree as ET

SCOPE_MAP = {
    "text.html": "html",
    "text.html.markdown": "markdown",
    "text.html.erb": "html",
    "text.xml": "xml",
    "text.plain": "plaintext",
    "text.tex": "latex",
    "text.tex.latex": "latex",
    "text.m3u": "plaintext",
    "text.css": "css",
    "text.css.less": "css",
    "text.css.scss": "css",
    "source.python": "python",
    "source.js": "javascript",
    "source.js.jsx": "javascript",
    "source.ts": "typescript",
    "source.tsx": "typescript",
    "source.go": "go",
    "source.rust": "rust",
    "source.ruby": "ruby",
    "source.shell": "shellscript",
    "source.shell.bash": "shellscript",
    "source.yaml": "yaml",
    "source.json": "json",
    "source.toml": "toml",
    "source.sql": "sql",
    "source.c": "c",
    "source.cpp": "cpp",
    "source.java": "java",
    "source.lua": "lua",
    "source.perl": "perl",
    "source.php": "php",
    "source.scss": "css",
    "source.less": "css",
    "source.css": "css",
    "source.r": "r",
    "source.dart": "dart",
    "source.swift": "swift",
    "source.kotlin": "kotlin",
    "text": None,
}


def map_scope(sublime_scope):
    if not sublime_scope:
        return None
    for scope_key, lang in SCOPE_MAP.items():
        if sublime_scope.startswith(scope_key):
            return lang
    first_scope = sublime_scope.split()[0] if sublime_scope.strip() else ""
    dot_parts = first_scope.split(".")
    if len(dot_parts) >= 2:
        candidate = dot_parts[-1]
        if candidate not in (
            "html",
            "xml",
            "plain",
            "css",
            "json",
            "yaml",
            "toml",
            "sql",
            "lua",
            "md",
        ):
            return candidate
    return None


def escape_json_string(s):
    s = s.replace("\\", "\\\\")
    s = s.replace('"', '\\"')
    s = s.replace("\n", "\\n")
    s = s.replace("\r", "")
    s = s.replace("\t", "\\t")
    return s


def parse_sublime_snippet(filepath):
    try:
        tree = ET.parse(filepath)
    except ET.ParseError as e:
        print(f"Error parsing XML: {e}")
        return None

    root = tree.getroot()
    if root.tag != "snippet":
        print(f"Error: Root element is '{root.tag}', expected 'snippet'")
        return None

    content_el = root.find("content")
    if content_el is None:
        print("Error: No <content> element found")
        return None

    raw_content = content_el.text or ""
    raw_content = raw_content.strip("\n")

    if raw_content.endswith("]]>"):
        raw_content = raw_content[:-3]
    if raw_content.startswith("<![CDATA["):
        raw_content = raw_content[9:]
    raw_content = raw_content.strip("\n")

    if raw_content.endswith("]]>"):
        raw_content = raw_content[:-3]
    raw_content = raw_content.strip("\n")

    tab_trigger_el = root.find("tabTrigger")
    prefix = (
        tab_trigger_el.text.strip()
        if tab_trigger_el is not None and tab_trigger_el.text
        else ""
    )

    description_el = root.find("description")
    description = (
        description_el.text.strip()
        if description_el is not None and description_el.text
        else ""
    )

    scope_el = root.find("scope")
    sublime_scope = (
        scope_el.text.strip() if scope_el is not None and scope_el.text else ""
    )
    vscode_lang = map_scope(sublime_scope)

    lines = raw_content.split("\n")

    snippet = {}
    snippet_key = prefix or os.path.splitext(os.path.basename(filepath))[0]
    snippet_key = re.sub(r"[^a-zA-Z0-9_]", "", snippet_key)
    if not snippet_key:
        snippet_key = "snippet"

    snippet["prefix"] = prefix
    snippet["body"] = lines
    if description:
        snippet["description"] = description
    if vscode_lang is not None:
        snippet["scope"] = vscode_lang

    return {snippet_key: snippet}


def convert_file(input_path, output_path):
    result = parse_sublime_snippet(input_path)
    if result is None:
        return False

    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(result, f, indent=2, ensure_ascii=False)

    return True


def main():
    parser = argparse.ArgumentParser(
        description="Convert Sublime Text snippet to VSCode/LuaSnip JSON"
    )
    parser.add_argument("input", help="Input .sublime-snippet file")
    parser.add_argument("output", help="Output .json file")
    args = parser.parse_args()

    if not os.path.isfile(args.input):
        print(f"Error: Input file '{args.input}' not found.")
        return 1

    if convert_file(args.input, args.output):
        return 0
    return 1


if __name__ == "__main__":
    exit(main())
