import json
import sys
import io
import unicodedata
from typing import Optional

import requests


sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")


BAD_CHARS = [
    "\x00",
    "\x01",
    "\x02",
    "\x03",
    "\x04",
    "\x05",
    "\x06",
    "\x07",
    "\x08",
    "\x0b",
    "\x0c",
    "\x0e",
    "\x0f",
    "\u200b",
    "\u200c",
    "\u200d",
    "\ufeff",
]


def clean_surrogates(text: str) -> str:
    if not text:
        return ""
    return "".join(c for c in text if not ("\ud800" <= c <= "\udfff"))


def normalize_text(text: str, *, casefold: bool = False) -> str:
    if not text:
        return ""
    text = clean_surrogates(text)
    try:
        text = unicodedata.normalize("NFKC", text)
    except Exception:
        pass
    for ch in BAD_CHARS:
        text = text.replace(ch, "")
    text = text.strip()
    if casefold:
        text = text.lower()
    return text


def safe_json_dumps(obj: dict, ensure_ascii: bool = False) -> str:
    try:
        s = json.dumps(obj, ensure_ascii=ensure_ascii)
    except UnicodeEncodeError:
        s = json.dumps(obj, ensure_ascii=True)
    return clean_surrogates(s)


def read_input_with_encoding(fileobj) -> str:
    data = fileobj.buffer.read()
    if not data:
        return ""
    if data.startswith(b"\xff\xfe") or data.startswith(b"\xfe\xff"):
        return data.decode("utf-16")
    if data.startswith(b"\xef\xbb\xbf"):
        return data[3:].decode("utf-8")
    try:
        return data.decode("utf-8")
    except UnicodeDecodeError:
        pass
    if data.count(b"\x00") > len(data) // 4:
        for enc in ("utf-16-le", "utf-16-be"):
            try:
                return data.decode(enc)
            except UnicodeDecodeError:
                continue
    for enc in ("cp936", "gb18030"):
        try:
            return data.decode(enc)
        except UnicodeDecodeError:
            continue
    return data.decode("latin-1", errors="replace")


def read_stdin(silent: bool = False) -> str:
    if sys.stdin.isatty():
        if not silent:
            print("Error: No input piped to stdin", file=sys.stderr)
        sys.exit(1)
    return read_input_with_encoding(sys.stdin).rstrip("\r\n")


def call_llamacpp(
    prompt: str,
    model: Optional[str],
    host: str,
    timeout: int,
    *,
    system_prompt: Optional[str] = None,
    temperature: float = 0.3,
    max_tokens: int = 512,
) -> str:
    url = f"{host.rstrip('/')}/v1/chat/completions"
    messages = []
    if system_prompt:
        messages.append({"role": "system", "content": system_prompt})
    messages.append({"role": "user", "content": prompt})

    payload = {
        "messages": messages,
        "temperature": temperature,
        "max_tokens": max_tokens,
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
    choices = data.get("choices", [])
    if not choices:
        return ""
    return choices[0]["message"]["content"].strip()


def format_html(main_text: str, original: Optional[str] = None) -> str:
    lines = main_text.split("\n")
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
                parts.append(
                    f'<p style="margin: 0; padding: 0; color: #666">{line}</p>'
                )
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


def add_common_cli(parser):
    parser.add_argument(
        "--host",
        type=str,
        required=True,
        help="llama.cpp server host, e.g. http://127.0.0.1:8080",
    )
    parser.add_argument(
        "--timeout", type=int, default=30, help="Request timeout in seconds"
    )
    parser.add_argument("--stdin", action="store_true", help="Read input from stdin")
    parser.add_argument(
        "--debug", action="store_true", help="Show debug info on stderr"
    )
    parser.add_argument("--silent", action="store_true", help="Suppress error messages")


def handle_llm_error(e: Exception, silent: bool = False, host: str = ""):
    if silent:
        return
    if isinstance(e, requests.exceptions.ConnectionError):
        msg = "Error: Could not connect to llama.cpp server"
        if host:
            msg += f" at {host}"
        print(msg, file=sys.stderr)
    elif isinstance(e, requests.exceptions.HTTPError):
        print(f"HTTP Error: {e}", file=sys.stderr)
    elif isinstance(e, (KeyError, IndexError)):
        print("Error: Unexpected response format from server", file=sys.stderr)
    else:
        print(f"Error: {e}", file=sys.stderr)
