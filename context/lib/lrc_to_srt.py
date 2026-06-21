# Base on https://github.com/HUYDGD/lrc2srt/blob/main/lrc2srt.py
# Authors: perplexity.ai🧙‍♂️, scillidan🤡
# Usage: python script.py <lrc> <srt>

import os
import re
import sys

def parse_lrc_timestamp(timestamp):
    try:
        minutes, seconds = timestamp.split(':')
        seconds, milliseconds = seconds.split('.')
        return int(minutes) * 60 + int(seconds) + int(milliseconds) / 100
    except ValueError:
        return None

def format_time(seconds):
    minutes, seconds = divmod(int(seconds), 60)
    hours, minutes = divmod(minutes, 60)
    millis = int((seconds - int(seconds)) * 1000) if seconds != int(seconds) else 0
    return f"{hours:02d}:{minutes:02d}:{int(seconds):02d},{millis:03d}"

def lrc_to_srt(lrc_file_path, srt_file_path):
    with open(lrc_file_path, 'r', encoding='utf-8') as lrc_file:
        matches = re.findall(r'\[(\d+:\d+\.\d+)\](.*)', lrc_file.read())

    subs = []
    for idx, (timestamp, text) in enumerate(matches):
        start_time = parse_lrc_timestamp(timestamp)
        if start_time is None:
            continue
        end_time = parse_lrc_timestamp(matches[idx + 1][0]) if idx + 1 < len(matches) else start_time + 1
        subs.append(f"{len(subs) + 1}\n{format_time(start_time)} --> {format_time(end_time)}\n{text.strip()}")

    with open(srt_file_path, 'w', encoding='utf-8') as srt_file:
        srt_file.write("\n\n".join(subs))

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python script.py <input_file> <output_file>")
        sys.exit(1)

    input_file, output_file = sys.argv[1], sys.argv[2]

    if not os.path.isfile(input_file):
        print(f"Error: Input file '{input_file}' not found.")
        sys.exit(1)

    lrc_to_srt(input_file, output_file)
    print(f"Converted '{os.path.basename(input_file)}' to '{os.path.basename(output_file)}'")
