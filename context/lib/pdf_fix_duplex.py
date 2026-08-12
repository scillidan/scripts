# /// script
# requires-python = ">=3.10"
# dependencies = ["pypdf"]
# ///

# Fix PDF page order from non-duplex scanning
# Authors: GLM-5.1🧙‍♂️, scillidan🤡
#
# Input page order (scanner feeds the top sheet, ejects to the bottom):
#   A.pdf: 01, 03, 05, ... 101, 103   (odd pages, ascending)
#   B.pdf: 102, 100, ... 04, 02       (even pages, reversed by scanner)
#   Result: 01, 02, 03, ... 102, 103
#
# Usage:
#   uv run lib/pdf_fix_duplex.py <pdf1> <pdf2> [-o OUTPUT]
#   pdf1, pdf2: sorted alphabetically -> pdf1=odd, pdf2=even
#   -o, --output   Output file path (default: <pdf1_stem>_fixed.pdf)
#   If the output file already exists, asks to overwrite (n/Y).

import argparse
import sys
from pathlib import Path

from pypdf import PdfReader, PdfWriter


def confirm_overwrite(path: Path) -> bool:
    if not path.exists():
        return True
    answer = input(f"  {path.name} already exists. Overwrite? [n/Y]: ").strip().lower()
    return answer in ("", "y", "yes")


def fix_duplex_order(odd_path: str, even_path: str, output_path: str):
    odd_reader = PdfReader(odd_path)
    even_reader = PdfReader(even_path)

    odd_count = len(odd_reader.pages)
    even_count = len(even_reader.pages)

    writer = PdfWriter()
    for i in range(odd_count):
        writer.add_page(odd_reader.pages[i])
        if i < even_count:
            writer.add_page(even_reader.pages[even_count - 1 - i])

    with open(output_path, "wb") as f:
        writer.write(f)

    print(f"  {odd_count}+{even_count} pages -> {output_path}")


def main():
    parser = argparse.ArgumentParser(
        description="Fix PDF page order from non-duplex scanning"
    )
    parser.add_argument(
        "files",
        nargs=2,
        metavar="PDF",
        help="Two PDF files (sorted alphabetically: A=odd, B=even)",
    )
    parser.add_argument(
        "-o",
        "--output",
        default=None,
        help="Output PDF path (default: <first_stem>_fixed.pdf)",
    )
    args = parser.parse_args()

    paths = sorted(Path(p).resolve() for p in args.files)

    for p in paths:
        if not p.exists():
            print(f"Error: File not found: {p}", file=sys.stderr)
            sys.exit(1)

    odd_path = paths[0]
    even_path = paths[1]

    print(f"  Odd  (A): {odd_path.name}  ({len(PdfReader(str(odd_path)).pages)} pages)")
    print(
        f"  Even (B): {even_path.name}  ({len(PdfReader(str(even_path)).pages)} pages)"
    )

    if args.output is not None:
        out_path = Path(args.output).resolve()
    else:
        out_path = odd_path.with_name(odd_path.stem + "_fixed.pdf")

    print(f"  Output  : {out_path.name}")
    print()

    if not confirm_overwrite(out_path):
        print(f"  Aborted: {out_path.name} not overwritten.")
        sys.exit(1)

    fix_duplex_order(str(odd_path), str(even_path), str(out_path))


if __name__ == "__main__":
    main()
