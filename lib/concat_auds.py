# Generate chapters, concat audio, and merge .lrc
# Authors: MiniMax-M2.1🧙‍♂️, scillidan🤡
# Usage: python file.py --chapters --concat --lyrics <dir>

import sys
import argparse
import subprocess
from pathlib import Path
from typing import List, Tuple, Dict

AUDIO_EXTENSIONS = {
    ".mp3",
    ".wav",
    ".flac",
    ".aac",
    ".m4a",
    ".m4b",
    ".ogg",
    ".opus",
    ".wma",
}
LRC_EXTENSIONS = {".lrc"}


def get_duration(file_path: Path) -> float:
    """Get audio duration in seconds"""
    result = subprocess.run(
        [
            "ffprobe",
            "-v",
            "error",
            "-show_entries",
            "format=duration",
            "-of",
            "default=noprint_wrappers=1:nokey=1",
            str(file_path),
        ],
        capture_output=True,
        text=True,
    )
    return float(result.stdout.strip())


def format_time_chapters(seconds: float) -> str:
    """Format as HH:MM:SS"""
    h = int(seconds) // 3600
    m = (int(seconds) % 3600) // 60
    s = int(seconds) % 60
    return f"{h:02d}:{m:02d}:{s:02d}"


def format_time_srt(seconds: float) -> str:
    """Format as HH:MM:SS,mmm"""
    h = int(seconds) // 3600
    m = (int(seconds) % 3600) // 60
    s = int(seconds) % 60
    ms = int((seconds - int(seconds)) * 1000)
    return f"{h:02d}:{m:02d}:{s:02d},{ms:03d}"


def parse_lrc(file_path: Path) -> List[Tuple[float, str]]:
    """Parse lrc file, return list of (timestamp, text)"""
    lines = []
    with open(file_path, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if line.startswith("[") and "]" in line:
                time_str = line[1 : line.index("]")]
                text = line[line.index("]") + 1 :]
                try:
                    parts = time_str.split(":")
                    minutes = float(parts[0])
                    seconds = float(parts[1])
                    timestamp = minutes * 60 + seconds
                    if text:
                        lines.append((timestamp, text))
                except (ValueError, IndexError):
                    continue
    return lines


def merge_lrc_to_srt(
    lrc_files: List[Path], audio_files: List[Path], srt_path: Path
) -> None:
    """Merge multiple lrc files into a single srt file"""
    all_subtitles = []
    accumulated_time = 0.0

    for lrc_file, audio_file in zip(lrc_files, audio_files):
        track_duration = get_duration(audio_file)
        lrc_lines = parse_lrc(lrc_file)

        for i, (start_ts, text) in enumerate(lrc_lines):
            adjusted_start = accumulated_time + start_ts
            if i + 1 < len(lrc_lines):
                next_start_ts = lrc_lines[i + 1][0]
                adjusted_end = accumulated_time + next_start_ts
            else:
                adjusted_end = adjusted_start + 3.0
            adjusted_end = min(adjusted_end, accumulated_time + track_duration)
            all_subtitles.append((adjusted_start, adjusted_end, text))

        accumulated_time += track_duration

    with open(srt_path, "w", encoding="utf-8") as f:
        for idx, (start, end, text) in enumerate(all_subtitles, 1):
            f.write(f"{idx}\n")
            f.write(f"{format_time_srt(start)} --> {format_time_srt(end)}\n")
            f.write(f"{text}\n\n")


def merge_lang_lrc(
    lrc_files: List[Path], audio_files: List[Path], output_path: Path
) -> None:
    """Merge language-specific lrc files into a single lrc file"""
    merged_lines = []
    accumulated_time = 0.0

    for lrc_file, audio_file in zip(lrc_files, audio_files):
        lrc_lines = parse_lrc(lrc_file)
        for start_ts, text in lrc_lines:
            adjusted_start = accumulated_time + start_ts
            merged_lines.append((adjusted_start, text))
        accumulated_time += get_duration(audio_file)

    with open(output_path, "w", encoding="utf-8") as f:
        for start, text in merged_lines:
            minutes = int(start) // 60
            seconds = start % 60
            f.write(f"[{minutes:02d}:{seconds:05.2f}]{text}\n")


def generate_chapters(
    audio_files: List[Path], output_path: Path
) -> List[Tuple[str, str]]:
    """Generate chapter file from audio files, return chapters list"""
    accumulated_time = 0.0
    chapters = []

    for idx, audio_file in enumerate(audio_files, 1):
        timestamp = format_time_chapters(accumulated_time)
        title = (
            audio_file.stem.split(".", 1)[-1].strip()
            if "." in audio_file.stem
            else audio_file.stem
        )
        chapters.append((timestamp, title))
        accumulated_time += get_duration(audio_file)
        print(f"OK: {audio_file.name}")

    with open(output_path, "w", encoding="utf-8") as f:
        lines = [
            f"{timestamp} {idx:02d}. {title}"
            for idx, (timestamp, title) in enumerate(chapters, 1)
        ]
        f.write("\n".join(lines))

    print(f"\nChapters saved to: {output_path}")
    print(f"Total chapters: {len(chapters)}")
    return chapters


import shutil
import re


def sanitize_filename(name: str) -> str:
    """Replace problematic characters for file paths"""
    name = name.replace(":", "-")
    name = name.replace("'", "'")
    name = name.replace('"', "-")
    name = name.replace("<", "-")
    name = name.replace(">", "-")
    name = name.replace("|", "-")
    return name


def concat_audio(audio_files: List[Path], output_path: Path) -> None:
    """Concat audio files using ffmpeg concat demuxer"""
    temp_dir = output_path.parent / "_temp"
    temp_dir.mkdir(exist_ok=True)

    temp_files = []
    try:
        for i, audio_file in enumerate(audio_files, 1):
            ext = audio_file.suffix
            temp_name = f"{i:02d}{ext}"
            temp_path = temp_dir / temp_name
            shutil.copy2(audio_file, temp_path)
            temp_files.append(temp_path)

        temp_list = temp_dir / "_concat_list.txt"
        with open(temp_list, "w", encoding="utf-8") as f:
            for temp_file in temp_files:
                f.write(f"file '{temp_file}'\n")

        subprocess.run(
            [
                "ffmpeg",
                "-y",
                "-f",
                "concat",
                "-safe",
                "0",
                "-i",
                str(temp_list),
                "-codec:a",
                "libmp3lame",
                "-qscale:a",
                "1",
                str(output_path),
            ],
            check=True,
        )
        print(f"Concat saved to: {output_path}")
    finally:
        shutil.rmtree(temp_dir, ignore_errors=True)


def generate_typst(
    audio_files: List[Path],
    chapters: List[Tuple[str, str]],
    lrc_groups: Dict[str, List[Path]],
    output_path: Path,
) -> None:
    """Generate Typst template file"""
    dir_name = output_path.stem

    with open(output_path, "w", encoding="utf-8") as f:
        f.write('#import "@preview/cute:1.0.0": *\n\n')

        f.write(f'#let song = "{dir_name}"\n')
        f.write(f'#let input-path = sys.inputs.at("path", default: song)\n')
        f.write(f'#let name-only = input-path.split("/").last().split(".").first()\n')
        f.write(f'#let cover-image = name-only + "_cover.jpg"\n\n')

        f.write("#let metadata = (\n")
        f.write(f'  title: "{chapters[0][1] if chapters else ""}",\n')
        artist = dir_name.split(" - ")[0] if " - " in dir_name else ""
        f.write(f'  artist: "{artist}",\n')
        f.write(f'  album: "{dir_name}",\n')
        f.write("  year: 2025,\n")
        f.write('  genre: "J-Pop",\n')
        f.write("  cover: cover-image\n")
        f.write(")\n\n")

        f.write("#let styles = (\n")
        f.write('  bg-color: rgb("#1a1a2e"),\n')
        f.write('  text-color: rgb("#eaeaea"),\n')
        f.write('  accent-color: rgb("#e94560"),\n')
        f.write('  secondary-color: rgb("#16213e"),\n')
        f.write("  font-size: 12pt,\n")
        f.write("  line-height: 1.5,\n")
        f.write(")\n\n")

        f.write("#let audio-files = (\n")
        for audio_file in audio_files:
            title = audio_file.stem.split(".", 1)[-1].strip()
            f.write(f'  "{title}",\n')
        f.write(")\n\n")

        f.write("#let chapters = (\n")
        for ts, title in chapters:
            f.write(f'  (time: "{ts}", title: "{title}"),\n')
        f.write(")\n\n")

        for lang, files in lrc_groups.items():
            if not files:
                continue
            lang_var = f"lrc{lang.replace('.', '')}" if lang else "lrc"
            f.write(f"#let {lang_var} = (\n")
            accumulated_time = 0.0
            for lrc_file, audio_file in zip(files, audio_files):
                lrc_lines = parse_lrc(lrc_file)
                for ts, text in lrc_lines:
                    adjusted = accumulated_time + ts
                    m = int(adjusted) // 60
                    s = adjusted % 60
                    f.write(f'  (time: "{m:02d}:{s:05.2f}", text: "{text}"),\n')
                accumulated_time += get_duration(audio_file)
            f.write(")\n\n")

        f.write("#show: doc => CTemplate(\n")
        f.write("  title: metadata.title,\n")
        f.write("  artist: metadata.artist,\n")
        f.write("  album: metadata.album,\n")
        f.write("  year: metadata.year,\n")
        f.write("  cover: metadata.cover,\n")
        f.write("  bg-color: styles.bg-color,\n")
        f.write("  text-color: styles.text-color,\n")
        f.write("  accent-color: styles.accent-color,\n")
        f.write("  secondary-color: styles.secondary-color,\n")
        f.write("  font-size: styles.font-size,\n")
        f.write("  line-height: styles.line-height,\n")
        f.write("  doc\n")
        f.write(")\n\n")

        if chapters:
            f.write(f"= {chapters[0][1]}\n\n")

        f.write("== Tracklist\n\n")
        f.write("#for (i, chapter) in chapters.enumerate() {\n")
        f.write("  box(inset: (x: 0pt, y: 4pt))[\n")
        f.write("    #strong[(#{i + 1}. )]#chapter.title\n")
        f.write("  ]\n")
        f.write("}\n\n")

        f.write("== Chapters\n\n")
        f.write("#table(\n")
        f.write("  columns: (auto, 1fr),\n")
        f.write("  align: (left, left),\n")
        f.write("  stroke: none,\n")
        f.write("  ..chapters.map(c => (c.time, c.title)).flatten()\n")
        f.write(")\n\n")

        for lang, files in lrc_groups.items():
            if not files:
                continue
            lang_name = f" ({lang.replace('.', '').upper()})" if lang else ""
            lang_var = f"lrc{lang.replace('.', '')}" if lang else "lrc"
            f.write(f"== Lyrics{lang_name}\n\n")
            f.write(f"#for line in {lang_var} {{\n")
            f.write("  #line.time #line.text\n")
            f.write("}\n")

    print(f"Typst template saved to: {output_path}")


def main():
    parser = argparse.ArgumentParser(
        description="Generate chapters, concat audio, and merge lrc"
    )
    parser.add_argument("input_dir", help="Directory containing audio and lrc files")
    parser.add_argument(
        "--chapters",
        action="store_true",
        help="Generate chapter file (default: <dirname>.mp3.chp)",
    )
    parser.add_argument(
        "--concat",
        action="store_true",
        help="Generate concatenated audio file (default: <dirname>.mp3)",
    )
    parser.add_argument(
        "--lyrics",
        action="store_true",
        help="Generate srt and merged lrc files (default: <dirname>.srt and <dirname>.<lang>.lrc)",
    )
    parser.add_argument(
        "--typst",
        action="store_true",
        help="Generate Typst template file (default: <dirname>.typ)",
    )
    args = parser.parse_args()

    input_dir = Path(args.input_dir)
    if not input_dir.is_dir():
        print(f"Error: {input_dir} is not a directory")
        sys.exit(1)

    audio_files = sorted(
        [
            f
            for f in input_dir.iterdir()
            if f.is_file() and f.suffix.lower() in AUDIO_EXTENSIONS
        ]
    )

    lrc_files = []
    lrc_lang_files = {}
    known_langs = {".chs", ".eng", ".cht", ".jp", ".sc", ".tc"}

    for f in input_dir.iterdir():
        if not f.is_file() or f.suffix.lower() != ".lrc":
            continue
        lrc_stem = f.stem
        lrc_suffix = ""
        for lang in known_langs:
            if lrc_stem.endswith(lang):
                lrc_suffix = lang
                break
        if lrc_suffix:
            lang_code = "." + lrc_suffix.replace(".", "")
            if lang_code not in lrc_lang_files:
                lrc_lang_files[lang_code] = []
            lrc_lang_files[lang_code].append(f)
        else:
            lrc_files.append(f)

    lrc_files = sorted(lrc_files)
    for lang in lrc_lang_files:
        lrc_lang_files[lang] = sorted(lrc_lang_files[lang])

    if not audio_files:
        print("Error: No audio files found")
        sys.exit(1)

    chapters = []
    if args.chapters or args.typst:
        chapters_path = Path.cwd() / f"{input_dir.name}.mp3.chp"
        chapters = generate_chapters(audio_files, chapters_path)

    if args.concat:
        concat_path = Path.cwd() / f"{input_dir.name}.mp3"
        concat_audio(audio_files, concat_path)

    if args.lyrics:
        all_lrc_groups = {"": lrc_files}
        for lang, files in lrc_lang_files.items():
            all_lrc_groups[lang] = files
        for lang, files in all_lrc_groups.items():
            if not files:
                continue
            base_name = f"{input_dir.name}{lang}" if lang else input_dir.name
            srt_path = Path.cwd() / f"{base_name}.srt"
            lrc_path = Path.cwd() / f"{base_name}.lrc"
            merge_lrc_to_srt(files, audio_files, srt_path)
            merge_lang_lrc(files, audio_files, lrc_path)

    if args.typst:
        typst_path = Path.cwd() / f"{input_dir.name}.typ"
        lrc_groups = {"": lrc_files}
        lrc_groups.update(lrc_lang_files)
        generate_typst(audio_files, chapters, lrc_groups, typst_path)

    if not any([args.chapters, args.concat, args.lyrics, args.typst]):
        print(
            "Error: Please specify at least one of --chapters, --concat, --lyrics, --typst"
        )
        sys.exit(1)


if __name__ == "__main__":
    main()
