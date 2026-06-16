# /// script
# requires-python = ">=3.12"
# dependencies = [
#     "requests",
# ]
# ///

# llm_lambda_replace - Convert string replacement examples into Python lambda expressions via llama.cpp server
# Authors: GLM-5.1🧙‍♂️, scillidan🤡
#
# Tested model: gemma-3-4b-it-qat
#
# Usage:
#   uv run llm_lambda_replace.py --host http://127.0.0.1:8080 "change 'foo' to 'bar'"
#   echo "replace hello with world" | uv run llm_lambda_replace.py --stdin


import argparse
import sys

from llm_utils.llm_common import (
    add_common_cli,
    call_llamacpp,
    emit,
    handle_llm_error,
    normalize_text,
    read_stdin,
)


DEFAULT_PROMPT = (
    "You convert string replacement examples into Python lambda expressions.\n"
    "\n"
    "Input: an EXAMPLE string containing `<var>` placeholders — not literal text; infer the pattern.\n"
    "Output: ONLY a single `lambda x: x.replace(...)` expression. No explanation. No backticks.\n"
    "\n"
    "Example input: -change 'foo' to 'bar'\n"
    "Example output: lambda x: x.replace('foo', 'bar')\n"
    "\n"
    "Input:"
)

DEFAULT_MODEL = "gemma-3-4b-it-qat"


def main():
    parser = argparse.ArgumentParser(
        description="Convert string replacement examples into lambda replace expressions."
    )
    add_common_cli(parser)
    parser.add_argument("--model", type=str, default=DEFAULT_MODEL, help=f"Model name (default: {DEFAULT_MODEL})")
    parser.add_argument("text", nargs="*", default="", help="Input example string")

    args = parser.parse_args()

    if args.stdin and args.text:
        if not args.silent:
            print("Error: Cannot use both stdin and text argument", file=sys.stderr)
        sys.exit(1)

    if args.stdin:
        input_text = read_stdin(args.silent)
    elif args.text:
        input_text = " ".join(args.text)
    else:
        if not args.silent:
            print("Error: No input provided", file=sys.stderr)
        sys.exit(1)

    text = normalize_text(input_text)
    if not text:
        if not args.silent:
            print("Error: Input cannot be empty", file=sys.stderr)
        sys.exit(1)

    if args.debug:
        print(f"Host: {args.host}", file=sys.stderr)
        print(f"Model: {args.model}", file=sys.stderr)
        print(f"Input: {text}", file=sys.stderr)

    try:
        result = call_llamacpp(
            text, args.model, args.host, args.timeout,
            system_prompt=DEFAULT_PROMPT,
            temperature=0.1,
            max_tokens=100,
        )
    except Exception as e:
        handle_llm_error(e, args.silent, host=args.host)
        sys.exit(1)

    result = result.strip().strip("` ")
    emit(result)


if __name__ == "__main__":
    main()
