#!/usr/bin/env python3
"""Build the desktop fonts that an HTML5 standalone can carry.

Writes twelve files into `engine/rsrc/emscripten-desktop-fonts/`: Arimo,
Tinos and Cousine, plain, bold, italic and bold italic. They are Google's
Croscore fonts, whose glyphs are as wide as those of Arial, Times New Roman
and Courier New, so text drawn in them wraps where it wraps on a desktop.
The web engine draws the desktop names (Arial, Helvetica, Geneva, Times,
New York, Courier, Monaco and the rest of the table in
`engine/src/em-font.cpp`) in them when a standalone carries them: the
Web pane's "Desktop fonts" setting, and the Stack Player. Without them,
text draws in Droid Sans, as before.

The sources are the files of Ubuntu 24.04's `fonts-croscore` package
(version 20201225-2), pinned by SHA-256 below. They are under the SIL Open
Font License 1.1 (their licence field), with no Reserved Font Name, so the
subset files keep their names and their licence. They are subset to the
scripts and symbols a desktop stack uses most (Latin, Greek, Cyrillic,
punctuation, currency, arrows and maths), and their hinting is left out
(the web engine draws without it): about a fifth of the size.

To rebuild, on Linux with fontTools 4.67 (`pip install fonttools==4.67.0`):

    mkdir src && cd src
    apt-get download fonts-croscore
    dpkg-deb -x fonts-croscore_*.deb x
    cd ..
    python3 tools/oxt/build_web_desktop_fonts.py src/x            # write the files
    python3 tools/oxt/build_web_desktop_fonts.py src/x --check    # fail if they differ

The output is byte-for-byte the same on every run (no timestamps).
"""

import argparse
import hashlib
import io
import os
import sys

from fontTools.ttLib import TTFont
from fontTools.subset import Options, Subsetter

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
OUT_DIR = os.path.join(ROOT, "engine", "rsrc", "emscripten-desktop-fonts")
SOURCE_DIR = "usr/share/fonts/truetype/croscore"

# file name -> SHA-256 of the file in fonts-croscore 20201225-2
SOURCES = {
    "Arimo-Regular.ttf": "5c315974260455a02fad62495a0ae9a783bb53f0eccf807deb75c7967e7a81d6",
    "Arimo-Bold.ttf": "10724c3733f60cdec733da1a439de9100e1593ceb219cc4d03c443bef1feb9b6",
    "Arimo-Italic.ttf": "5f4917a32312ba8a011502e2147567d678984d820223367a2a4c5d6dda2a758c",
    "Arimo-BoldItalic.ttf": "8e057ec4b127ee4242b35cf66f31b558aa46eb5e6808047324bf2a6f1e8c86a6",
    "Tinos-Regular.ttf": "cf264a22292950ca1679b2ade07e9e6ecb26c649ab70975d0e113f979efa827a",
    "Tinos-Bold.ttf": "971d6af5fcb3a0c05535a92a635fb63a86ea5eb935639c9b864be33f3bfaba80",
    "Tinos-Italic.ttf": "0f949a3fa0e23cd0ca94a0c4784bd8f9efb99c20070b9f73b5fd592b49c092ad",
    "Tinos-BoldItalic.ttf": "0cd67b90617a03a69a815e758d0649d00f2be48a0cb570615e94e8e5a13aae2e",
    "Cousine-Regular.ttf": "829e776e4929eb6467838b92c7b700085fac2073801e6b54b224661affb34688",
    "Cousine-Bold.ttf": "1f224341677c5ceaa717417d1cb94efbdb276801b3ab1ccea697eb3a8057b6ac",
    "Cousine-Italic.ttf": "64e8ed603232b28eceebe0d18838a5e62297605203b33720d775ed628cdc222b",
    "Cousine-BoldItalic.ttf": "82755a6d4b12067daabf89eb5bf48d52b9fea4073a59792d331651510a901728",
}

# The characters kept (inclusive ranges)
RANGES = [
    (0x0020, 0x007E),  # ASCII
    (0x00A0, 0x024F),  # Latin-1, Latin Extended-A and -B
    (0x0250, 0x02FF),  # IPA, spacing modifiers
    (0x0300, 0x036F),  # combining marks
    (0x0370, 0x03FF),  # Greek
    (0x0400, 0x052F),  # Cyrillic
    (0x1E00, 0x1EFF),  # Latin Extended Additional
    (0x2000, 0x206F),  # general punctuation
    (0x2070, 0x209F),  # super- and subscripts
    (0x20A0, 0x20CF),  # currency
    (0x2100, 0x214F),  # letterlike symbols
    (0x2150, 0x218F),  # number forms
    (0x2190, 0x21FF),  # arrows
    (0x2200, 0x22FF),  # mathematical operators
    (0x2500, 0x257F),  # box drawing
    (0x2580, 0x259F),  # block elements
    (0x25A0, 0x25FF),  # geometric shapes
    (0xFB00, 0xFB06),  # Latin ligatures
    (0xFFFD, 0xFFFD),  # replacement character
]


def unicodes():
    out = []
    for first, last in RANGES:
        out.extend(range(first, last + 1))
    return out


def build(path):
    font = TTFont(path, recalcTimestamp=False)
    options = Options()
    options.hinting = False
    options.notdef_outline = True
    options.name_IDs = ["*"]
    options.name_languages = ["*"]
    options.layout_features = ["*"]
    options.drop_tables += ["DSIG"]
    subsetter = Subsetter(options=options)
    subsetter.populate(unicodes=unicodes())
    subsetter.subset(font)
    # The engine names a font file's font by its Macintosh full name (name
    # ID 4, platform 1, encoding 0, language 0: MCFreeTypeGetFontInfoFromData
    # in engine/src/freetype-font.cpp), and skips a file without one. The
    # Croscore files have only Windows names, so the subsets get Macintosh
    # family, subfamily and full names, copied from the Windows ones (all
    # ASCII).
    names = font["name"]
    for name_id in (1, 2, 4):
        text = names.getName(name_id, 3, 1, 0x409).toUnicode()
        names.setName(text, name_id, 1, 0, 0)
    font["head"].modified = font["head"].created
    out = io.BytesIO()
    font.save(out)
    return out.getvalue()


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("source", help="the extracted fonts-croscore package (the folder holding usr/)")
    parser.add_argument("--check", action="store_true", help="fail if the committed files differ")
    args = parser.parse_args()

    status = 0
    if not args.check:
        os.makedirs(OUT_DIR, exist_ok=True)
    for name, digest in sorted(SOURCES.items()):
        path = os.path.join(args.source, SOURCE_DIR, name)
        with open(path, "rb") as f:
            got = hashlib.sha256(f.read()).hexdigest()
        if got != digest:
            sys.exit("%s: SHA-256 %s, expected %s" % (path, got, digest))
        data = build(path)
        target = os.path.join(OUT_DIR, name)
        if args.check:
            try:
                with open(target, "rb") as f:
                    same = f.read() == data
            except OSError:
                same = False
            print("%s %s" % ("ok     " if same else "DIFFERS", name))
            if not same:
                status = 1
        else:
            with open(target, "wb") as f:
                f.write(data)
            print("wrote %s (%d bytes)" % (name, len(data)))
    return status


if __name__ == "__main__":
    sys.exit(main())
