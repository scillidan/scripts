# /// script
# requires-python = ">=3.12"
# dependencies = [
#     "requests",
# ]
# ///

# llm_grammar - Local LLM grammar checker via llama.cpp server
# Inspired by https://ollama.com/gnokit/improve-grammar
# Authors: Hy3-preview🧙‍♂️, scillidan🤡
#
# Tested model: https://huggingface.co/gnokit/gemma_2b_coedit
#
# Usage:
#   # Check a single sentence with gemma-2b-coedit and default prompt
#   uv run llm_grammar.py --host http://127.0.0.1:8080 --model gemma-2b-coedit --input --original-text "The quikc brown fox jumps over the lazey dog"
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
#
# Changelog:
# - v2: Align style with llm_trans.py. Add PEP 723 metadata. Split logic into functions.
#       Improve error handling and encoding safety. Remove hardcoded endpoint fallback.
# - v1: Initial grammar checker for llama.cpp server.


import argparse
import json
import sys
import io
import unicodedata
from typing import Optional

import requests


sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")


BAD_CHARS = [
    "\x00", "\x01", "\x02", "\x03", "\x04", "\x05", "\x06", "\x07",
    "\x08", "\x0b", "\x0c", "\x0e", "\x0f",
    "\u200b", "\u200c", "\u200d", "\ufeff",
]


DEFAULT_PROMPT = (
    "You are a professional English teacher. "
    "Perform spell check and improve grammar if necessary. "
    "Fix grammar in the following text:"
)


def clean_surrogates(text: str) -> str:
    if not text:
        return ""
    return "".join(c for c in text if not ("\ud800" <= c <= "\udfff"))


def normalize_text(text: str) -> str:
    if not text:
        return ""
    text = clean_surrogates(text)
    try:
        text = unicodedata.normalize("NFKC", text)
    except Exception:
        pass
    for ch in BAD_CHARS:
        text = text.replace(ch, "")
    return text.strip()


def safe_json_dumps(obj: dict, ensure_ascii: bool = False) -> str:
    try:
        s = json.dumps(obj, ensure_ascii=ensure_ascii)
    except UnicodeEncodeError:
        s = json.dumps(obj, ensure_ascii=True)
    return clean_surrogates(s)


def read_input_with_encoding(fileobj) -> str:
    try:
        return fileobj.buffer.read().decode("utf-8")
    except UnicodeDecodeError:
        try:
            fileobj.buffer.seek(0)
            bom = fileobj.buffer.read(2)
            fileobj.buffer.seek(0)
            if bom in (b"\xff\xfe", b"\xfe\xff"):
                return fileobj.buffer.read().decode("utf-16")
            try:
                fileobj.buffer.seek(0)
                return fileobj.buffer.read().decode("utf-16-le")
            except Exception:
                fileobj.buffer.seek(0)
                return fileobj.buffer.read().decode("utf-16-be")
        except Exception:
            fileobj.buffer.seek(0)
            return fileobj.buffer.read().decode("latin-1", errors="replace")


def call_llamacpp(
    prompt: str,
    model: Optional[str],
    host: str,
    timeout: int
) -> str:
    url = f"{host.rstrip('/')}/v1/chat/completions"
    payload = {
        "messages": [
            {"role": "system", "content": DEFAULT_PROMPT},
            {"role": "user", "content": prompt}
        ],
        "temperature": 0.3,
        "max_tokens": 512,
        "stream": False,
    }
    if model:
        payload["model"] = model

    body = safe_json_dumps(payload).encode("utf-8", errors="replace")
    resp = requests.post(
        url,
        headers={"Content-Type": "application/json; charset=utf-8"},
        data=body,
        timeout=timeout,
    )
    resp.raise_for_status()

    data = resp.json()
    return data["choices"][0]["message"]["content"].strip()


def format_html(corrected: str, original: Optional[str] = None) -> str:
    lines = corrected.split("\n")
    parts = ['<div style="margin: 0; padding: 0;">']
    for i, line in enumerate(lines):
        if line.strip():
            parts.append(f'<p style="margin: 0; padding: 0">{line}</p>')
        elif i < len(lines) - 1:
            parts.append('<p style="margin: 0; padding: 0">&nbsp;</p>')
    parts.append("</div>")

    if original:
        orig_lines = original.split("\n")
        parts.append('<div style="margin: 0; padding: 0;">')
        for i, line in enumerate(orig_lines):
            if line.strip():
                parts.append(f'<p style="margin: 0; padding: 0; color: #666">{line}</p>')
            elif i < len(orig_lines) - 1:
                parts.append('<p style="margin: 0; padding: 0">&nbsp;</p>')
        parts.append("</div>")

    return "".join(parts)


def emit(text: str, utf16: bool = False):
    if utf16:
        sys.stdout.buffer.write(text.encode("utf-16", errors="replace"))
        sys.stdout.buffer.flush()
    else:
        print(text)


def main():
    parser = argparse.ArgumentParser(
        description="Grammar check text using local LLM (llama.cpp server)."
    )
    parser.add_argument(
        "--host",
        type=str,
        required=True,
        help="llama.cpp server host, e.g. http://127.0.0.1:8080",
    )
    parser.add_argument(
        "--model",
        type=str,
        default=None,
        help="Model name sent to server (optional)",
    )
    parser.add_argument(
        "--prompt",
        type=str,
        default=DEFAULT_PROMPT,
        help="Custom system prompt for grammar checking",
    )
    parser.add_argument(
        "--timeout",
        type=int,
        default=30,
        help="Request timeout in seconds",
    )
    parser.add_argument(
        "--original-text",
        action="store_true",
        help="Append original text",
    )
    parser.add_argument(
        "--html",
        action="store_true",
        help="Output in HTML format",
    )
    parser.add_argument(
        "--stdin",
        action="store_true",
        help="Read input from stdin",
    )
    parser.add_argument(
        "--debug",
        action="store_true",
        help="Show debug info on stderr",
    )
    parser.add_argument(
        "--silent",
        action="store_true",
        help="Suppress error messages",
    )
    parser.add_argument(
        "text",
        nargs="*",
        default="",
        help="Input text to check",
    )

    args = parser.parse_args()

    if args.stdin and args.text:
        if not args.silent:
            print("Error: Cannot use both stdin and text argument", file=sys.stderr)
        sys.exit(1)

    if args.stdin:
        if sys.stdin.isatty():
            if not args.silent:
                print("Error: No input piped to stdin", file=sys.stderr)
            sys.exit(1)
        input_text = read_input_with_encoding(sys.stdin).rstrip("\r\n")
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
        corrected = call_llamacpp(text, args.model, args.host, args.timeout)
    except requests.exceptions.ConnectionError:
        if not args.silent:
            print(f"❌ Error: Could not connect to llama.cpp server at {args.host}", file=sys.stderr)
            print("   Make sure the server is running (e.g., `./llama-server -m your_model.gguf`)", file=sys.stderr)
        sys.exit(1)
    except requests.exceptions.HTTPError as e:
        if not args.silent:
            print(f"❌ HTTP Error: {e}", file=sys.stderr)
        sys.exit(1)
    except KeyError:
        if not args.silent:
            print("❌ Error: Unexpected response format from server", file=sys.stderr)
            print("   Ensure you're using llama.cpp server with /v1/chat/completions support", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        if not args.silent:
            print(f"❌ Error: {e}", file=sys.stderr)
        sys.exit(1)

    if args.html:
        output = format_html(
            corrected,
            original=text if args.original_text else None
        )
    else:
        output = corrected
        if args.original_text:
            output += f"\n{text}"

    emit(output)


if __name__ == "__main__":
    main()