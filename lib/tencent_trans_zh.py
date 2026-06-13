# /// script
# requires-python = ">=3.12"
# dependencies = [
#     "tencentcloud-sdk-python",
#     "langid"
# ]
# ///

# Tencent Cloud Translation API wrapper for translate Multi-language to Chinese or translate Chinese to English.
# Inspired by https://github.com/LexsionLee/tencent-translate-for-goldendict
# Authors: DeepSeek🧙, scillidan🤡
#
# Install:
#   1. Get your API-Key from https://cloud.tencent.com/product/tmt
#   2. In environment, add:
#      ENCENT_SECRET_ID=<YOUR_SECRET_ID>
#      ENCENT_SECRET_KEY=<YOUR_SECRET_KEY>
#
# Usage:
#   uv run file.py "<text>"
#   echo <text> | uv run file.py
#   cat file.txt | uv run file.py

import json
import sys
import os
import argparse
import textwrap
import unicodedata
import re
import codecs
import time
from typing import Optional, Tuple, List
import langid


class RateLimiter:
    def __init__(self, max_qps: float = 5.0):
        self.min_interval = 1.0 / max_qps
        self.last_call = 0.0

    def wait(self):
        elapsed = time.monotonic() - self.last_call
        if elapsed < self.min_interval:
            time.sleep(self.min_interval - elapsed)
        self.last_call = time.monotonic()


rate_limiter = RateLimiter(5.0)

from tencentcloud.common import credential
from tencentcloud.common.profile.client_profile import ClientProfile
from tencentcloud.common.profile.http_profile import HttpProfile
from tencentcloud.common.exception.tencent_cloud_sdk_exception import (
    TencentCloudSDKException,
)
from tencentcloud.tmt.v20180321 import tmt_client, models


SECRET_ID = os.getenv("TENCENT_SECRET_ID")
SECRET_KEY = os.getenv("TENCENT_SECRET_KEY")
REGION = "ap-shanghai"
PROJECT_ID = 0

# Ensure stdout uses UTF-8 encoding
sys.stdout.reconfigure(encoding="utf-8")


def clean_surrogates(text: str) -> str:
    """Remove or replace surrogate characters."""
    if not text:
        return ""

    # Remove surrogate characters (U+D800 to U+DFFF)
    cleaned = "".join(char for char in text if not ("\ud800" <= char <= "\udfff"))

    return cleaned


def parse_arguments() -> argparse.Namespace:
    """Parse command line arguments with improved error handling"""
    parser = argparse.ArgumentParser(
        formatter_class=argparse.RawDescriptionHelpFormatter,
        description=textwrap.dedent("""
            Tencent Cloud Translation for GoldenDict
            Automatically detects language and translates:
            - Non-Chinese to Chinese
            - Chinese to English
            Supports languages listed at: https://cloud.tencent.com/document/api/551/15620
        """),
    )
    parser.add_argument(
        "text",
        metavar="TEXT",
        type=str,
        nargs="?",
        default="",
        help="Text to translate (reads from stdin if not provided)",
    )
    parser.add_argument(
        "--silent",
        action="store_true",
        help="Suppress error messages (useful for GoldenDict integration)",
    )
    parser.add_argument(
        "--original-text",
        action="store_true",
        help="Show the original input text after translation",
    )
    parser.add_argument(
        "--html", action="store_true", help="Output translation in HTML format"
    )
    parser.add_argument(
        "--utf16", action="store_true", help="Output translation in UTF-16 encoding"
    )
    return parser.parse_args()


def normalize_text(text: str) -> str:
    """
    Normalize text to handle special characters and encoding issues
    This helps prevent API errors caused by malformed input
    """
    if not text:
        return ""

    # First clean any surrogate characters
    text = clean_surrogates(text)

    # Normalize Unicode characters
    try:
        normalized = unicodedata.normalize("NFKC", text)
    except:
        # If normalization fails, return the cleaned text
        normalized = text

    # Remove other problematic control characters
    problematic_chars = [
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
        "\ufeff",  # Zero-width spaces and BOM
    ]
    for char in problematic_chars:
        normalized = normalized.replace(char, "")

    return normalized


def safe_json_dumps(obj, ensure_ascii: bool = False) -> str:
    """Safely serialize JSON with surrogate character handling."""
    # First convert to JSON string
    try:
        json_str = json.dumps(obj, ensure_ascii=ensure_ascii)
    except UnicodeEncodeError:
        # If that fails, try with ensure_ascii=True
        json_str = json.dumps(obj, ensure_ascii=True)

    # Clean any remaining surrogates
    json_str = clean_surrogates(json_str)
    return json_str


def detect_language(text: str) -> Optional[str]:
    """
    Detect language of input text with fallback mechanisms
    Returns language code compatible with Tencent Cloud API
    """
    if not text or not text.strip():
        return None

    try:
        # Use langid to detect language
        detected_lang, confidence = langid.classify(text)

        # Map to Tencent Cloud language codes
        lang_map = {
            "zh": "zh",  # Chinese
            "en": "en",  # English
            "ja": "ja",  # Japanese
            "ko": "ko",  # Korean
            "fr": "fr",  # French
            "de": "de",  # German
            "es": "es",  # Spanish
            "it": "it",  # Italian
            "ru": "ru",  # Russian
            "pt": "pt",  # Portuguese
            "ar": "ar",  # Arabic
            "th": "th",  # Thai
            "vi": "vi",  # Vietnamese
            "ms": "ms",  # Malay
        }

        # Return mapped language or default to English
        return lang_map.get(detected_lang, "en")

    except Exception as e:
        # Fallback detection for robustness
        if any("\u4e00" <= char <= "\u9fff" for char in text):
            return "zh"
        return "en"  # Default to English


def initialize_tencent_client() -> Optional[tmt_client.TmtClient]:
    """
    Initialize Tencent Cloud Translation client with proper configuration
    Handles credential validation and client setup
    """
    if not SECRET_ID or not SECRET_KEY:
        raise ValueError(
            "API credentials not configured. Please set SECRET_ID and SECRET_KEY."
        )

    try:
        # Initialize credentials
        cred = credential.Credential(SECRET_ID, SECRET_KEY)

        # Configure HTTP profile
        http_profile = HttpProfile()
        http_profile.endpoint = "tmt.tencentcloudapi.com"
        http_profile.req_timeout = 30  # 30 seconds timeout

        # Configure client profile
        client_profile = ClientProfile()
        client_profile.httpProfile = http_profile
        client_profile.signMethod = "TC3-HMAC-SHA256"  # Recommended signature method

        # Create client
        client = tmt_client.TmtClient(cred, REGION, client_profile)

        return client

    except TencentCloudSDKException as e:
        raise Exception(f"Failed to initialize Tencent Cloud client: {str(e)}")


def translate_text(
    text: str, source_lang: str, target_lang: str, silent: bool = False
) -> Tuple[Optional[str], Optional[str]]:
    """
    Translate text using Tencent Cloud Translation API
    Returns: (translated_text, target_language_code)
    """
    if not text or not text.strip():
        return None, None

    # Normalize input text
    normalized_text = normalize_text(text)
    if not normalized_text:
        return None, None

    try:
        # Initialize client
        client = initialize_tencent_client()

        # Prepare translation request
        req = models.TextTranslateRequest()
        params = {
            "SourceText": normalized_text,
            "Source": source_lang,
            "Target": target_lang,
            "ProjectId": PROJECT_ID,
        }

        # Use safe JSON serialization
        json_str = safe_json_dumps(params, ensure_ascii=False)
        req.from_json_string(json_str)

        # Send request
        resp = client.TextTranslate(req)
        dict_resp = json.loads(resp.to_json_string())

        # Extract translation
        translated_text = dict_resp.get("TargetText")

        if translated_text:
            # Clean any surrogate characters from the response
            translated_text = clean_surrogates(translated_text)
            return translated_text, target_lang
        else:
            if not silent:
                print(f"Warning: No translation returned for text: {text[:50]}...")
            return None, None

    except TencentCloudSDKException as e:
        if not silent:
            print(f"Tencent Cloud API Error: {str(e)}")

        # Provide more specific error messages
        error_code = str(e)
        if "AuthFailure" in error_code:
            if not silent:
                print(
                    "Authentication failed. Please check your SecretId and SecretKey."
                )
        elif "RequestLimitExceeded" in error_code:
            if not silent:
                print("API rate limit exceeded. Please wait and try again.")
        elif "FailedOperation.NoFreeAmount" in error_code:
            if not silent:
                print("Free quota exhausted. Please upgrade to paid service.")

        return None, None

    except Exception as e:
        if not silent:
            print(f"Unexpected error: {str(e)}")
        return None, None


def translate_multiline(
    text: str, source_lang: str, target_lang: str, silent: bool = False
) -> Tuple[Optional[str], Optional[str]]:
    """
    Translate multi-line text, preserving line breaks
    Returns: (translated_text, target_language_code)
    """
    if not text or not text.strip():
        return None, None

    lines = text.split("\n")
    translated_lines = []

    for i, line in enumerate(lines):
        if line.strip():  # Only translate non-empty lines
            translated_line, lang = translate_text(
                line, source_lang, target_lang, silent
            )
            if translated_line:
                translated_lines.append(translated_line)
            else:
                translated_lines.append(line)  # Keep original if translation fails
        else:
            translated_lines.append("")  # Keep empty lines

    # Reconstruct with original line breaks
    result = "\n".join(translated_lines)
    return result, target_lang


def determine_translation_direction(source_lang: str) -> Tuple[str, str]:
    """
    Determine translation direction based on source language
    Returns: (source_lang_code, target_lang_code)
    """
    # If Chinese, translate to English
    if source_lang == "zh":
        return "zh", "en"
    # Otherwise, translate to Chinese (if supported) or to English
    else:
        # Languages that can be translated to Chinese
        supported_to_chinese = [
            "en",
            "ja",
            "ko",
            "fr",
            "de",
            "es",
            "it",
            "ru",
            "pt",
            "ms",
            "th",
            "vi",
            "ar",
        ]

        if source_lang in supported_to_chinese:
            return source_lang, "zh"
        else:
            # For other languages, fallback to English
            return source_lang, "en"


def format_plaintext_output(
    original: str, translated: str, target_lang: str, show_original: bool = False
) -> str:
    """
    Format plain text output, preserving original line breaks
    """
    if not translated:
        return ""

    # Clean up translation
    clean_translation = translated.strip()

    output = clean_translation

    # Add original text if requested
    if show_original:
        separator = "\n"
        output += separator + original

    return output


def format_html_output(
    original: str, translated: str, target_lang: str, show_original: bool = False
) -> str:
    """
    Generate HTML output formatted for GoldenDict display
    """
    if not translated:
        return ""

    # Clean up translation
    clean_translation = translated.strip()

    # Split into lines
    lines = clean_translation.split("\n")
    source_lines = original.split("\n") if show_original else []

    # Create HTML with minimal styling
    html_output = """<div style="margin: 0; padding: 0;">"""

    for i, line in enumerate(lines):
        if line.strip():
            html_output += f'<p style="margin: 0; padding: 0">{line}</p>'
        elif i < len(lines) - 1:  # Only add empty line if it's not the last line
            html_output += '<p style="margin: 0; padding: 0">&nbsp;</p>'

    html_output += "</div>"

    # Add original text if requested
    if show_original and source_lines:
        html_output += '<div style="margin: 0; padding: 0;">'
        for i, line in enumerate(source_lines):
            if line.strip():
                html_output += f'<p style="margin: 0; padding: 0">{line}</p>'
            elif i < len(source_lines) - 1:
                html_output += '<p style="margin: 0; padding: 0">&nbsp;</p>'
        html_output += "</div>"

    return html_output


def read_input_with_encoding(fileobj):
    """Read input with proper encoding handling."""
    # Try UTF-8 first
    try:
        content = fileobj.buffer.read()
        return content.decode("utf-8")
    except UnicodeDecodeError:
        # Try UTF-16 if UTF-8 fails
        try:
            fileobj.buffer.seek(0)
            bom = fileobj.buffer.read(2)
            fileobj.buffer.seek(0)

            if bom == b"\xff\xfe" or bom == b"\xfe\xff":
                # UTF-16 with BOM
                return fileobj.buffer.read().decode("utf-16")
            else:
                # Try UTF-16 LE/BE without BOM
                try:
                    fileobj.buffer.seek(0)
                    return fileobj.buffer.read().decode("utf-16-le")
                except:
                    fileobj.buffer.seek(0)
                    return fileobj.buffer.read().decode("utf-16-be")
        except:
            # Fall back to latin-1 (never fails)
            fileobj.buffer.seek(0)
            return fileobj.buffer.read().decode("latin-1", errors="replace")


def main():
    """Main execution function with improved error handling"""
    args = parse_arguments()

    # Read input text
    if args.text:
        source_text = args.text
    else:
        try:
            source_text = read_input_with_encoding(sys.stdin)
        except Exception as e:
            if not args.silent:
                print(f"Error reading input: {str(e)}", file=sys.stderr)
            sys.exit(1)

    if not source_text:
        if not args.silent:
            print("Error: Empty input text", file=sys.stderr)
        sys.exit(1)

    # Remove trailing whitespace characters (including newlines)
    source_text = source_text.rstrip("\r\n")

    # Detect source language
    source_lang = detect_language(source_text)
    if not source_lang:
        if not args.silent:
            print(
                f"Warning: Could not detect language for: {source_text[:50]}...",
                file=sys.stderr,
            )
        source_lang = "en"  # Default to English

    # Determine translation direction
    actual_source, target_lang = determine_translation_direction(source_lang)

    # Perform translation
    if source_text.count("\n") > 0:  # Multi-line text
        translated_text, final_target_lang = translate_multiline(
            source_text, actual_source, target_lang, silent=args.silent
        )
    else:  # Single line text
        translated_text, final_target_lang = translate_text(
            source_text, actual_source, target_lang, silent=args.silent
        )

    # Output result
    if translated_text:
        # Format output
        if args.html:
            output_text = format_html_output(
                source_text, translated_text, final_target_lang, args.original_text
            )
        else:
            output_text = format_plaintext_output(
                source_text, translated_text, final_target_lang, args.original_text
            )

        # Output with or without UTF-16 encoding
        if args.utf16:
            encoded_output = output_text.encode("utf-16", errors="replace")
            sys.stdout.buffer.write(encoded_output)
            sys.stdout.buffer.flush()
        else:
            print(output_text)
    else:
        if not args.silent:
            print(
                "Translation failed. Please check your API credentials and network connection.",
                file=sys.stderr,
            )
        sys.exit(1)


if __name__ == "__main__":
    main()
