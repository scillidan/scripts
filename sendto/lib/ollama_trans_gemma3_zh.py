# /// script
# requires-python = ">=3.12"
# dependencies = [
#     "requests",
#     "langdetect"
# ]
# ///

# Translate Non-Chinese to Chinese or translate Chinese to English with Ollama.
# References:
#   https://qiita.com/KEINOS/items/3ab8879654e808d12791
#   https://github.com/xiaodaxia-2008/golden-dict-trans
# Model: https://ollama.com/zongwei/gemma3-translator
# Authors: mistral.ai🧙‍♂️, DeepSeek🧙‍♂️, scillidan🤡
#
# Usage:
#   uv run file.py
#   uv run file.py "<text>"
#   echo <text> | uv run file.py --stdin
#   cat file.txt | uv run file.py --stdin

import requests
import json
import argparse
import re
import sys
import io
import unicodedata
import os
import codecs
from langdetect import detect, DetectorFactory

# Ensure consistent langdetect results
DetectorFactory.seed = 0

# Ensure stdout uses UTF-8 encoding
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')

model_name = 'zongwei/gemma3-translator:4b'

ollama_host = os.environ.get("OLLAMA_HOST", "http://localhost")
if ollama_host and not ollama_host.startswith(('http://', 'https://')):
    ollama_host = f'http://{ollama_host}'

def clean_surrogates(text):
    """Remove or replace surrogate characters."""
    if not text:
        return ""

    # Remove surrogate characters (U+D800 to U+DFFF)
    cleaned = ''.join(
        char for char in text
        if not ('\ud800' <= char <= '\udfff')
    )

    return cleaned

def normalize_text(text):
    """Normalize text to handle special characters and encoding issues."""
    if not text:
        return ""

    # First clean any surrogate characters
    text = clean_surrogates(text)

    # Then normalize Unicode
    try:
        normalized = unicodedata.normalize('NFKC', text)
    except:
        # If normalization fails, return the cleaned text
        normalized = text

    # Remove other problematic control characters
    problematic_chars = [
        '\x00', '\x01', '\x02', '\x03', '\x04', '\x05', '\x06', '\x07',
        '\x08', '\x0b', '\x0c', '\x0e', '\x0f',
        '\u200b', '\u200c', '\u200d', '\ufeff'  # Zero-width spaces and BOM
    ]
    for char in problematic_chars:
        normalized = normalized.replace(char, '')

    return normalized.strip()

def safe_json_dumps(obj, ensure_ascii=False):
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

def is_chinese(text):
    """Check if the text contains Chinese characters."""
    for char in text:
        if '\u4e00' <= char <= '\u9fff':
            return True
    return False

def detect_language(text):
    """Detect language of text."""
    try:
        if is_chinese(text):
            return 'zh'
        return detect(text)
    except:
        return "unknown"

def translate_text(text, debug=False):
    """Translate text."""
    if not text or not text.strip():
        return text, None

    # Normalize input text first
    normalized_text = normalize_text(text)
    if debug and text != normalized_text:
        print(f"<!-- Normalized text: '{text}' -> '{normalized_text}' -->")

    url = f"{ollama_host}:11434/api/generate"
    if is_chinese(normalized_text):
        prompt = f'Translate from Chinese to English:\n{{"english": "<translation here>"}}\n\nChinese: {normalized_text}'
    else:
        lang = detect_language(normalized_text)
        prompt = f'Translate from {lang} to Chinese:\n{{"chinese": "<translation here>"}}\n\nSentence: {normalized_text}'

    headers = {'Content-Type': 'application/json; charset=utf-8'}
    data = {
        'model': model_name,
        'prompt': prompt,
        'stream': False
    }

    try:
        # Use safe JSON serialization
        json_str = safe_json_dumps(data, ensure_ascii=False)
        json_bytes = json_str.encode('utf-8', errors='replace')

        if debug:
            print(f"<!-- Request data: {json_str[:500]}... -->")

        response = requests.post(url, headers=headers, data=json_bytes, timeout=30)

        if response.status_code != 200:
            if debug:
                print(f"<!-- API Error: {response.status_code}, Response: {response.text[:500]} -->")
            return text, None  # Return original text if API fails

        response_data = response.json()
        output = response_data.get('response', '').strip()

        if debug:
            print(f"<!-- Raw API Response: {output} -->")  # Debug: Print raw response

        try:
            json_match = re.search(r'\{.*\}', output, re.DOTALL)
            if json_match:
                output = json_match.group(0)
            result = json.loads(output)
            if is_chinese(normalized_text):
                translated_text = result.get('english', output)
            else:
                translated_text = result.get('chinese', output)

            # Normalize the translated text as well
            normalized_translation = normalize_text(translated_text)
            if debug and translated_text != normalized_translation:
                print(f"<!-- Normalized translation: '{translated_text}' -> '{normalized_translation}' -->")

            if is_chinese(normalized_text):
                return normalized_translation, 'English'
            else:
                return normalized_translation, 'Chinese (Simplified)'
        except json.JSONDecodeError as e:
            if debug:
                print(f"<!-- JSON decode error: {e} -->")
            # Normalize the raw output if JSON parsing fails
            normalized_output = normalize_text(output)
            return normalized_output, None
    except requests.exceptions.RequestException as e:
        if debug:
            print(f"<!-- Request error: {e} -->")
        return text, None
    except Exception as e:
        if debug:
            print(f"<!-- Unexpected error: {e} -->")
        return text, None

def translate_multiline(text, debug=False):
    """Translate multi-line text, preserving line breaks."""
    if not text:
        return "", None

    lines = text.split('\n')
    translated_lines = []

    for i, line in enumerate(lines):
        if debug and i > 0:
            print(f"<!-- Processing line {i+1} -->")

        if line.strip():  # Only translate non-empty lines
            translated_line, lang = translate_text(line, debug)
            translated_lines.append(translated_line)
        else:
            translated_lines.append("")  # Keep empty lines

    # Reconstruct with original line breaks
    result = '\n'.join(translated_lines)

    # Determine overall language (use first non-empty line)
    for line in lines:
        if line.strip():
            _, lang = translate_text(line, debug)
            break
    else:
        lang = None

    return result, lang

def read_input_with_encoding(fileobj):
    """Read input with proper encoding handling."""
    # Try UTF-8 first
    try:
        content = fileobj.buffer.read()
        return content.decode('utf-8')
    except UnicodeDecodeError:
        # Try UTF-16 if UTF-8 fails
        try:
            fileobj.buffer.seek(0)
            bom = fileobj.buffer.read(2)
            fileobj.buffer.seek(0)

            if bom == b'\xff\xfe' or bom == b'\xfe\xff':
                # UTF-16 with BOM
                return fileobj.buffer.read().decode('utf-16')
            else:
                # Try UTF-16 LE/BE without BOM
                try:
                    fileobj.buffer.seek(0)
                    return fileobj.buffer.read().decode('utf-16-le')
                except:
                    fileobj.buffer.seek(0)
                    return fileobj.buffer.read().decode('utf-16-be')
        except:
            # Fall back to latin-1 (never fails)
            fileobj.buffer.seek(0)
            return fileobj.buffer.read().decode('latin-1', errors='replace')

def main():
    parser = argparse.ArgumentParser(description='Translate text using Ollama API.')
    parser.add_argument('--debug', action='store_true', help='Enable debug output')
    parser.add_argument('--utf16', action='store_true', help='Output translation in UTF-16 encoding')
    parser.add_argument('--html', action='store_true', help='Output translation in HTML format')
    parser.add_argument('--stdin', action='store_true', help='Read input from stdin instead of arguments')
    parser.add_argument('--original-text', action='store_true', help='Show original text after translation')
    parser.add_argument('text', nargs='*', type=str, help='Input text to translate (or use --stdin)')

    args = parser.parse_args()

    # Get input text
    input_text = ''
    if args.stdin:
        # Read from stdin with encoding detection
        if not sys.stdin.isatty():  # Check if stdin has data
            input_text = read_input_with_encoding(sys.stdin)
            # Remove trailing whitespace characters (including newlines)
            input_text = input_text.rstrip('\r\n')
    elif args.text:
        # Join all arguments as a single string
        input_text = ' '.join(args.text)

    if not input_text:
        print("Error: No input text provided.", file=sys.stderr)
        print("Usage: script.py [--debug] [--html] [--utf16] [--stdin] [--original-text] <text>", file=sys.stderr)
        print("  Use --stdin to read from standard input", file=sys.stderr)
        sys.exit(1)

    if args.debug:
        print(f"<!-- Input text length: {len(input_text)} -->", file=sys.stderr)
        if input_text:
            print(f"<!-- First 200 chars: {repr(input_text[:200])} -->", file=sys.stderr)

    # Translate the text
    translated_text, _ = translate_multiline(input_text, args.debug)

    if translated_text:
        if args.html:
            # HTML output with minimal styling to look like plain text
            lines = translated_text.split('\n')
            source_lines = input_text.split('\n') if args.original_text else []

            # Create HTML with minimal styling
            html_output = '''<div style="margin: 0; padding: 0;">'''

            for i, line in enumerate(lines):
                if line.strip():
                    html_output += f'<p style="margin: 0; padding: 0">{line}</p>'
                elif i < len(lines) - 1:  # Only add empty line if it's not the last line
                    html_output += '<p style="margin: 0; padding: 0">&nbsp;</p>'
                # If it's the last empty line, skip it (to avoid trailing whitespace)

            html_output += '</div>'

            # Add original text if requested
            if args.original_text and source_lines:
                html_output += '<div style="margin: 0; padding: 0;">'
                for i, line in enumerate(source_lines):
                    if line.strip():
                        html_output += f'<p style="margin: 0; padding: 0">{line}</p>'
                    elif i < len(source_lines) - 1:
                        html_output += '<p style="margin: 0; padding: 0">&nbsp;</p>'
                html_output += '</div>'

            if args.utf16:
                encoded_output = html_output.encode("utf-16", errors="replace")
                sys.stdout.buffer.write(encoded_output)
                sys.stdout.buffer.flush()
            else:
                print(html_output)
        else:
            # Plain text output
            output_text = translated_text

            # Add original text if requested
            if args.original_text:
                # Add separator and original text
                separator = "\n\n--- Original Text ---\n"
                output_text += separator + input_text

            if args.utf16:
                encoded_output = output_text.encode("utf-16", errors="replace")
                sys.stdout.buffer.write(encoded_output)
                sys.stdout.buffer.flush()
            else:
                print(output_text)

if __name__ == "__main__":
    main()