# /// script
# requires-python = ">=3.12"
# dependencies = [
#     "requests",
#     "langdetect",
#     "iso639-lang"
# ]
# ///

# llm_trans - Local LLM translator via llama.cpp server
# Inspired by https://ollama.com/zongwei/gemma3-translator:4b
# Authors: GLM-5.1🧙‍♂️, scillidan🤡
#
# Tested models:
#   https://huggingface.co/unsloth/gemma-3-4b-it-qat-GGUF
#   https://huggingface.co/unsloth/gemma-3-12b-it-GGUF
#
# Usage:
#   # Auto mode (detect language, match direction rules)
#   uv run llm_trans.py --host http://127.0.0.1:8080 --model gemma-3-4b-it-qat --input English --output Chinese --prompt quick --original-text "Alice was beginning to get very tired of sitting by her sister on the bank, and of having nothing to do: once or twice she had peeped into the book her sister was reading, but it had no pictures or conversations in it, “and what is the use of a book,” thought Alice “without pictures or conversations?”"
#   uv run llm_trans.py --host http://127.0.0.1:8080 --model gemma-3-12b-it --input English --output Chinese --prompt serious --original-text "Alice was beginning to get very tired of sitting by her sister on the bank, and of having nothing to do: once or twice she had peeped into the book her sister was reading, but it had no pictures or conversations in it, “and what is the use of a book,” thought Alice “without pictures or conversations?”"
#   uv run llm_trans.py --host http://127.0.0.1:8080 --model gemma-3-4b-it-qat --auto-mode all2zh-cn --auto-mode zh-cn2en "The quick brown fox jumps over the lazy dog."
#   uv run llm_trans.py --host http://127.0.0.1:8080 --model gemma-3-4b-it-qat --auto-mode all2zh-cn --auto-mode zh-cn2en "敏捷的棕色狐狸跳过懒惰的狗。"
#   echo "..." | uv run llm_trans.py ... --stdin
#   cat file.txt | uv run llm_trans.py ... --stdin
#
# Changelog:
# - v5: Replace --input-out with --auto-mode (no defaults) and --input/--output
#   for explicit direction. Mutually exclusive.
# - v4: Parameterize translation direction via --auto-mode (e.g. all2zh-cn zh-cn2en).
#   Remove hardcoded zh↔en logic. Use iso639-lang for language labels.
# - v3: Inline two prompt presets (quick/serious), remove external prompts/ dir.
# - v2: Remove Ollama support. Ollama's native API (/api/generate, /api/chat) is
#   unstable across versions — models that worked with /api/generate suddenly break
#   on newer Ollama, and /api/chat fails for some models too. llama.cpp server
#   provides a stable OpenAI-compatible /v1/chat/completions endpoint, making it
#   the only supported backend now. If you need Ollama, use the legacy
#   ollama_trans_zh.py / ollama_trans_gemma3_zh.py.
# - v1: Initial unified translator (Ollama + llama.cpp).


import requests
import json
import argparse
import re
import sys
import io
import unicodedata

from langdetect import detect, DetectorFactory
from iso639 import Lang

DetectorFactory.seed = 0
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")


def lang_label(code):
    base = code.split("-")[0].lower()
    try:
        return Lang(base).name
    except Exception:
        return code


def lang_to_code(token):
    t = token.strip().lower()
    if "-" in t:
        base = t.split("-")[0]
    else:
        base = t
    try:
        Lang(base)
        return t
    except Exception:
        pass
    try:
        return Lang(token.strip()).pt1
    except Exception:
        return t


PROMPTS = {
    "quick": (
        "You are a translation engine.\n"
        "Input: text in {src_lang}\n"
        "Output: text in {tgt_lang}\n"
        "No explanation. No formatting. No extra words.\n"
        "\n{src_lang}: {text}\n{tgt_lang}:"
    ),
    "serious": (
        "You are a professional translator.\n"
        "Only output the translated text.\n"
        "Do NOT explain.\n"
        "Do NOT add notes.\n"
        "Do NOT reply conversationally.\n"
        "\nTranslate from {src_lang} to {tgt_lang}:\n\n{text}"
    ),
}

BAD_CHARS = [
    "\x00", "\x01", "\x02", "\x03", "\x04", "\x05", "\x06", "\x07",
    "\x08", "\x0b", "\x0c", "\x0e", "\x0f",
    "\u200b", "\u200c", "\u200d", "\ufeff",
]


def clean_surrogates(text):
    if not text:
        return ""
    return "".join(c for c in text if not ("\ud800" <= c <= "\udfff"))


def normalize_text(text):
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


def safe_json_dumps(obj, ensure_ascii=False):
    try:
        s = json.dumps(obj, ensure_ascii=ensure_ascii)
    except UnicodeEncodeError:
        s = json.dumps(obj, ensure_ascii=True)
    return clean_surrogates(s)


def is_chinese(text):
    return any("\u4e00" <= c <= "\u9fff" for c in text)


def base_lang(code):
    return code.split("-")[0].lower()


def detect_lang(text):
    if is_chinese(text):
        return "zh"
    try:
        return detect(text)
    except Exception:
        return "en"


def parse_direction(spec):
    parts = spec.split("2", 1)
    if len(parts) != 2 or not parts[0] or not parts[1]:
        raise ValueError(f"Invalid direction: {spec} (expected SRC2TGT, e.g. all2zh-cn)")
    return parts[0].lower(), parts[1].lower()


def resolve_direction(text, directions):
    detected = detect_lang(text)
    detected_base = base_lang(detected)
    for src_spec, tgt in directions:
        if src_spec == "all":
            if detected_base != base_lang(tgt):
                return detected, tgt
        elif base_lang(src_spec) == detected_base:
            return detected, tgt
    return None


def read_input_with_encoding(fileobj):
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


JSON_TRANS_KEYS = ("translation", "chinese", "english", "trans")


def postprocess(raw):
    text = raw.strip().rstrip("\n").strip()
    json_match = re.search(r"\{.*\}", text, re.DOTALL)
    if json_match:
        try:
            obj = json.loads(json_match.group(0))
            for k in JSON_TRANS_KEYS:
                if k in obj and isinstance(obj[k], str):
                    return obj[k].strip()
        except json.JSONDecodeError:
            pass
    return text


def build_prompt(text, src, tgt, template):
    return template.replace("{src_lang}", lang_label(src)).replace("{tgt_lang}", lang_label(tgt)).replace("{text}", text)


def call_llamacpp(prompt, model, host, timeout):
    url = f"{host}/v1/chat/completions"
    payload = {
        "model": model,
        "messages": [{"role": "user", "content": prompt}],
        "temperature": 0.2,
        "max_tokens": 512,
        "stream": False,
    }
    body = safe_json_dumps(payload).encode("utf-8", errors="replace")
    resp = requests.post(
        url,
        headers={"Content-Type": "application/json; charset=utf-8"},
        data=body,
        timeout=timeout,
    )
    resp.raise_for_status()
    choices = resp.json().get("choices", [])
    if choices:
        return choices[0].get("message", {}).get("content", "").strip()
    return ""


def translate_line(text, model, host, prompt_template, src, tgt, timeout):
    norm = normalize_text(text)
    if not norm:
        return text
    prompt = build_prompt(norm, src, tgt, prompt_template)
    raw = call_llamacpp(prompt, model, host, timeout)
    translated = postprocess(raw)
    return normalize_text(translated) if translated else norm


def translate_multiline(text, model, host, prompt_template, src, tgt, timeout):
    if not text:
        return ""
    lines = text.split("\n")
    results = []
    for line in lines:
        if line.strip():
            results.append(translate_line(line, model, host, prompt_template, src, tgt, timeout))
        else:
            results.append("")
    return "\n".join(results)


def format_html(translated, original=None):
    lines = translated.split("\n")
    parts = ['<div style="margin: 0; padding: 0;">']
    for i, line in enumerate(lines):
        if line.strip():
            parts.append(f'<p style="margin: 0; padding: 0">{line}</p>')
        elif i < len(lines) - 1:
            parts.append('<p style="margin: 0; padding: 0">&nbsp;</p>')
    parts.append("</div>")
    if original:
        src_lines = original.split("\n")
        parts.append('<div style="margin: 0; padding: 0;">')
        for i, line in enumerate(src_lines):
            if line.strip():
                parts.append(f'<p style="margin: 0; padding: 0">{line}</p>')
            elif i < len(src_lines) - 1:
                parts.append('<p style="margin: 0; padding: 0">&nbsp;</p>')
        parts.append("</div>")
    return "".join(parts)


def emit(text):
    print(text)


def main():
    parser = argparse.ArgumentParser(description="Translate text using local LLM (llama.cpp server).")
    grp = parser.add_mutually_exclusive_group()
    grp.add_argument("--auto-mode", type=str, action="append", default=None,
        help="Auto-detect direction rule, repeatable, e.g. --auto-mode all2zh-cn --auto-mode zh-cn2en")
    grp.add_argument("--input", type=str, default=None,
        help="Source language (ISO code or English name, e.g. en or English)")
    parser.add_argument("--output", type=str, default=None,
        help="Target language (ISO code or English name, e.g. zh or Chinese); required with --input")
    parser.add_argument("--host", type=str, required=True, help="llama.cpp server host, e.g. http://127.0.0.1:8080")
    parser.add_argument("--model", type=str, required=True, help="Model name sent to server")
    parser.add_argument("--prompt", type=str, default="quick", choices=list(PROMPTS.keys()), help="Prompt preset (default: quick)")
    parser.add_argument("--timeout", type=int, default=30, help="Request timeout in seconds")

    parser.add_argument("--html", action="store_true", help="Output in HTML format")
    parser.add_argument("--stdin", action="store_true", help="Read input from stdin")
    parser.add_argument("--original-text", action="store_true", help="Append original text")
    parser.add_argument("--debug", action="store_true", help="Show debug info on stderr")
    parser.add_argument("--silent", action="store_true", help="Suppress error messages")
    parser.add_argument("text", nargs="*", default="", help="Input text")

    args = parser.parse_args()

    if args.input and not args.output:
        if not args.silent:
            print("Error: --output is required when --input is specified", file=sys.stderr)
        sys.exit(1)

    input_text = ""
    if args.stdin:
        if not sys.stdin.isatty():
            input_text = read_input_with_encoding(sys.stdin).rstrip("\r\n")
    elif args.text:
        input_text = " ".join(args.text)

    if not input_text:
        if not args.silent:
            print("Error: No input text provided", file=sys.stderr)
        sys.exit(1)

    prompt_template = PROMPTS[args.prompt]

    if args.auto_mode:
        try:
            directions = [parse_direction(d) for d in args.auto_mode]
        except ValueError as e:
            if not args.silent:
                print(f"Error: {e}", file=sys.stderr)
            sys.exit(1)
        result = resolve_direction(input_text, directions)
        if not result:
            if not args.silent:
                print("Error: No matching auto-mode direction for detected language", file=sys.stderr)
            sys.exit(1)
        src, tgt = result
    elif args.input:
        src = lang_to_code(args.input)
        tgt = lang_to_code(args.output)
    else:
        if not args.silent:
            print("Error: Specify --auto-mode or --input/--output", file=sys.stderr)
        sys.exit(1)

    if args.debug:
        print(f"Host: {args.host}", file=sys.stderr)
        print(f"Model: {args.model}", file=sys.stderr)
        print(f"Prompt: {args.prompt}", file=sys.stderr)
        print(f"Direction: {lang_label(src)} -> {lang_label(tgt)}", file=sys.stderr)
        print(f"Input length: {len(input_text)}", file=sys.stderr)

    try:
        translated = translate_multiline(
            input_text, args.model, args.host.rstrip("/"), prompt_template, src, tgt, args.timeout
        )
    except Exception as e:
        if not args.silent:
            print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)

    if args.html:
        orig = input_text if args.original_text else None
        output = format_html(translated, orig)
    else:
        output = translated
        if args.original_text:
            output += f"\n{input_text}"

    emit(output)


if __name__ == "__main__":
    main()
