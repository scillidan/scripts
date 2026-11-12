# /// script
# requires-python = ">=3.10"
# dependencies = ["pypdf", "numpy", "pillow"]
# ///
#
# Flatten bitmap PDFs for printing: 1-bit DeviceGray images, no color profile,
# no transparency group, standard paper size.
#
# Why gray shows up on paper but not on screen:
#   - An 8-bit RGB page with an ICCBased(sRGB) profile is converted to CMYK by
#     the print driver, where paper white tends to land as light four-color gray.
#   - 8-bit paper still carries +/-1..3 levels of noise and texture; halftoning
#     renders that as gray dots, while 1-bit ink either prints or does not.
#   - A page transparency group (/Group) can paint its background color, and an
#     /OutputIntents profile can force a conversion that washes out white.
#   - A non-standard MediaBox is rescaled by the driver, which drags background
#     fills (and their gray) into the output.
#
# Scans are usually JPEG-in-PDF (DCTDecode), so images are decoded with Pillow;
# pypdf alone only inflates Flate data and would leave those images untouched.
#
# Usage:
#   uv run lib/pdfs_fix_brightness.py <pdf1> <pdf2> ...
#   --paper      a4 / a3 / a4r / letter / b5, or WxH in pt (default a4)
#   --landscape  Landscape paper orientation
#   --threshold  0-255, lower keeps more white (default 128)
#   --no-verify  Skip the pixel check after writing
#   Output: <stem>_print.pdf next to each input.
#   If the output file already exists, asks to overwrite (n/Y).
#
# File side only: cartridge condition, toner density, economy mode and the
# "print background colors and images" dialog switch are not touched.

import argparse
import re
import sys
import zlib
from io import BytesIO
from pathlib import Path

import numpy as np
from PIL import Image
from pypdf import PdfReader, PdfWriter
from pypdf.generic import (
    DecodedStreamObject,
    IndirectObject,
    NameObject,
    NumberObject,
)

# Standard paper sizes in pt (1 inch = 72 pt).
PAPERS = {
    "a4": (595.276, 841.890),
    "a3": (841.890, 1190.551),
    "a4r": (841.890, 595.276),
    "letter": (612.0, 792.0),
    "b5": (498.898, 708.661),
}

# Filters whose payload is a complete image file that Pillow can open.
PIL_FILTERS = ("/DCTDecode", "/JPXDecode")

# Image keys that can steer a print driver toward color conversion or the
# alternate, higher-fidelity copy of the image.
IMAGE_STRIP_KEYS = (
    "/DecodeParms",
    "/Decode",
    "/SMask",
    "/Mask",
    "/Interpolate",
    "/Intent",
    "/Alternates",
    "/Metadata",
)


def format_size(size: int) -> str:
    if size < 1024 * 1024:
        return f"{size / 1024:.1f} KB"
    return f"{size / 1024 / 1024:.2f} MB"


def confirm_overwrite(path: Path) -> bool:
    if not path.exists():
        return True
    try:
        answer = (
            input(f"  {path.name} already exists. Overwrite? [n/Y]: ").strip().lower()
        )
    except EOFError:  # No console attached: never overwrite silently.
        return False
    return answer in ("", "y", "yes")


def parse_paper(spec: str, landscape: bool) -> tuple[float, float]:
    if spec.strip().lower() in PAPERS:
        width, height = PAPERS[spec.strip().lower()]
    else:
        match = re.fullmatch(r"([0-9.]+)\s*[xX*]\s*([0-9.]+)", spec.strip())
        if not match:
            raise ValueError(
                "Paper must be a4/a3/a4r/letter/b5 or WxH in pt, e.g. 595x842"
            )
        width, height = float(match.group(1)), float(match.group(2))
    if landscape:
        width, height = height, width
    return float(width), float(height)


def resolve(obj):
    """Dereference an indirect object.

    Every pypdf PdfObject has get_object() (returning self), so hasattr() cannot
    be used here: only IndirectObject may be unwrapped, otherwise this loops.
    """
    while isinstance(obj, IndirectObject):
        obj = obj.get_object()
    return obj


def filter_names(img) -> list[str]:
    filters = resolve(img.get("/Filter"))
    if filters is None:
        return []
    if isinstance(filters, (list, tuple)):
        return [str(resolve(name)) for name in filters]
    return [str(filters)]


def channel_count(img):
    """Return the sample count per pixel, or None when unsupported."""
    cs = resolve(img.get("/ColorSpace"))
    if isinstance(cs, str) or hasattr(cs, "startswith"):
        return {
            "/DeviceGray": 1,
            "/G": 1,
            "/CalGray": 1,
            "/DeviceRGB": 3,
            "/RGB": 3,
            "/CalRGB": 3,
            "/DeviceCMYK": 4,
            "/CMYK": 4,
        }.get(str(cs))
    if isinstance(cs, (list, tuple)):
        base = str(resolve(cs[0]))
        if base == "/ICCBased":
            n = int(resolve(cs[1]).get("/N", 3))
            return n if n in (1, 3, 4) else None
        if base in ("/CalRGB",):
            return 3
        if base in ("/CalGray",):
            return 1
    return None


def page_images(page):
    """Return (name, image) for every /Image XObject, following form XObjects."""
    resources = page.get("/Resources")
    if resources is None:  # Inherited from the page tree.
        node = resolve(page.get("/Parent"))
        while node is not None and resources is None:
            resources = node.get("/Resources")
            node = resolve(node.get("/Parent"))
    if resources is None:
        return []

    images: list[tuple[str, object]] = []
    seen: set[int] = set()

    def walk(res, prefix: str, depth: int):
        xobjects = resolve(resolve(res).get("/XObject"))
        if not xobjects or not hasattr(xobjects, "items"):
            return
        for name, ref in xobjects.items():
            key = ref.idnum if isinstance(ref, IndirectObject) else id(ref)
            if key in seen:
                continue
            seen.add(key)
            obj = resolve(ref)
            subtype = str(obj.get("/Subtype"))
            if subtype == "/Image":
                images.append((prefix + name, obj))
            elif subtype == "/Form" and depth < 6:
                sub = obj.get("/Resources")
                if sub is not None:
                    walk(sub, prefix + name + "/", depth + 1)

    walk(resources, "", 0)
    return images


def apply_decode(img, pixels, channels):
    """Apply a /Decode array to 8-bit samples, e.g. the [1 0] inversion."""
    decode = resolve(img.get("/Decode"))
    if decode is None:
        return pixels
    try:
        bounds = [float(v) for v in decode]
    except (TypeError, ValueError):
        return pixels
    if len(bounds) != 2 * channels:
        return pixels
    scaled = pixels.astype(np.float32)
    for channel in range(channels):
        low, high = bounds[2 * channel], bounds[2 * channel + 1]
        scaled[:, :, channel] = (
            low + scaled[:, :, channel] / 255.0 * (high - low)
        ) * 255.0
    return np.clip(scaled, 0, 255).astype(np.uint8)


def decode_pixels(img):
    """Return (samples as HxWxC uint8, channels) or (None, reason)."""
    width, height = int(img["/Width"]), int(img["/Height"])
    filters = filter_names(img)

    if any(f in PIL_FILTERS for f in filters):
        try:
            pil = Image.open(BytesIO(img.get_data()))
            pil.load()
        except Exception as exc:  # noqa: BLE001 - any decoder failure means skip
            return None, f"cannot decode {filters}: {exc}"
        gray_mode = pil.mode in ("L", "1", "LA", "I;16")
        pil = pil.convert("L" if gray_mode else "RGB")
        arr = np.asarray(pil, dtype=np.uint8)
        if arr.ndim == 2:
            arr = arr[:, :, None]
        if arr.shape[0] != height or arr.shape[1] != width:
            return (
                None,
                f"decoded size {arr.shape[1]}x{arr.shape[0]} != {width}x{height}",
            )
        return apply_decode(img, arr, arr.shape[2]), arr.shape[2]

    channels = channel_count(img)
    if channels is None:
        return None, f"unsupported color space {img.get('/ColorSpace')}"
    try:
        raw = img.get_data()
    except Exception as exc:  # noqa: BLE001 - e.g. CCITT/JBIG2 without a decoder
        return None, f"cannot decode {filters}: {exc}"
    expected = width * height * channels
    if len(raw) != expected:
        return None, f"decoded size mismatch ({len(raw)} != {expected}) {filters}"
    arr = np.frombuffer(raw, dtype=np.uint8).reshape(height, width, channels)
    return apply_decode(img, arr, channels), channels


def level_map(pixels, channels):
    """Map samples to a brightness map: low value = ink, 255 = bare paper."""
    if channels == 1:
        return pixels[:, :, 0]
    if channels == 3:
        return pixels.mean(axis=2)
    return 255.0 - pixels.max(axis=2)  # CMYK ink coverage


def binarize(img, threshold: int, warnings: list[str], page_no: int, name: str):
    """Replace an 8-bit gray/RGB/CMYK image with 1-bit DeviceGray in place.

    Returns True when the image was converted.
    """
    bits = int(img.get("/BitsPerComponent", 8))
    if bits != 8:
        text = "already bilevel" if bits == 1 else f"{bits}-bit"
        warnings.append(f"page {page_no} {name}: {text}, left as is")
        return False

    pixels, channels = decode_pixels(img)
    if pixels is None:
        warnings.append(f"page {page_no} {name}: {channels}")
        return False

    level = level_map(pixels, channels)
    black = level < threshold

    height, width = black.shape
    if black.mean() < 0.01 and ((level >= threshold) & (level < 240)).mean() > 0.03:
        warnings.append(
            f"page {page_no} {name}: mostly light content,"
            " a higher --threshold (e.g. 190) keeps it"
        )
    # DeviceGray 1-bit: 1 = white, 0 = black, rows packed big-endian.
    packed = np.packbits((~black).astype(np.uint8), axis=1, bitorder="big")
    if width % 8:
        # Pad the last byte with white bits so the right edge gains no black line.
        packed[:, -1] |= np.uint8(0xFF >> (width % 8))

    if "/SMask" in img or "/Mask" in img:
        warnings.append(f"page {page_no} {name}: dropped /SMask or /Mask")

    img._data = zlib.compress(packed.tobytes(), 6)
    img[NameObject("/Filter")] = NameObject("/FlateDecode")
    img[NameObject("/ColorSpace")] = NameObject("/DeviceGray")
    img[NameObject("/BitsPerComponent")] = NumberObject(1)
    for key in IMAGE_STRIP_KEYS:
        img.pop(NameObject(key), None)
    return True


def page_uses_alpha(page) -> bool:
    resources = resolve(page.get("/Resources"))
    states = resolve(resources.get("/ExtGState")) if resources else None
    if not states or not hasattr(states, "items"):
        return False
    for ref in states.values():
        state = resolve(ref)
        for key in ("/ca", "/CA"):
            try:
                if float(state.get(key, 1)) < 1:
                    return True
            except (TypeError, ValueError):
                continue
    return False


def strip_page_group(page, warnings: list[str], page_no: int):
    """Drop the page transparency group so no group backdrop color is painted."""
    if "/Group" not in page:
        return
    if page_uses_alpha(page):
        warnings.append(f"page {page_no}: keeps /Group, transparency in use")
        return
    page.pop(NameObject("/Group"), None)


def is_near_white_fill(operator: bytes, operands) -> bool:
    """True for a g/rg/k fill that is white or a barely visible tint."""
    try:
        values = [float(v) for v in operands]
    except (TypeError, ValueError):
        return False
    if operator == b"g" and len(values) == 1:
        return values[0] >= 0.85
    if operator == b"rg" and len(values) == 3:
        return min(values) >= 0.85
    if operator == b"k" and len(values) == 4:
        return max(values) <= 0.15
    return False


def strip_background_fill(page, writer, warnings: list[str], page_no: int):
    """Remove a page-covering near-white fill, the usual export "paper" tint.

    Word/Excel/scan exporters often paint 0.9-1.0 g or rg over the whole page.
    On screen it reads as white, on paper it is a visible gray wash. Only that
    paint is dropped; text, vectors and images are untouched.
    """
    contents = page.get_contents()
    if contents is None:
        return
    try:
        operations = contents.operations
    except Exception:  # noqa: BLE001 - unparsable content is left alone
        return

    mediabox = page.mediabox
    x0, y0 = float(mediabox.left), float(mediabox.bottom)
    page_w, page_h = float(mediabox.width), float(mediabox.height)
    if page_w <= 0 or page_h <= 0:
        return

    fill = None
    drop: set[int] = set()
    for index, (operands, operator) in enumerate(operations):
        if operator in (b"g", b"rg", b"k"):
            fill = (operator, operands)
            continue
        if operator != b"re" or index + 1 >= len(operations):
            continue
        if operations[index + 1][1] not in (b"f", b"f*"):
            continue
        if fill is None or not is_near_white_fill(*fill):
            continue
        try:
            x, y, w, h = [float(v) for v in operands]
        except (TypeError, ValueError):
            continue
        if x <= x0 + 1 and y <= y0 + 1 and w >= page_w * 0.95 and h >= page_h * 0.95:
            drop.update((index, index + 1))
            warnings.append(
                f"page {page_no}: removed near-white page fill"
                f" ({fill[0].decode()} {' '.join(str(v) for v in fill[1])})"
            )

    if not drop:
        return
    contents._operations = [
        op for index, op in enumerate(operations) if index not in drop
    ]
    contents._data = b""  # Force get_data() to re-serialize the filtered list.
    stream = DecodedStreamObject()
    stream.set_data(contents.get_data())
    page[NameObject("/Contents")] = writer._add_object(stream)


def resize_page(page, writer, paper, warnings: list[str], page_no: int):
    """Scale the whole page content into the paper size and center it.

    The content is wrapped in one `q <scale> 0 0 <scale> <tx> <ty> cm ... Q`
    instead of editing image draw matrices: that keeps text, rules and checkbox
    positions in the same relative place, and works no matter which matrix form
    the producer used or how many images a page draws.
    """
    width, height = paper
    mediabox = page.mediabox
    page_w, page_h = float(mediabox.width), float(mediabox.height)
    if page_w <= 0 or page_h <= 0:
        warnings.append(f"page {page_no}: empty MediaBox, paper size replaced only")
        page.mediabox.lower_left = (0, 0)
        page.mediabox.upper_right = (width, height)
        return

    x0, y0 = float(mediabox.left), float(mediabox.bottom)
    scale = min(width / page_w, height / page_h)
    tx = (width - page_w * scale) / 2 - x0 * scale
    ty = (height - page_h * scale) / 2 - y0 * scale

    contents = page.get_contents()
    content = contents.get_data() if contents is not None else b""
    # Leave an already correctly sized page's stream untouched.
    needs_wrap = abs(scale - 1) > 1e-6 or abs(tx) > 1e-6 or abs(ty) > 1e-6
    if content and needs_wrap:
        wrapped = (
            b"q\n"
            + f"{scale:.6f} 0 0 {scale:.6f} {tx:.6f} {ty:.6f} cm\n".encode()
            + content
            + b"\nQ"
        )
        # get_contents() wraps the streams, so set_data() never reaches the file:
        # a fresh /Contents stream is the only write-back path.
        stream = DecodedStreamObject()
        stream.set_data(wrapped)
        page[NameObject("/Contents")] = writer._add_object(stream)

    page.mediabox.lower_left = (0, 0)
    page.mediabox.upper_right = (width, height)


def strip_output_intents(writer, warnings: list[str]):
    """Remove the document output intent: it can force a CMYK conversion."""
    root = writer._root_object
    intents = resolve(root.get("/OutputIntents"))
    if not intents:
        return
    names = []
    for intent in intents:
        intent = resolve(intent)
        names.append(str(intent.get("/OutputConditionIdentifier", "?")))
    root.pop(NameObject("/OutputIntents"), None)
    warnings.append(f"removed /OutputIntents ({', '.join(names)})")


def optimize(
    src_path: Path, out_path: Path, paper, threshold: int, verify_pixels: bool
):
    writer = PdfWriter(clone_from=str(src_path))
    warnings: list[str] = []
    converted = 0
    skipped = 0
    seen: set[int] = set()  # The same image object can be drawn on many pages.

    strip_output_intents(writer, warnings)

    for page_no, page in enumerate(writer.pages, 1):
        strip_background_fill(page, writer, warnings, page_no)
        images = page_images(page)
        if not images:
            warnings.append(f"page {page_no}: no image, page left as is")
        for name, img in images:
            if id(img) in seen:
                continue
            seen.add(id(img))
            if binarize(img, threshold, warnings, page_no, name):
                converted += 1
            else:
                skipped += 1

        strip_page_group(page, warnings, page_no)
        resize_page(page, writer, paper, warnings, page_no)

    page_count = len(writer.pages)
    with open(out_path, "wb") as f:
        writer.write(f)

    print(f"  Output : {out_path.name}")
    print(
        f"  Layout : {page_count} pages | {paper[0]:.2f} x {paper[1]:.2f} pt"
        f" | threshold {threshold}"
    )
    print(
        f"  Images : {converted} converted, {skipped} skipped"
        f" | {format_size(out_path.stat().st_size)}"
    )
    for line in warnings[:20]:
        print(f"  Note   : {line}")
    if len(warnings) > 20:
        print(f"  Note   : ...{len(warnings) - 20} more")

    if not verify_pixels:
        return True
    passed, total = verify(src_path, out_path, threshold)
    if total == 0:
        print("  Check  : no images to compare")
        return True
    print(f"  Check  : {passed}/{total} pages match the source ink exactly")
    return passed == total


def verify(src_path: Path, out_path: Path, threshold: int):
    """Reopen both files and compare every converted image against the source."""
    reader_in = PdfReader(str(src_path))
    reader_out = PdfReader(str(out_path))
    passed = 0
    total = 0

    for page_in, page_out in zip(reader_in.pages, reader_out.pages):
        images_in = page_images(page_in)
        images_out = page_images(page_out)
        if not images_in:
            continue
        total += 1
        if len(images_in) != len(images_out):
            continue

        same = True
        for (_, img_in), (_, img_out) in zip(images_in, images_out):
            if str(img_out.get("/ColorSpace")) != "/DeviceGray":
                same = False
            if int(img_out.get("/BitsPerComponent", 8)) != 1:
                same = False
            if int(img_in.get("/BitsPerComponent", 8)) != 8:
                continue  # Left as is, nothing to compare.
            pixels, channels = decode_pixels(img_in)
            if pixels is None:
                continue
            src_black = level_map(pixels, channels) < threshold

            height, width = src_black.shape
            bits = np.unpackbits(
                np.frombuffer(img_out.get_data(), dtype=np.uint8).reshape(
                    height, (width + 7) // 8
                ),
                axis=1,
                bitorder="big",
            )[:, :width]
            if not np.array_equal(src_black, bits == 0):
                same = False

        if same:
            passed += 1

    return passed, total


def main():
    parser = argparse.ArgumentParser(
        description="Flatten bitmap PDFs to 1-bit black/white on standard paper"
    )
    parser.add_argument("files", nargs="+", metavar="PDF", help="Source PDF files")
    parser.add_argument(
        "-o",
        "--output",
        help="Output PDF path (single input only; default: <stem>_print.pdf)",
    )
    parser.add_argument(
        "--paper",
        default="a4",
        help="a4 / a3 / a4r / letter / b5, or WxH in pt (default a4)",
    )
    parser.add_argument(
        "--landscape", action="store_true", help="Landscape orientation"
    )
    parser.add_argument(
        "--threshold",
        type=int,
        default=128,
        help="Binarization threshold 0-255, lower keeps more white (default 128)",
    )
    parser.add_argument("--no-verify", action="store_true", help="Skip the pixel check")
    args = parser.parse_args()

    if not 0 <= args.threshold <= 255:
        sys.exit("Error: --threshold must be between 0 and 255")
    try:
        paper = parse_paper(args.paper, args.landscape)
    except ValueError as exc:
        sys.exit(f"Error: {exc}")

    paths = [Path(p).resolve() for p in args.files]
    for path in paths:
        if not path.is_file():
            print(f"Error: File not found: {path}", file=sys.stderr)
            sys.exit(1)

    if args.output and len(paths) > 1:
        print("Error: -o/--output only works with a single input file", file=sys.stderr)
        sys.exit(1)

    failed = 0
    for path in paths:
        out_path = (
            Path(args.output).resolve()
            if args.output
            else path.with_name(path.stem + "_print.pdf")
        )
        if out_path == path:
            print(
                f"Error: {path.name} is the input file, refusing to overwrite",
                file=sys.stderr,
            )
            failed = 1
            continue

        print(f"  Input  : {path.name}")
        if not confirm_overwrite(out_path):
            print(f"  Skipped: {out_path.name} not overwritten.")
            continue
        try:
            if not optimize(path, out_path, paper, args.threshold, not args.no_verify):
                failed = 1
        except Exception as exc:  # noqa: BLE001 - keep the batch going
            print(f"  Error  : {path.name}: {exc}", file=sys.stderr)
            failed = 1
        print()

    sys.exit(failed)


if __name__ == "__main__":
    main()
