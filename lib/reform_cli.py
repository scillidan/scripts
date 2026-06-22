# /// script
# requires-python = ">=3.12"
# dependencies = [
#     "py-reform",
# ]
# ///

# py-reform CLI wrapper
# Authors: GLM-5🧙‍♂️, scillidan🤡
#
# Usage:
#   uv run reform_cli.py --input curved.jpg
#   uv run reform_cli.py --input doc.pdf --output result.pdf


import argparse
from pathlib import Path

from py_reform import straighten, save_pdf


def main():
    parser = argparse.ArgumentParser(
        description="Dewarp / straighten document images or PDFs using py-reform"
    )
    parser.add_argument(
        "--input",
        required=True,
        type=str,
        help="Input image or PDF file",
    )
    parser.add_argument(
        "--output",
        type=str,
        help="Optional output path (default: <input_dir>/_<input_name>)",
    )
    parser.add_argument(
        "--model",
        choices=["uvdoc", "deskew"],
        default="uvdoc",
        help="Dewarping model (default: uvdoc)",
    )
    parser.add_argument(
        "--device",
        default="auto",
        help="Device for UVDoc (cpu / cuda / auto)",
    )
    parser.add_argument(
        "--max-angle",
        type=float,
        default=15.0,
        help="Max rotation angle for deskew model (default: 15.0)",
    )
    parser.add_argument(
        "--num-peaks",
        type=int,
        default=30,
        help="Number of peaks for deskew model (default: 30)",
    )
    parser.add_argument(
        "--pages",
        type=str,
        help="PDF pages to process, comma-separated (e.g., '0,2,5')",
    )
    parser.add_argument(
        "--errors",
        choices=["raise", "ignore", "warn"],
        default="raise",
        help="Error handling (default: raise)",
    )

    parser.add_argument(
        "--force",
        action="store_true",
        help="Overwrite existing output file without prompting",
    )

    args = parser.parse_args()

    input_path = Path(args.input).expanduser().resolve()
    if not input_path.exists():
        raise FileNotFoundError(f"Input file does not exist: {input_path}")

    # Determine output path
    if args.output:
        output_path = Path(args.output).expanduser().resolve()
    else:
        output_path = input_path.with_name("_" + input_path.name)

    print(f"📥 Input:  {input_path}")
    print(f"📤 Output: {output_path}")
    print(f"🧠 Model:  {args.model}")

    if output_path.exists() and not args.force:
        print(f"⚠️  Output file already exists: {output_path}")
        response = input("Overwrite? [y/N]: ").strip().lower()
        if response != "y":
            print("❌ Aborted.")
            return

    kwargs = {"model": args.model, "errors": args.errors}

    if args.model == "uvdoc" and args.device != "auto":
        kwargs["device"] = args.device
    elif args.model == "deskew":
        kwargs["max_angle"] = args.max_angle
        kwargs["num_peaks"] = args.num_peaks

    if args.pages and input_path.suffix.lower() == ".pdf":
        kwargs["pages"] = [int(p.strip()) for p in args.pages.split(",")]

    result = straighten(str(input_path), **kwargs)

    # Image
    if input_path.suffix.lower() in {".jpg", ".jpeg", ".png", ".bmp", ".tiff"}:
        result.save(output_path)
        print("✅ Image saved.")

    # PDF
    elif input_path.suffix.lower() == ".pdf":
        save_pdf(result, str(output_path))
        print("✅ PDF saved.")

    else:
        raise ValueError(f"Unsupported file type: {input_path.suffix}")


if __name__ == "__main__":
    main()