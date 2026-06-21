# Inspired by https://github.com/cometeme/compress-office
# Authors: GLM-5.1🧙‍♂️, scillidan🤡

import io
import shutil
import subprocess
import sys
import tempfile
import zipfile
from pathlib import Path

try:
    from PIL import Image
except ImportError:
    Image = None

PNG_EXTS = {".png"}
JPG_EXTS = {".jpg", ".jpeg"}


def fmt_size(n):
    for unit in ("B", "KB", "MB", "GB"):
        if n < 1024:
            return f"{n:.2f}{unit}"
        n /= 1024
    return f"{n:.2f}TB"


def rimage_batch(images, codec_args, workers):
    if not images:
        return
    cmd = (
        ["rimage"] + codec_args + ["--strip", "--quiet", f"-t{workers}"]
        + [str(p) for p in images]
    )
    subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def pillow_compress_jpeg(path, quality=75):
    with Image.open(path) as img:
        buf = io.BytesIO()
        img.save(buf, format="JPEG", quality=quality, optimize=True)
    if buf.tell() < path.stat().st_size:
        path.write_bytes(buf.getvalue())


def compress_jpegs(jpg_images, quality):
    if Image is None:
        print("  Warning: Pillow not installed, JPEG compression skipped.")
        return
    for p in jpg_images:
        try:
            pillow_compress_jpeg(p, quality)
        except Exception:
            pass


def compress_office(file_path, quality=75, effort=2, workers=4):
    file_path = Path(file_path).resolve()
    before_size = file_path.stat().st_size

    try:
        zf_check = zipfile.ZipFile(file_path, "r")
        zf_check.close()
    except zipfile.BadZipFile:
        print("  Not a valid Office file (old binary format or corrupted).")
        return before_size, before_size

    with tempfile.TemporaryDirectory() as tmp_dir:
        tmp = Path(tmp_dir)

        with zipfile.ZipFile(file_path, "r") as zf:
            zf.extractall(tmp)

        all_files = [p for p in tmp.rglob("*") if p.is_file()]
        png_images = [p for p in all_files if p.suffix.lower() in PNG_EXTS]
        jpg_images = [p for p in all_files if p.suffix.lower() in JPG_EXTS]

        if not png_images and not jpg_images:
            print("  No compressible images found.")
            return before_size, before_size

        rimage_batch(png_images, ["oxipng", f"--effort={effort}"], workers)
        compress_jpegs(jpg_images, quality)

        new_file = tmp / file_path.name
        with zipfile.ZipFile(new_file, "w", zipfile.ZIP_DEFLATED) as zf:
            for item in sorted(tmp.rglob("*")):
                if item.is_file() and item != new_file:
                    zf.write(item, item.relative_to(tmp))

        after_size = new_file.stat().st_size

        if after_size >= before_size:
            print("  Size unchanged.")
            return before_size, before_size

        shutil.copy2(new_file, file_path)

    saved = before_size - after_size
    pct = round(100 * saved / before_size, 1)
    print(f"  {fmt_size(before_size)} -> {fmt_size(after_size)} (-{pct}%)")
    return before_size, after_size


def main():
    if len(sys.argv) < 2:
        print("Usage: rimage_office.py <office_file>", file=sys.stderr)
        sys.exit(1)

    file_path = sys.argv[1]

    b, a = compress_office(file_path)
    if b == a:
        sys.exit(0)
    saved = b - a
    pct = round(100 * saved / b, 2)
    print(f"  Total saved: {fmt_size(saved)} ({pct}%)")


if __name__ == "__main__":
    main()
