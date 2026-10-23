# Authors: MiniMax-M2.1🧙‍♂️, scillidan🤡

import argparse
import os
import re

CHINESE_PUNCT = '，。！？、；：""【】《》…——·～「」『』（）()[]{}<>/\\|@#$%^&*_-~+=`^'
ENGLISH_PUNCT = ",.!?;:'\"()[]{}<>/\\|@#$%^&*_-~+=`^"


def is_timestamp(line):
    return bool(
        re.match(
            r"\d{2}:\d{2}:\d{2},\d{3}\s*-->\s*\d{2}:\d{2}:\d{2},\d{3}$", line.strip()
        )
    )


def is_index(line):
    return bool(re.match(r"^\d+$", line.strip()))


def process_content(text):
    all_punct = CHINESE_PUNCT + ENGLISH_PUNCT
    for p in all_punct:
        text = text.replace(p, " ")
    text = re.sub(r"\s+", " ", text)
    text = text.strip()
    return text


def _next_non_blank(lines, start):
    """Return index of the next non-blank line at or after start, or len(lines)."""
    i = start
    while i < len(lines) and lines[i].strip() == "":
        i += 1
    return i


def process_srt(src_path, dst_path):
    with open(src_path, "rb") as f:
        raw = f.read()
    if raw.startswith(b"\xef\xbb\xbf"):
        raw = raw[3:]
    try:
        text = raw.decode("utf-8")
    except UnicodeDecodeError:
        text = raw.decode("utf-8", errors="ignore")

    # Normalize line endings for consistent parsing.
    text = text.replace("\r\n", "\n").replace("\r", "\n")
    lines = text.split("\n")

    entries = []
    i = 0
    n = len(lines)
    while i < n:
        # Find a subtitle index followed by a timestamp.
        if not is_index(lines[i]):
            i += 1
            continue

        timestamp_idx = _next_non_blank(lines, i + 1)
        if timestamp_idx >= n or not is_timestamp(lines[timestamp_idx]):
            i += 1
            continue

        index = lines[i].strip()
        timestamp = lines[timestamp_idx].strip()

        # Collect content lines until the next valid subtitle entry.
        k = timestamp_idx + 1
        content_lines = []
        while k < n:
            if lines[k].strip() == "":
                k += 1
                continue

            # A line is only a new index if it is followed by a timestamp.
            if is_index(lines[k]):
                next_ts = _next_non_blank(lines, k + 1)
                if next_ts < n and is_timestamp(lines[next_ts]):
                    break

            cleaned = process_content(lines[k])
            if cleaned:
                content_lines.append(cleaned)
            k += 1

        entries.append((index, timestamp, content_lines))
        i = k

    os.makedirs(os.path.dirname(dst_path), exist_ok=True) if os.path.dirname(
        dst_path
    ) else None
    with open(dst_path, "w", encoding="utf-8") as f:
        for index, timestamp, content_lines in entries:
            f.write(f"{index}\n")
            f.write(f"{timestamp}\n")
            for line in content_lines:
                f.write(f"{line}\n")
            f.write("\n")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Convert SRT punctuation to spaces")
    parser.add_argument("-i", "--input", required=True, help="Input file")
    parser.add_argument("-o", "--output", required=True, help="Output file")
    args = parser.parse_args()

    process_srt(args.input, args.output)
