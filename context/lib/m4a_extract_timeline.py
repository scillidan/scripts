# Extract chapter timeline from m4a/m4b audio file
# Authors: MiniMax-M2.1🧙‍♂️, scillidan🤡
# Usage: uv run file.py <m4a>

import argparse
import subprocess
import sys
import re
from pathlib import Path


def find_ffmpeg() -> Path:
    """Find ffmpeg executable path."""
    ffmpeg_names = ["ffmpeg.exe", "ffmpeg"] if sys.platform == "win32" else ["ffmpeg"]

    for name in ffmpeg_names:
        ffmpeg_path = Path(name)
        if ffmpeg_path.is_file():
            return ffmpeg_path.resolve()

        result = subprocess.run(
            ["where" if sys.platform == "win32" else "which", name],
            capture_output=True,
            text=True,
        )
        if result.returncode == 0:
            return Path(result.stdout.strip().split("\n")[0])

    raise FileNotFoundError("ffmpeg not found. Please install ffmpeg first.")


def extract_timeline(input_file: Path) -> str:
    """Extract chapter timeline from audio file."""
    ffmpeg_path = find_ffmpeg()

    cmd = [str(ffmpeg_path), "-i", str(input_file), "-hide_banner"]
    result = subprocess.run(cmd, capture_output=True, text=True)
    output = result.stderr + result.stdout

    lines = []

    chapter_pattern = re.compile(
        r"Chapter #\d+:\d+: start ([\d\.]+), end ([\d\.]+).*?title\s*:\s*(.+?)\s*$",
        re.MULTILINE | re.DOTALL,
    )

    for idx, match in enumerate(chapter_pattern.finditer(output), 1):
        start_time = match.group(1)
        title = match.group(3).strip()

        seconds = float(start_time)
        hours = int(seconds // 3600)
        minutes = int((seconds % 3600) // 60)
        secs = int(seconds % 60)

        timestamp = f"{hours:02d}:{minutes:02d}:{secs:02d}"

        lines.append(f"{timestamp} {idx:02d}. {title}")

    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser(
        description="Extract chapter timeline from m4a/m4b audio file.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  uv run m4a_timeline.py book.m4a
  uv run m4a_timeline.py "path/to/track.m4b"
        """,
    )
    parser.add_argument("input", type=Path, help="Input m4a/m4b file")
    parser.add_argument(
        "-v", "--verbose", action="store_true", help="Enable verbose output"
    )

    args = parser.parse_args()

    if not args.input.exists():
        print(f"Error: Input file not found: {args.input}")
        sys.exit(1)

    if args.verbose:
        print(f"Processing: {args.input.name}")

    timeline = extract_timeline(args.input)

    if not timeline.strip():
        print("No chapters found in the file.")
        sys.exit(1)

    output_file = Path(str(args.input) + ".chp")
    output_file.write_text(timeline + "\n")

    print(f"Timeline extracted to: {output_file}")
    print(f"Found {timeline.count(chr(10)) + 1} chapters")


if __name__ == "__main__":
    main()
