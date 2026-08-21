# /// script
# requires-python = ">=3.10"
# dependencies = ["pypdf"]
# ///

# Extract selected pages from PDFs into one new PDF per input file.
# Page syntax: single pages, ranges, and comma/semicolon-separated lists, e.g.
#   1 ; 1-3 ; 1,3 ; 1,3-5,8
#
# Usage:
#   uv run lib/pdf_extract.py -p "1-3,5" <pdf1> <pdf2> ...
#   -p, --pages   Pages to extract (e.g. "1", "1-3", "1,3")
#   Output: <stem>_p<pages>.pdf next to each input
#   If the output file already exists, asks to overwrite (n/Y).

import argparse
import re
import sys
from pathlib import Path

from pypdf import PdfReader, PdfWriter


def confirm_overwrite(path: Path) -> bool:
    if not path.exists():
        return True
    answer = input(f"  {path.name} already exists. Overwrite? [n/Y]: ").strip().lower()
    return answer in ("", "y", "yes")


def parse_page_spec(spec: str, page_count: int) -> list[int]:
    """Return 0-based page indices for a spec like '1,3-5'. 1-based, inclusive."""
    indices: list[int] = []
    for part in spec.split(","):
        part = part.strip()
        if not part:
            continue
        if "-" in part:
            start_s, _, end_s = part.partition("-")
            if not start_s.strip() or not end_s.strip():
                raise ValueError(f"Invalid range: '{part}'")
            start = int(start_s)
            end = int(end_s)
            if start < 1 or end > page_count or start > end:
                raise ValueError(f"Range '{part}' out of bounds (1-{page_count})")
            indices.extend(range(start, end + 1))
        else:
            page = int(part)
            if page < 1 or page > page_count:
                raise ValueError(f"Page '{page}' out of bounds (1-{page_count})")
            indices.append(page)
    seen: set[int] = set()
    result: list[int] = []
    for i in indices:
        if i not in seen:
            seen.add(i)
            result.append(i)
    return [i - 1 for i in result]


def main():
    parser = argparse.ArgumentParser(
        description="Extract selected pages from PDFs into one new PDF per input"
    )
    parser.add_argument(
        "files",
        nargs="+",
        metavar="PDF",
        help="PDF files to process",
    )
    parser.add_argument(
        "-p",
        "--pages",
        required=True,
        help='Pages to extract, e.g. "1", "1-3", "1,3", "1,3-5,8"',
    )
    args = parser.parse_args()

    page_spec = ",".join(p.strip() for p in re.split(r"[,;]", args.pages) if p.strip())
    if not page_spec:
        print("Error: No pages specified", file=sys.stderr)
        sys.exit(1)

    error = 0
    for file in args.files:
        path = Path(file)
        if not path.exists():
            print(f"Error: File not found: {path}", file=sys.stderr)
            error = 1
            continue

        try:
            reader = PdfReader(str(path))
        except Exception as e:
            print(f"Error: Cannot read {path.name}: {e}", file=sys.stderr)
            error = 1
            continue

        page_count = len(reader.pages)
        try:
            indices = parse_page_spec(page_spec, page_count)
        except ValueError as e:
            print(f"Error: {path.name}: {e}", file=sys.stderr)
            error = 1
            continue

        out_path = path.with_name(f"{path.stem}_p{page_spec}.pdf")
        print(
            f"  {path.name}: {page_count} pages -> {out_path.name} ({len(indices)} pages)"
        )

        if not confirm_overwrite(out_path):
            print(f"  Skipped: {out_path.name} not overwritten.")
            continue

        writer = PdfWriter()
        for i in indices:
            writer.add_page(reader.pages[i])
        with open(out_path, "wb") as f:
            writer.write(f)

    sys.exit(1 if error else 0)


if __name__ == "__main__":
    main()
