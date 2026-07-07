# /// script
# requires-python = ">=3.10"
# dependencies = [
#     "fonttools",
# ]
# ///

# fonttools_ttfs — Print TTF font metadata (font-family, font-weight, font-style)

SHOW_COPYRIGHT = False
SHOW_VERSION = False

import sys
from fontTools.ttLib import TTFont

WEIGHT_MAP = {
    100: "Thin",
    200: "ExtraLight",
    300: "Light",
    400: "Regular",
    500: "Medium",
    600: "SemiBold",
    700: "Bold",
    800: "ExtraBold",
    900: "Black",
}


def get_name_record(ttf, name_id):
    for record in ttf["name"].names:
        if record.nameID == name_id:
            try:
                return record.toUnicode()
            except (UnicodeDecodeError, AttributeError):
                try:
                    return record.string.decode("utf-16-be")
                except (UnicodeDecodeError, AttributeError):
                    return record.string.decode("latin-1", errors="replace")
    return ""


def get_font_weight(ttf):
    os2 = ttf.get("OS/2")
    if os2 and os2.usWeightClass:
        w = os2.usWeightClass
        label = WEIGHT_MAP.get(w)
        if label:
            return f"{w} ({label})"
        return str(w)
    return ""


def get_font_style(ttf):
    mac = ttf["head"].macStyle
    is_bold = bool(mac & 1)
    is_italic = bool(mac & 2)
    if is_bold and is_italic:
        return "Bold Italic"
    elif is_bold:
        return "Bold"
    elif is_italic:
        return "Italic"
    return "Normal"


def main():
    if len(sys.argv) < 2:
        print("Usage: python fonttools_ttfs.py <ttf_file> [ttf_file ...]")
        sys.exit(1)

    error = 0
    for path in sys.argv[1:]:
        try:
            ttf = TTFont(path)
            family = get_name_record(ttf, 1) or get_name_record(ttf, 16)
            subfamily = get_name_record(ttf, 2) or get_name_record(ttf, 17)
            full_name = get_name_record(ttf, 4)
            version = get_name_record(ttf, 5)
            copyright = get_name_record(ttf, 0)
            weight = get_font_weight(ttf)
            style = get_font_style(ttf)
            ttf.close()
            print(f"{path}")
            if SHOW_COPYRIGHT:
                print(f"  copyright     : {copyright}")
            print(f"  full-name     : {full_name}")
            print(f"  font-family   : {family}")
            print(f"  font-subfamily: {subfamily}")
            print(f"  font-weight   : {weight}")
            print(f"  font-style    : {style}")
            if SHOW_VERSION:
                print(f"  version       : {version}")
            print()
        except Exception as e:
            print(f"Error reading {path}: {e}", file=sys.stderr)
            error = 1

    if error:
        sys.exit(1)


if __name__ == "__main__":
    main()
