# /// script
# requires-python = ">=3.10"
# dependencies = ["pymupdf", "opencv-python-headless", "numpy", "pillow"]
# ///
#
# Whiten scanned-PDF backgrounds.
#
# A wide Gaussian blur estimates the local paper brightness; dividing by it
# lifts paper to white while ink keeps its original depth.
#
# Usage:
#   uv run lib/pdfs_fix_brightness.py <pdf1> <pdf2> ...
#   --mode        clean = keep gray tones (default); binary = pure black/white
#   --strength    Whitening force 0~1.5 (lower for dark/yellow paper, higher for heavy shading)
#   --white-clip  Brightness above which pixels go pure white (default 246)
#   --dpi         Render DPI for pages without an embedded image (default 200)
#   --jpeg        Write JPEG instead of PNG (smaller output, ±1 level drift)
#   Output: <stem>_whitened.pdf next to each input.
#   If the output file already exists, asks to overwrite (n/Y).

import argparse
import io
import sys
from pathlib import Path

import cv2
import numpy as np
import pymupdf as fitz
from PIL import Image


def confirm_overwrite(path: Path) -> bool:
    if not path.exists():
        return True
    answer = input(f"  {path.name} already exists. Overwrite? [n/Y]: ").strip().lower()
    return answer in ("", "y", "yes")


def load_page_image(doc, page, dpi):
    """Prefer the embedded scan; fall back to rendering at the given DPI."""
    imgs = page.get_images(full=True)
    if imgs:
        xref = max(imgs, key=lambda t: t[2] * t[3])[0]
        raw = doc.extract_image(xref)
        img = Image.open(io.BytesIO(raw["image"]))
        if img.mode in ("RGBA", "LA", "P") or "transparency" in img.info:
            img = img.convert("RGBA")
            white = Image.new("RGBA", img.size, (255, 255, 255, 255))
            img = Image.alpha_composite(white, img).convert("RGB")
        else:
            img = img.convert("RGB")
        return img
    pix = page.get_pixmap(dpi=dpi, colorspace=fitz.csRGB)
    return Image.frombytes("RGB", (pix.width, pix.height), pix.samples)


def corner_mean(arr):
    """Rough paper brightness from the mean of four corner blocks."""
    h, w = arr.shape[:2]
    k = max(4, min(h, w) // 20)
    blocks = [arr[:k, :k], arr[:k, -k:], arr[-k:, :k], arr[-k:, -k:]]
    return float(np.mean([b.mean() for b in blocks]))


def whiten(img, mode="clean", strength=1.0, white_clip=246):
    arr = np.asarray(img).astype(np.float32)
    _, w = arr.shape[:2]
    gray = cv2.cvtColor(arr.astype(np.uint8), cv2.COLOR_RGB2GRAY).astype(np.float32)

    # Sigma ~= w/45: wide enough to erase text, leaving only slow paper variation.
    sigma = max(15.0, w / 45.0)
    bg = cv2.GaussianBlur(gray, (0, 0), sigmaX=sigma, sigmaY=sigma)
    bg = np.clip(bg, 120.0, 255.0)  # Clamp dark corners to limit noise amplification.

    factor = 1.0 + (255.0 / np.maximum(bg, 1.0) - 1.0) * strength
    out = np.clip(arr * factor[..., None], 0, 255)
    near_white = (out >= white_clip).all(axis=2)
    out[near_white] = 255.0
    out = out.astype(np.uint8)

    if mode == "binary":
        g = cv2.cvtColor(out, cv2.COLOR_RGB2GRAY)
        block = int(max(15, w / 40)) | 1
        bw = cv2.adaptiveThreshold(
            g, 255, cv2.ADAPTIVE_THRESH_GAUSSIAN_C, cv2.THRESH_BINARY, block, 12
        )
        out = cv2.cvtColor(bw, cv2.COLOR_GRAY2RGB)

    return Image.fromarray(out)


def process(src_path: Path, out_path: Path, args):
    src = fitz.open(str(src_path))
    dst = fitz.open()
    try:
        for i, page in enumerate(src, 1):
            img = load_page_image(src, page, args.dpi)
            before = corner_mean(np.asarray(img))
            cleaned = whiten(img, args.mode, args.strength, args.white_clip)
            after = corner_mean(np.asarray(cleaned))

            buf = io.BytesIO()
            if args.jpeg:
                cleaned.save(
                    buf, format="JPEG", quality=args.jpeg_quality, subsampling=0
                )
            else:
                cleaned.save(buf, format="PNG", optimize=True)

            new_page = dst.new_page(width=page.rect.width, height=page.rect.height)
            new_page.insert_image(
                new_page.rect, stream=buf.getvalue(), keep_proportion=True
            )
            print(
                f"  Page {i:>3}  {img.width}x{img.height}  background {before:6.1f} -> {after:6.1f}"
            )

        dst.save(str(out_path), deflate=True)
    finally:
        dst.close()
        src.close()


def main():
    parser = argparse.ArgumentParser(
        description="Whiten the background of scanned PDFs"
    )
    parser.add_argument("files", nargs="+", metavar="PDF", help="Source PDF files")
    parser.add_argument(
        "-o",
        "--output",
        default=None,
        help="Output PDF path (single input only; default: <stem>_whitened.pdf)",
    )
    parser.add_argument(
        "--dpi", type=int, default=200, help="Render DPI when no image is embedded"
    )
    parser.add_argument(
        "--mode",
        choices=["clean", "binary"],
        default="clean",
        help="clean = keep gray tones (default); binary = pure black and white",
    )
    parser.add_argument(
        "--strength",
        type=float,
        default=1.0,
        help="Whitening force 0~1.5; lower for dark/yellow paper, higher for heavy shading",
    )
    parser.add_argument(
        "--white-clip",
        type=int,
        default=246,
        help="Brightness above which pixels go pure white (default 246)",
    )
    parser.add_argument("--jpeg", action="store_true", help="Write JPEG instead of PNG")
    parser.add_argument(
        "--jpeg-quality", type=int, default=92, help="JPEG quality (default 92)"
    )
    args = parser.parse_args()

    paths = [Path(p).resolve() for p in args.files]
    for p in paths:
        if not p.is_file():
            print(f"Error: File not found: {p}", file=sys.stderr)
            sys.exit(1)

    if args.output and len(paths) > 1:
        print("Error: -o/--output only works with a single input file", file=sys.stderr)
        sys.exit(1)

    print("Print at 100% / actual size in black-and-white mode for best ink saving.")
    print()

    failed = 0
    for p in paths:
        out_path = (
            Path(args.output).resolve()
            if args.output
            else p.with_name(p.stem + "_whitened.pdf")
        )
        print(f"  Input   : {p.name}")
        print(f"  Output  : {out_path.name}")
        if not confirm_overwrite(out_path):
            print(f"  Skipped : {out_path.name} not overwritten.")
            continue
        try:
            process(p, out_path, args)
        except Exception as exc:
            print(f"  Error   : {p.name}: {exc}", file=sys.stderr)
            failed = 1
            continue
        print()

    sys.exit(failed)


if __name__ == "__main__":
    main()
