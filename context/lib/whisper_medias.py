# /// script
# requires-python = ">=3.12"
# dependencies = []
# ///

# Subtitle post-processing for whisper_medias.sh
# Commands:
#   fix <srt>       — fix zero-duration entries, split long lines (>30 chars)
#   nopunc <src> <dst> — strip punctuation to spaces (for TTS)

import sys
import re
import os

MIN_DURATION_MS = 1000
MAX_CHARS = 30
CHINESE_PUNCT = '，。！？、；：""【】《》…——·～「」『』（）()[]{}<>/\\|@#$%^&*_-~+=`^'
ENGLISH_PUNCT = ",.!?;:'\"()[]{}<>/\\|@#$%^&*_-~+=`^"


def parse_srt(content):
    entries = []
    content = content.lstrip("\ufeff")
    blocks = content.strip().split("\n\n")
    for block in blocks:
        lines = block.strip().split("\n")
        if len(lines) < 3:
            continue
        time_match = re.match(
            r"(\d{2}):(\d{2}):(\d{2}),(\d{3})\s*-->\s*(\d{2}):(\d{2}):(\d{2}),(\d{3})",
            lines[1],
        )
        if not time_match:
            continue
        start = (
            int(time_match[1]) * 3600000
            + int(time_match[2]) * 60000
            + int(time_match[3]) * 1000
            + int(time_match[4])
        )
        end = (
            int(time_match[5]) * 3600000
            + int(time_match[6]) * 60000
            + int(time_match[7]) * 1000
            + int(time_match[8])
        )
        text = "\n".join(lines[2:])
        entries.append((start, end, text))
    return entries


def format_time(ms):
    h = ms // 3600000
    m = (ms % 3600000) // 60000
    s = (ms % 60000) // 1000
    mss = ms % 1000
    return f"{h:02d}:{m:02d}:{s:02d},{mss:03d}"


def fix_entries(entries, max_chars=MAX_CHARS):
    fixed = []

    i = 0
    while i < len(entries):
        start, end, text = entries[i]
        duration = end - start

        if duration < MIN_DURATION_MS:
            group = [(start, end, text)]
            j = i + 1
            while j < len(entries) and entries[j][0] == start:
                group.append(entries[j])
                j += 1

            total_chars = sum(len(e[2].replace("\n", " ")) for e in group)
            next_start = (
                entries[j][0]
                if j < len(entries)
                else start + max(total_chars * 200, MIN_DURATION_MS)
            )
            available = next_start - start
            duration_total = max(
                available, max(total_chars * 200, len(group) * MIN_DURATION_MS)
            )

            current = start
            for gs, ge, gt in group:
                chars = len(gt.replace("\n", " "))
                chunk = (
                    int(duration_total * (chars / total_chars))
                    if total_chars > 0
                    else duration_total // len(group)
                )
                chunk = max(chunk, MIN_DURATION_MS)
                piece_end = current + chunk
                if piece_end > next_start:
                    piece_end = next_start
                    if piece_end <= current:
                        piece_end = current + MIN_DURATION_MS
                fixed.append((current, piece_end, gt))
                current = piece_end

            i = j
        else:
            fixed.append((start, end, text))
            i += 1

    result = []
    for start, end, text in fixed:
        flat = text.replace("\n", " ")
        flat = re.sub(r"\s+", " ", flat).strip()

        if len(flat) <= max_chars:
            result.append((start, end, text))
            continue

        duration = end - start
        parts = []
        while flat:
            if len(flat) <= max_chars:
                parts.append(flat)
                break

            split_at = max_chars
            lo = int(max_chars * 0.5)
            for p in "。！？，、；：.!?,;: ":
                pos = flat.rfind(p, lo, max_chars)
                if pos > 0:
                    split_at = pos + 1
                    break
            else:
                hi = min(max_chars + 10, len(flat))
                if hi > max_chars:
                    for p in "。！？，、；：.!?,;: ":
                        pos = flat.rfind(p, max_chars, hi)
                        if pos > 0:
                            split_at = pos + 1
                            break

            parts.append(flat[:split_at].strip())
            flat = flat[split_at:].strip()

        if not parts:
            continue

        total_len = sum(len(p) for p in parts)
        current = start
        for p in parts:
            p_end = (
                current + int(duration * len(p) / total_len)
                if total_len > 0
                else current + duration // len(parts)
            )
            p_end = min(p_end, end)
            if p_end <= current:
                p_end = current + max(MIN_DURATION_MS // 2, 100)
            result.append((current, p_end, p))
            current = p_end

    return result


def format_srt(entries):
    blocks = []
    for i, (start, end, text) in enumerate(entries, 1):
        blocks.append(f"{i}\n{format_time(start)} --> {format_time(end)}\n{text}")
    return "\n\n".join(blocks) + "\n"


def cmd_fix(args):
    max_chars = MAX_CHARS
    files = []
    i = 0
    while i < len(args):
        if args[i] == "--max-chars":
            i += 1
            if i < len(args):
                max_chars = int(args[i])
        else:
            files.append(args[i])
        i += 1

    if not files:
        print("Usage: python whisper_medias.py fix <srt_file> [--max-chars N]")
        return 1

    for filepath in files:
        if not os.path.isfile(filepath):
            print(f"Error: File not found: {filepath}", file=sys.stderr)
            continue
        with open(filepath, "r", encoding="utf-8-sig", errors="replace") as f:
            content = f.read()
        entries = parse_srt(content)
        if not entries:
            print(f"Warning: No entries found in {filepath}", file=sys.stderr)
            continue
        fixed = fix_entries(entries, max_chars)
        output = format_srt(fixed)
        with open(filepath, "w", encoding="utf-8") as f:
            f.write("\ufeff" + output)
        print(f"Fixed: {filepath}")
    return 0


def strip_punctuation_srt(content):
    content = content.lstrip("\ufeff")
    lines = content.splitlines(True)
    output = []
    for line in lines:
        stripped = line.strip()
        if re.match(r"^\d+$", stripped) or re.match(
            r"\d{2}:\d{2}:\d{2},\d{3}\s*-->\s*\d{2}:\d{2}:\d{2},\d{3}$", stripped
        ) or stripped == "":
            output.append(line)
        else:
            text = line
            all_punct = CHINESE_PUNCT + ENGLISH_PUNCT
            for p in all_punct:
                text = text.replace(p, " ")
            text = re.sub(r"\s+", " ", text)
            output.append(text.rstrip() + "\n")
    return "".join(output)


def cmd_nopunc(args):
    if len(args) < 2:
        print("Usage: python whisper_medias.py nopunc <input.srt> <output.srt>")
        return 1
    src, dst = args[0], args[1]
    with open(src, "r", encoding="utf-8-sig", errors="replace") as f:
        content = f.read()
    result = strip_punctuation_srt(content)
    d = os.path.dirname(dst)
    if d:
        os.makedirs(d, exist_ok=True)
    with open(dst, "w", encoding="utf-8") as f:
        f.write("\ufeff" + result)
    return 0


def main():
    if len(sys.argv) < 3:
        print("Usage:")
        print("  python whisper_medias.py fix <srt_file> [--max-chars N]")
        print("  python whisper_medias.py nopunc <input.srt> <output.srt>")
        sys.exit(1)

    cmd = sys.argv[1]
    args = sys.argv[2:]
    if cmd == "fix":
        sys.exit(cmd_fix(args))
    elif cmd == "nopunc":
        sys.exit(cmd_nopunc(args))
    else:
        print(f"Unknown command: {cmd}")
        sys.exit(1)


if __name__ == "__main__":
    main()
