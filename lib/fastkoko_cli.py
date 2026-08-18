# /// script
# requires-python = ">=3.10"
# dependencies = []
# ///

# fastkoko_cli - CLI client for Kokoro-FastAPI local TTS server
# Calls the OpenAI-compatible /v1/audio/speech endpoint and writes audio bytes to stdout.
# Matches the web UI behavior: non-streaming, full audio file in response.content.
# Authors: Kimi-K2.7-Code🧙‍♂️, scillidan🤡
#
# Usage:
#   uv run fastkoko_cli.py "Hello world" --voice af_bella --format mp3 --play
#   uv run fastkoko_cli.py "Hello world" --voice af_bella --format mp3 > out.mp3
#   echo "Hello world" | uv run fastkoko_cli.py - --voice af_bella --format mp3 > out.mp3
#   uv run fastkoko_cli.py "Hello world" --voice af_bella --format mp3 | ffmpeg -f mp3 -i - -f wav - > out.wav


import argparse
import json
import os
import shutil
import subprocess
import sys
import urllib.error
import urllib.request


DEFAULT_URL = "http://localhost:8880/v1"
DEFAULT_VOICE = "af_bella"
DEFAULT_FORMAT = "mp3"
DEFAULT_SPEED = 1.0
DEFAULT_VOLUME = 1.0
DEFAULT_TIMEOUT = 300
SUPPORTED_FORMATS = ("mp3", "opus", "aac", "flac", "wav", "pcm")


def _log(msg, verbose=False):
    if verbose:
        print(msg, file=sys.stderr)


def _set_binary_stdout():
    """Ensure stdout is in binary mode (mainly for Windows)."""
    if sys.platform == "win32":
        import msvcrt

        try:
            msvcrt.setmode(sys.stdout.fileno(), os.O_BINARY)
        except (OSError, AttributeError):
            pass


def _read_input_with_encoding(fileobj):
    """Read binary stdin and decode with BOM/encoding detection."""
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


def _strip_quotes(text):
    """Strip matching surrounding quotes (common when piping from echo)."""
    text = text.strip()
    if len(text) >= 2 and text[0] == text[-1] and text[0] in ('"', "'"):
        return text[1:-1].strip()
    return text


def _read_text(args_text):
    """Read text from positional arg or stdin."""
    if args_text is not None and args_text != "-":
        return _strip_quotes(args_text)
    if sys.stdin.isatty():
        return ""
    return _strip_quotes(_read_input_with_encoding(sys.stdin))


def _call_tts(text, args):
    """Call the FastKoko TTS API and write audio to stdout, file, or ffplay."""
    url = "{}/audio/speech".format(args.url.rstrip("/"))
    payload = {
        "model": args.model,
        "input": text,
        "voice": args.voice,
        "response_format": args.format,
        "speed": args.speed,
        "stream": args.stream,
    }
    if args.lang is not None:
        payload["lang_code"] = args.lang
    if args.volume is not None:
        payload["volume_multiplier"] = args.volume

    data = json.dumps(payload, ensure_ascii=False).encode("utf-8")
    req = urllib.request.Request(
        url,
        data=data,
        headers={"Content-Type": "application/json; charset=utf-8"},
        method="POST",
    )

    _log("POST {} (stream={})".format(url, args.stream), args.verbose)
    _log("Payload: {}".format(payload), args.verbose)

    if args.play:
        _play_via_ffplay(req, args)
        return

    out = sys.stdout.buffer if args.output is None else open(args.output, "wb")
    try:
        with urllib.request.urlopen(req, timeout=args.timeout) as resp:
            _log("Response: {} {}".format(resp.status, resp.reason), args.verbose)
            audio = resp.read()
            out.write(audio)
            out.flush()
            _log("Wrote {} bytes of audio".format(len(audio)), args.verbose)
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8", errors="replace")
        raise RuntimeError(
            "API HTTP error {}: {}".format(e.code, body or e.reason)
        ) from e
    except urllib.error.URLError as e:
        raise RuntimeError("API connection error: {}".format(e.reason)) from e
    finally:
        if out is not sys.stdout.buffer:
            out.close()


def _play_via_ffplay(req, args):
    """Fetch audio and pipe it to ffplay for direct playback."""
    ffplay = shutil.which("ffplay")
    if not ffplay:
        raise RuntimeError("ffplay not found in PATH")

    proc = subprocess.Popen(
        [ffplay, "-nodisp", "-autoexit", "-i", "-"],
        stdin=subprocess.PIPE,
    )
    if proc.stdin is None:
        proc.kill()
        raise RuntimeError("failed to open ffplay stdin")

    try:
        with urllib.request.urlopen(req, timeout=args.timeout) as resp:
            _log("Response: {} {}".format(resp.status, resp.reason), args.verbose)
            audio = resp.read()
            proc.stdin.write(audio)
            proc.stdin.flush()
            _log("Wrote {} bytes of audio to ffplay".format(len(audio)), args.verbose)
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8", errors="replace")
        raise RuntimeError(
            "API HTTP error {}: {}".format(e.code, body or e.reason)
        ) from e
    except urllib.error.URLError as e:
        raise RuntimeError("API connection error: {}".format(e.reason)) from e
    finally:
        proc.stdin.close()

    proc.wait()
    if proc.returncode != 0:
        raise RuntimeError("ffplay exited with code {}".format(proc.returncode))


def main():
    parser = argparse.ArgumentParser(
        prog="fastkoko_cli",
        description="CLI client for Kokoro-FastAPI local TTS server. Writes audio bytes to stdout.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  uv run fastkoko_cli.py "Hello world" --voice af_bella --format mp3 > out.mp3
  uv run fastkoko_cli.py "Hello world" --voice af_bella --format mp3 -o out.mp3
  echo "Hello world" | uv run fastkoko_cli.py - --voice af_bella --format mp3 > out.mp3
  uv run fastkoko_cli.py "Hello world" --voice af_bella --format mp3 | ffmpeg -f mp3 -i - -f wav - > out.wav
  uv run fastkoko_cli.py "Hello world" --voice af_bella --format mp3 --play
  echo "%GDWORD%" | uv run fastkoko_cli.py - --voice af_bella --format mp3
  uv run fastkoko_cli.py "%GDWORD%" --voice af_bella --format mp3 --play
        """.strip(),
    )
    parser.add_argument(
        "text",
        nargs="?",
        default=None,
        help='Text to synthesize. Use "-" to read from stdin (default if no arg).',
    )
    parser.add_argument(
        "-o",
        "--output",
        default=None,
        help="Write audio to a file instead of stdout.",
    )
    parser.add_argument(
        "--voice",
        default=DEFAULT_VOICE,
        help="Voice to use (default: {}).".format(DEFAULT_VOICE),
    )
    parser.add_argument(
        "--format",
        "--response-format",
        dest="format",
        default=DEFAULT_FORMAT,
        choices=SUPPORTED_FORMATS,
        help="Output audio format (default: {}).".format(DEFAULT_FORMAT),
    )
    parser.add_argument(
        "--speed",
        type=float,
        default=DEFAULT_SPEED,
        help="Speech speed, 0.25-4.0 (default: {}).".format(DEFAULT_SPEED),
    )
    parser.add_argument(
        "--stream",
        action="store_true",
        default=False,
        help="Enable server-side streaming (default: off, matches web UI).",
    )
    parser.add_argument(
        "--url",
        default=DEFAULT_URL,
        help="FastKoko API base URL (default: {}).".format(DEFAULT_URL),
    )
    parser.add_argument(
        "--model",
        default="kokoro",
        help="Model name sent to API (default: kokoro).",
    )
    parser.add_argument(
        "--voices",
        default=None,
        help="Ignored; kept for compatibility with kokoro-tts CLI.",
    )
    parser.add_argument(
        "--lang",
        default=None,
        help="Optional language code.",
    )
    parser.add_argument(
        "--volume",
        type=float,
        default=DEFAULT_VOLUME,
        help="Volume multiplier (default: {}).".format(DEFAULT_VOLUME),
    )
    parser.add_argument(
        "--timeout",
        type=float,
        default=DEFAULT_TIMEOUT,
        help="Request timeout in seconds (default: {}).".format(DEFAULT_TIMEOUT),
    )
    parser.add_argument(
        "--play",
        action="store_true",
        help="Play audio via ffplay instead of writing to stdout.",
    )
    parser.add_argument(
        "-v",
        "--verbose",
        action="store_true",
        help="Print debug info to stderr.",
    )

    args = parser.parse_args()
    _set_binary_stdout()

    try:
        text = _read_text(args.text)
        if not text.strip():
            print("Error: no input text provided.", file=sys.stderr)
            return 2
        _call_tts(text, args)
    except Exception as e:
        print("Error: {}".format(e), file=sys.stderr)
        return 1

    return 0


if __name__ == "__main__":
    sys.exit(main())
