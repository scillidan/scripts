import argparse
import os
import re


def srt_to_vtt(input_path, output_path):
    with open(input_path, "r", encoding="utf-8-sig") as f:
        content = f.read()

    content = re.sub(r"(\d{2}:\d{2}:\d{2}),(\d{3})", r"\1.\2", content)
    content = f"WEBVTT\n\n{content}"

    with open(output_path, "w", encoding="utf-8") as f:
        f.write(content)


def main():
    parser = argparse.ArgumentParser(description="Convert SRT to VTT")
    parser.add_argument("-i", "--input", required=True, help="Input SRT file")
    parser.add_argument("-o", "--output", help="Output VTT file (optional)")
    args = parser.parse_args()

    input_file = args.input

    if not os.path.isfile(input_file):
        print(f"Error: Input file '{input_file}' not found.")
        return

    if args.output:
        output_file = args.output
    else:
        base = os.path.splitext(input_file)[0]
        output_file = f"{base}.vtt"

    srt_to_vtt(input_file, output_file)
    print(
        f"Converted '{os.path.basename(input_file)}' to '{os.path.basename(output_file)}'"
    )


if __name__ == "__main__":
    main()
