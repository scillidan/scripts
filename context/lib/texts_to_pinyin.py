# /// script
# requires-python = ">=3.12"
# dependencies = [
#     "opencc-python-reimplemented",
#     "pypinyin",
#     "ToJyutping",
# ]
# ///

# Convert CJK text to Mandarin Pinyin or Cantonese Jyutping.
# LRC lines keep the historical "CJK only" lyric output; every other text line
# (TXT/SRT body) is converted in place so non-CJK text is preserved.
#
# Usage: python script.py <pinyin|jyutping> <input> <output>

import os
import re
import sys

try:
    from pypinyin import lazy_pinyin, Style
    import ToJyutping
    import opencc
except ImportError as e:
    print(f"Error: Missing dependency: {e}")
    print("Please install: pip install opencc-python-reimplemented pypinyin ToJyutping")
    sys.exit(1)


CONVERTER = opencc.OpenCC("t2s")

CJK = "\u4e00-\u9fff"
TIMESTAMP_RE = re.compile(r"^(\[[^\]]+\])(.*)$")
METADATA_RE = re.compile(r"^\[[A-Za-z#]+:.*\]$")
CJK_RUN_RE = re.compile(f"[{CJK}]+")


def convert_chars(chars, mode):
    if mode == "jyutping":
        return ToJyutping.get_jyutping_text(chars)
    else:
        simplified = CONVERTER.convert(chars)
        return " ".join(lazy_pinyin(simplified, style=Style.TONE3))


def convert_lyric_line(text, mode):
    text = re.sub(rf"[^{CJK}\s]", "", text)
    text = re.sub(r"\s+", " ", text).strip()
    if not text:
        return ""
    segments = text.split(" ")
    converted = []
    for seg in segments:
        seg = seg.strip()
        if not seg:
            continue
        converted.append(convert_chars(seg, mode))
    return "  ".join(converted)


def convert_text_line(line, mode):
    return CJK_RUN_RE.sub(lambda m: convert_chars(m.group(0), mode), line)


def process_file(input_path, output_path, mode):
    with open(input_path, "r", encoding="utf-8") as f:
        lines = f.readlines()

    output_lines = []
    for line in lines:
        line = line.rstrip("\n").rstrip("\r")

        # Blank line, LRC tag ([ti:] [ar:] ...), SRT index or timecode: keep as is.
        if (
            not line.strip()
            or METADATA_RE.match(line)
            or line.strip().isdigit()
            or "-->" in line
        ):
            output_lines.append(line)
            continue

        match = TIMESTAMP_RE.match(line)
        if match:
            timestamp, text = match.groups()
            if text.strip():
                output_lines.append(f"{timestamp} {convert_lyric_line(text, mode)}")
            else:
                output_lines.append(timestamp)
        else:
            output_lines.append(convert_text_line(line, mode))

    with open(output_path, "w", encoding="utf-8") as f:
        f.write("\n".join(output_lines))
        if output_lines and output_lines[-1] != "":
            f.write("\n")


if __name__ == "__main__":
    if len(sys.argv) != 4:
        print("Usage: python script.py <pinyin|jyutping> <input> <output>")
        sys.exit(1)

    mode = sys.argv[1]
    input_file = sys.argv[2]
    output_file = sys.argv[3]

    if mode not in ("pinyin", "jyutping"):
        print(f"Error: mode must be 'pinyin' or 'jyutping', got '{mode}'")
        sys.exit(1)

    if not os.path.isfile(input_file):
        print(f"Error: Input file '{input_file}' not found.")
        sys.exit(1)

    process_file(input_file, output_file, mode)
    print(
        f"Converted '{os.path.basename(input_file)}' to '{os.path.basename(output_file)}'"
    )
