# /// script
# requires-python = ">=3.12"
# dependencies = [
#     "requests",
# ]
# ///

# llm_explain - Explain concepts in simple terms via llama.cpp server
# Refer to https://hub.anythingllm.com/i/slash-command/FeHxRthrf5kmUaS6ZzZg
# Authors: GLM-5.1🧙‍♂️, scillidan🤡
#
# Tested model: gemma-3-4b-it-qat
#
# Usage:
#   uv run llm_explain.py --host http://127.0.0.1:8080 "recursion"
#   echo "closures in JavaScript" | uv run llm_explain.py --stdin


import argparse
import sys

from llm_utils.llm_common import (
    add_common_cli,
    call_llamacpp,
    emit,
    format_html,
    handle_llm_error,
    normalize_text,
    read_stdin,
)


DEFAULT_PROMPT = (
    "Explain the following concept in very simple terms for a beginner who is not a native English speaker. "
    "Use short sentences and everyday words. Give a real-world example or analogy. "
    "Avoid technical jargon. Output ONLY the explanation."
)

DEFAULT_MODEL = "gemma-3-4b-it-qat"


def main():
    parser = argparse.ArgumentParser(
        description="Explain concepts in simple terms using local LLM."
    )
    add_common_cli(parser)
    parser.add_argument("--model", type=str, default=DEFAULT_MODEL, help=f"Model name (default: {DEFAULT_MODEL})")
    parser.add_argument("--original-text", action="store_true", help="Append original text")
    parser.add_argument("--html", action="store_true", help="Output in HTML format")
    parser.add_argument("text", nargs="*", default="", help="Concept to explain")

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
            temperature=0.4,
        )
    except Exception as e:
        handle_llm_error(e, args.silent, host=args.host)
        sys.exit(1)

    if args.html:
        output = format_html(result, original=text if args.original_text else None)
    else:
        output = result
        if args.original_text:
            output += f"\n{text}"

    emit(output)


if __name__ == "__main__":
    main()
