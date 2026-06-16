# /// script
# requires-python = ">=3.12"
# dependencies = [
#     "requests",
# ]
# ///

# llm_grammar - Local LLM grammar checker via llama.cpp server
# Inspired by https://ollama.com/gnokit/improve-grammar
# Authors: GLM-5.1🧙‍♂️, scillidan🤡
#
# Tested model: https://huggingface.co/gnokit/gemma_2b_coedit
#
# Usage:
#   # Check a single sentence with gemma-2b-coedit and default prompt
#   uv run llm_grammar.py --host http://127.0.0.1:8080 --model gemma-2b-coedit --original-text "The quikc brown fox jumps over the lazey dog"
#
#   # Use a custom prompt
#   uv run llm_grammar.py \
#     --host http://127.0.0.1:8080 \
#     --model gemma-2b-coedit \
#     --prompt "You are an editor. Fix grammar and spelling only, no extra comments." \
#     --input "She dont like apples."
#
#   # Read from stdin (pipe input)
#   echo "He go to school every day." | uv run llm_grammar.py --stdin
#   cat essay.txt | uv run llm_grammar.py --stdin --host http://localhost:8081


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
    "Fix grammar and spelling errors in the following text. "
    "Output ONLY the corrected text. "
    "No explanations. No comments. No repetitions. "
    "If the text is already correct, output it unchanged."
)


def main():
    parser = argparse.ArgumentParser(
        description="Grammar check text using local LLM (llama.cpp server)."
    )
    add_common_cli(parser)
    parser.add_argument("--model", type=str, default=None, help="Model name sent to server (optional)")
    parser.add_argument("--prompt", type=str, default=DEFAULT_PROMPT, help="Custom system prompt for grammar checking")
    parser.add_argument("--original-text", action="store_true", help="Append original text")
    parser.add_argument("--html", action="store_true", help="Output in HTML format")
    parser.add_argument("text", nargs="*", default="", help="Input text to check")

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
            print("Error: No input text provided", file=sys.stderr)
        sys.exit(1)

    text = normalize_text(input_text)
    if not text:
        if not args.silent:
            print("Error: Input text cannot be empty", file=sys.stderr)
        sys.exit(1)

    if args.debug:
        print(f"Host: {args.host}", file=sys.stderr)
        print(f"Model: {args.model}", file=sys.stderr)
        print(f"Input length: {len(text)}", file=sys.stderr)

    try:
        corrected = call_llamacpp(text, args.model, args.host, args.timeout, system_prompt=args.prompt, temperature=0.1)
    except Exception as e:
        handle_llm_error(e, args.silent, host=args.host)
        sys.exit(1)

    if args.html:
        output = format_html(corrected, original=text if args.original_text else None)
    else:
        output = corrected
        if args.original_text:
            output += f"\n{text}"

    emit(output)


if __name__ == "__main__":
    main()
