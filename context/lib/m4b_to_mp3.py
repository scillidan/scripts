# /// script
# requires-python = ">=3.12"
# dependencies = [
#     "eyed3",
#     "Pillow"
# ]
# ///

# Convert m4b audiobooks to mp3 with chapter support
# From https://github.com/enzotito/m4b2mp3/blob/main/m4b2mp3.py
# Authors: MiniMax-M2.1🧙‍♂️, scillidan🤡
# Usage: uv run file.py <m4b> [-o <output_dir>]

import argparse
import subprocess
import sys
import re
import logging
from pathlib import Path

try:
    from PIL import Image
except ImportError:
    print("Installing dependencies...")
    subprocess.run(
        [sys.executable, "-m", "pip", "install", "eyed3", "Pillow"], check=True
    )
    from PIL import Image


logging.basicConfig(level=logging.INFO, format="%(message)s")
logger = logging.getLogger(__name__)


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


def get_audio_info(m4b_path: Path, ffmpeg_path: Path) -> str:
    """Extract audio info from m4b file using ffmpeg."""
    cmd = [str(ffmpeg_path), "-i", str(m4b_path), "-hide_banner"]
    result = subprocess.run(cmd, capture_output=True, text=True)
    return result.stderr + result.stdout


def extract_cover_art(m4b_path: Path, output_dir: Path, ffmpeg_path: Path) -> Path:
    """Extract cover art from m4b file."""
    cover_path = output_dir / "cover.jpg"

    if not cover_path.exists():
        result = subprocess.run(
            [str(ffmpeg_path), "-i", str(m4b_path), str(cover_path)],
            capture_output=True,
            text=True,
        )
        if result.returncode != 0 and not cover_path.exists():
            raise RuntimeError("Could not extract cover art from m4b file")

    return cover_path


def create_default_cover(output_dir: Path) -> Path:
    """Create a default cover art image."""
    cover_path = output_dir / "cover.jpg"

    img = Image.new("RGB", (300, 300), color="#1a1a2e")
    img.save(cover_path)
    return cover_path


def tag_mp3_with_cover(mp3_path: Path, cover_path: Path) -> None:
    """Tag mp3 file with cover art."""
    import eyed3
    from eyed3.id3.frames import ImageFrame

    audio = eyed3.load(str(mp3_path))
    if audio.tag is None:
        audio.initTag()

    with open(cover_path, "rb") as f:
        audio.tag.images.set(ImageFrame.FRONT_COVER, f.read(), "image/jpeg")
    audio.tag.save(version=eyed3.id3.ID3_V2_3)


def convert_chapter(
    m4b_path: Path,
    output_path: Path,
    start_time: str,
    end_time: str,
    ffmpeg_path: Path,
    cover_path: Path,
) -> None:
    """Convert a single chapter from m4b to mp3."""
    cmd = [
        str(ffmpeg_path),
        "-y",
        "-ss",
        start_time,
        "-to",
        end_time,
        "-i",
        str(m4b_path),
        "-i",
        str(cover_path),
        "-acodec",
        "libmp3lame",
        str(output_path),
    ]
    subprocess.run(cmd, capture_output=True, check=True)


def convert_single_track(
    m4b_path: Path, output_path: Path, ffmpeg_path: Path, cover_path: Path
) -> None:
    """Convert entire m4b to single mp3."""
    cmd = [
        str(ffmpeg_path),
        "-y",
        "-i",
        str(m4b_path),
        "-i",
        str(cover_path),
        "-acodec",
        "libmp3lame",
        str(output_path),
    ]
    subprocess.run(cmd, capture_output=True, check=True)


def m4b_to_mp3(input_file: Path, output_dir: Path | None = None) -> None:
    """Main conversion function."""
    ffmpeg_path = find_ffmpeg()

    if not input_file.exists():
        raise FileNotFoundError(f"Input file not found: {input_file}")

    if input_file.suffix.lower() != ".m4b":
        raise ValueError(f"Input file must be .m4b format: {input_file}")

    if output_dir is None:
        output_dir = input_file.parent / input_file.stem
    output_dir = Path(output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    logger.info(f"Processing: {input_file.name}")
    logger.info(f"Output directory: {output_dir}")

    info_text = get_audio_info(input_file, ffmpeg_path)

    chapter_pattern = re.compile(
        r"Chapter #\d+:\d+: start ([\d\.]+), end ([\d\.]+).*?title\s*:\s*(.+?)\s*$",
        re.MULTILINE | re.DOTALL,
    )
    chapters = []
    for match in chapter_pattern.finditer(info_text):
        start_time = match.group(1)
        end_time = match.group(2)
        title = match.group(3).strip()
        chapters.append((start_time, end_time, title))

    try:
        cover_path = extract_cover_art(input_file, output_dir, ffmpeg_path)
    except RuntimeError:
        logger.warning("No cover art found in m4b, creating default...")
        cover_path = create_default_cover(output_dir)

    if not chapters:
        logger.info("No chapters found, converting as single track...")
        output_path = output_dir / "Chapter 01.mp3"
        convert_single_track(input_file, output_path, ffmpeg_path, cover_path)
        tag_mp3_with_cover(output_path, cover_path)
        logger.info(f"Created: {output_path.name}")
    else:
        num_chapters = len(chapters)
        logger.info(f"Found {num_chapters} chapters")

        for idx, (start_time, end_time, title) in enumerate(chapters, 1):
            safe_title = "".join(c for c in title if c.isalnum() or c in " _-").strip()
            output_name = f"Chapter {idx:02d} - {safe_title}.mp3"
            output_path = output_dir / output_name

            convert_chapter(
                input_file, output_path, start_time, end_time, ffmpeg_path, cover_path
            )
            tag_mp3_with_cover(output_path, cover_path)

            logger.info(f"Chapter {idx}/{num_chapters}: {output_name}")

    logger.info("Conversion complete!")


def main():
    parser = argparse.ArgumentParser(
        description="Convert m4b audiobooks to mp3 with chapter support.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  uv run m4b_to_mp3 book.m4b
  uv run m4b_to_mp3 book.m4b -o /path/to/output
  uv run m4b_to_mp3 "path/to/book.m4b" --output "C:\\output"
        """,
    )
    parser.add_argument("input", type=Path, help="Input m4b file")
    parser.add_argument(
        "-o",
        "--output",
        type=Path,
        default=None,
        help="Output directory (default: <input>/<input_name>/)",
    )
    parser.add_argument(
        "-v", "--verbose", action="store_true", help="Enable verbose output"
    )

    args = parser.parse_args()

    if args.verbose:
        logging.getLogger().setLevel(logging.DEBUG)

    try:
        m4b_to_mp3(args.input, args.output)
    except Exception as e:
        logger.error(f"Error: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
