# /// script
# requires-python = ">=3.12"
# dependencies = [
#     "opencc-python-reimplemented",
#     "pypinyin",
#     "ToJyutping",
# ]
# ///

# Usage: python script.py <pinyin|jyutping> <input.lrc> <output.lrc>

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


def convert_chars(chars, mode):
    if mode == "jyutping":
        return ToJyutping.get_jyutping_text(chars)
    else:
        simplified = CONVERTER.convert(chars)
        return " ".join(lazy_pinyin(simplified, style=Style.TONE3))


def convert_line(text, mode):
    text = re.sub(r"[^\u4e00-\u9fff\s]", "", text)
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


def process_file(input_path, output_path, mode):
    with open(input_path, "r", encoding="utf-8") as f:
        lines = f.readlines()

    output_lines = []
    for line in lines:
        line = line.rstrip("\n").rstrip("\r")
        match = re.match(r"^(\[[^\]]+\])(.*)$", line)
        if match:
            timestamp, text = match.groups()
            converted = convert_line(text, mode)
            output_lines.append(f"{timestamp} {converted}")
        else:
            output_lines.append(line)

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
