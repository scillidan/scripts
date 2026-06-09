# /// script
# requires-python = ">=3.12"
# dependencies = []
# ///

# Convert multi-line subtitle content to single line
# Authors: MiniMax-M2.1🧙‍♂️, scillidan🤡
#
# Usage: python file.py <input> [--output <output>]

import sys
import argparse
import os
import re


def parse_arguments() -> argparse.Namespace:
    """Parse command line arguments"""
    parser = argparse.ArgumentParser(
        formatter_class=argparse.RawDescriptionHelpFormatter,
        description="Convert multi-line SRT subtitle content to single line",
    )
    parser.add_argument(
        "input",
        metavar="INPUT",
        type=str,
        help="Input SRT file path",
    )
    parser.add_argument(
        "--output",
        type=str,
        default="",
        help="Output file path (default: _inline_$filename at workdir)",
    )
    return parser.parse_args()


def format_srt_content(srt_content: str) -> str:
    """
    Format SRT content by converting multi-line subtitle text to single line.
    """
    srt_content = srt_content.strip()
    if not srt_content:
        return ""

    lines = srt_content.split("\n")

    formatted_blocks = []
    i = 0

    while i < len(lines):
        line = lines[i].strip()

        if not line:
            i += 1
            continue

        if line.isdigit() or re.match(r"^\d+$", line):
            timeline_line = lines[i + 1].strip() if i + 1 < len(lines) else ""
            timeline_match = re.match(
                r"\d{2}:\d{2}:\d{2},\d{3}\s*-->\s*\d{2}:\d{2}:\d{2},\d{3}",
                timeline_line,
            )

            if timeline_match:
                i += 2
                subtitle_parts = []

                while (
                    i < len(lines)
                    and lines[i].strip()
                    and not re.match(r"^\d+$", lines[i].strip())
                    and "-->" not in lines[i]
                ):
                    subtitle_parts.append(lines[i].rstrip("\r"))
                    i += 1

                if subtitle_parts:
                    formatted_text = " ".join(subtitle_parts)
                    formatted_text = re.sub(r"\s+", " ", formatted_text).strip()
                else:
                    formatted_text = ""

                formatted_blocks.append(f"{line}\n{timeline_line}\n{formatted_text}")
            else:
                i += 1
        else:
            i += 1

    return "\n\n".join(formatted_blocks) + "\n"


def main():
    """Main execution function."""
    args = parse_arguments()

    try:
        with open(args.input, "r", encoding="utf-8") as f:
            source_content = f.read()
    except FileNotFoundError:
        print(f"Error: File '{args.input}' not found", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"Error reading file: {str(e)}", file=sys.stderr)
        sys.exit(1)

    if not source_content:
        print("Error: Empty input", file=sys.stderr)
        sys.exit(1)

    source_content = source_content.rstrip("\r\n")

    formatted_content = format_srt_content(source_content)

    if args.output:
        with open(args.output, "w", encoding="utf-8") as f:
            f.write(formatted_content)
    else:
        input_path = args.input
        base_name = os.path.basename(input_path)
        file_name, ext = os.path.splitext(base_name)
        output_path = os.path.join(".", f"_inline_{file_name}{ext}")
        with open(output_path, "w", encoding="utf-8") as f:
            f.write(formatted_content)


if __name__ == "__main__":
    main()
