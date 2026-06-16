# /// script
# requires-python = ">=3.12"
# dependencies = [
#     "requests",
# ]
# ///

# llm_abbr - Local LLM abbreviation generator via llama.cpp server
# Authors: GLM-5.1🧙‍♂️, scillidan🤡
#
# Tested models: https://huggingface.co/unsloth/gemma-3-4b-it-qat-GGUF
#
# Usage:
#   # Get abbreviation for a word or phrase
#   uv run llm_abbr.py --host http://127.0.0.1:8080 --model gemma-3-4b-it-qat "abbreviation"
#   uv run llm_abbr.py --host http://127.0.0.1:8080 --model gemma-3-4b-it-qat "application programming interface"
#
#   # Read from stdin (pipe input, one word/phrase per line)
#   echo "configuration" | uv run llm_abbr.py --stdin
#   cat terms.txt | uv run llm_abbr.py --stdin --host http://localhost:8080
#
#   # With cache (persist LLM results for reuse)
#   uv run llm_abbr.py --host http://127.0.0.1:8080 --model gemma-3-4b-it-qat --input "abbreviation" --save-cache
#
#   # With user abbreviation table (--include entries take priority over cache and LLM)
#   uv run llm_abbr.py --host http://127.0.0.1:8080 --model gemma-3-4b-it-qat --input "provider" --include my_abbr.txt


import argparse
import os
import sys
from pathlib import Path
from typing import Optional

from llm_utils.llm_common import (
    add_common_cli,
    call_llamacpp,
    emit,
    format_html,
    handle_llm_error,
    normalize_text,
    read_stdin,
)


DEFAULT_ABBR_PROMPT = (
    "Return the common English abbreviation for the given word or phrase. "
    "Output ONLY the abbreviation in lowercase. "
    "No explanations. No punctuation. No extra words."
)

CACHE_FILE = "data/abbr_cache.txt"


def parse_pipe_table(filepath: str) -> dict:
    table = {}
    resolved = os.path.expanduser(filepath)
    if not os.path.isabs(resolved):
        resolved = os.path.join(os.getcwd(), resolved)
    if not os.path.exists(resolved):
        print(f"Warning: Include file not found: {filepath}", file=sys.stderr)
        return table
    with open(resolved, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            if "|" in line:
                parts = line.split("|", 1)
                key = parts[0].strip().lower()
                value = parts[1].strip().lower()
                if key and value:
                    table[key] = value
    return table


def save_to_cache(filepath: str, key: str, value: str):
    os.makedirs(os.path.dirname(filepath), exist_ok=True)
    with open(filepath, "a", encoding="utf-8") as f:
        f.write(f"{key} | {value}\n")


def main():
    parser = argparse.ArgumentParser(
        description="Get abbreviation for words/phrases using local LLM with optional table caching."
    )
    add_common_cli(parser)
    parser.add_argument("--model", type=str, default=None, help="Model name sent to server (optional)")
    parser.add_argument("text", nargs="*", default="", help="Word or phrase to abbreviate")
    parser.add_argument("--original-text", action="store_true", help="Append original text")
    parser.add_argument("--html", action="store_true", help="Output in HTML format")
    parser.add_argument("--save-cache", action="store_true", help="Save LLM results to cache file for reuse")
    parser.add_argument("--include", type=str, action="append", default=None,
        help="User abbreviation table file, repeatable (pipe-delimited, priority over cache and LLM)")
    parser.add_argument("--cache-file", type=str, default=None,
        help=f"Cache file path (default: <script_dir>/{CACHE_FILE})")

    args = parser.parse_args()

    if not args.stdin and not args.text:
        if not args.silent:
            print("Error: No input provided", file=sys.stderr)
        sys.exit(1)

    cache_path = args.cache_file or str(Path(__file__).parent / CACHE_FILE)

    include_table = {}
    if args.include:
        for fpath in args.include:
            include_table.update(parse_pipe_table(fpath))

    cache_table = {}
    if args.save_cache:
        cache_table = parse_pipe_table(cache_path)

    if args.debug:
        print(f"Include files: {args.include}", file=sys.stderr)
        print(f"Include entries: {len(include_table)}", file=sys.stderr)
        print(f"Save cache: {args.save_cache}", file=sys.stderr)
        if args.save_cache:
            print(f"Cache file: {cache_path}", file=sys.stderr)
            print(f"Cache entries: {len(cache_table)}", file=sys.stderr)

    inputs = []
    if args.stdin:
        stdin_text = read_stdin(args.silent)
        inputs = [line for line in stdin_text.split("\n") if line.strip()]
    else:
        inputs = [" ".join(args.text)]

    abbreviations = []
    originals = []

    for input_text in inputs:
        normalized = normalize_text(input_text, casefold=True)
        if not normalized:
            continue

        abbr = None

        if normalized in include_table:
            abbr = include_table[normalized]
        elif args.save_cache and normalized in cache_table:
            abbr = cache_table[normalized]

        if not abbr:
            if args.debug:
                print(f"Asking LLM: '{normalized}'", file=sys.stderr)
            try:
                abbr = call_llamacpp(
                    normalized, args.model, args.host, args.timeout,
                    system_prompt=DEFAULT_ABBR_PROMPT,
                    temperature=0.1,
                    max_tokens=50,
                )
            except Exception as e:
                handle_llm_error(e, args.silent, host=args.host)
                sys.exit(1)

            abbr = abbr.strip("\"'.,;: ").lower()

            if abbr and args.save_cache:
                save_to_cache(cache_path, normalized, abbr)
                cache_table[normalized] = abbr

        if abbr:
            abbreviations.append(abbr)
            originals.append(input_text)
        else:
            if not args.silent:
                print(f"Warning: No abbreviation generated for '{input_text}'", file=sys.stderr)

    if not abbreviations:
        sys.exit(1)

    abbr_text = "\n".join(abbreviations)
    orig_text = "\n".join(originals)

    if args.html:
        output = format_html(abbr_text, original=orig_text if args.original_text else None)
    else:
        output = abbr_text
        if args.original_text:
            output += f"\n{orig_text}"

    emit(output)


if __name__ == "__main__":
    main()
