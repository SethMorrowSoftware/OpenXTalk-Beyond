#!/usr/bin/env python3
"""Build the two fonts that HTML5 standalones draw text with.

Writes `DroidSansCombined.ttf` (regular) and `DroidSansCombined-Bold.ttf`
(bold) for `engine/rsrc/emscripten-standalone-template/boot/standalone/`.
Both are the font family "Droid Sans", so a stack that asks for bold text
gets the bold one, and an unknown font name falls back to the same family
in the asked-for style (the custom font list in `customfont.cpp` and
Skia's font folder `/boot/standalone/` both match by family and style).

Why it is built rather than copied: the file LiveCode's HTML5 standalones
came with (Droid Sans with the CJK characters of Droid Sans Fallback added)
carried Ascender Corporation's commercial font licence in its licence
field, and had no bold. These are made only from sources whose own files
say what licence they are under:

- Droid Sans and Droid Sans Bold, builds 113 and 112, from the Android
  Open Source Project: Apache License 2.0 (in their licence field). Their
  Latin, Greek and Cyrillic advance widths are those of the old file, so
  text wraps where it did.
- Droid Sans Fallback 2.55b, from AOSP: Apache License 2.0. The Chinese,
  Japanese and Korean characters, at the old file's widths.
- The old file also had about 400 symbols (arrows, box drawing, circled
  numbers, maths, pinyin tone marks, CJK angle brackets) that neither of
  those has. So that no character the old file drew stops drawing, they
  come from DejaVu Sans (Bitstream Vera licence and public domain) or,
  where DejaVu has none, Noto Sans CJK SC (SIL Open Font License 1.1).
  Because the OFL covers a font "in part or in whole", the combined files
  are distributed under the OFL 1.1, with the Apache and Bitstream Vera
  notices kept for the parts they cover (THIRD-PARTY-NOTICES.md).

The sources are files of Ubuntu 24.04 packages, pinned by SHA-256 below.
To rebuild, on Linux with fontTools 4.67 (`pip install fonttools==4.67.0`):

    mkdir src && cd src
    apt-get download mythtv-common fonts-droid-fallback fonts-noto-cjk fonts-dejavu-core
    for d in *.deb; do dpkg-deb -x "$d" x; done
    cd ..
    python3 tools/oxt/build_web_fonts.py src/x            # write the two files
    python3 tools/oxt/build_web_fonts.py src/x --check    # fail if they differ

The output is byte-for-byte the same on every run (no timestamps).
"""

import argparse
import hashlib
import io
import os
import sys

from fontTools.ttLib import TTCollection, TTFont, newTable
from fontTools.ttLib.scaleUpem import scale_upem
from fontTools.merge import Merger
from fontTools.pens.cu2quPen import Cu2QuPen
from fontTools.pens.ttGlyphPen import TTGlyphPen
from fontTools.subset import Options, Subsetter

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
OUT_DIR = os.path.join(ROOT, "engine", "rsrc", "emscripten-standalone-template",
                       "boot", "standalone")

# path inside the extracted packages -> SHA-256 of the file
SOURCES = {
    "droid": ("usr/share/mythtv/fonts/DroidSans.ttf",
              "4e2371bc0e4cf6983342e150412f140da79d674c9be0b56458401f581072ecd3"),
    "droid-bold": ("usr/share/mythtv/fonts/DroidSans-Bold.ttf",
                   "b631b677af5aa7316297a8b56a1fe3bb1da706737f8c9785d5a5fc94faae1ea9"),
    "fallback": ("usr/share/fonts-droid-fallback/truetype/DroidSansFallback.ttf",
                 "56d3edfb377a8bc3c4b77f4476405c770173c0e31221ad7c77d0a8e1f3039a3e"),
    "dejavu": ("usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
               "ae7b7855e115a5966d8b1b3f80f254ccc117ec86f9965e202ee2940453837280"),
    "dejavu-bold": ("usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
                    "5c1247acef7f2b8522a31742c76d6adcb5569bacc0be7ceaa4dc39dd252ce895"),
    "noto": ("usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc",
             "b76b0433203017ca80401b2ee0dd69350349871c4b19d504c34dbdd80541690a"),
    "noto-bold": ("usr/share/fonts/opentype/noto/NotoSansCJK-Bold.ttc",
                  "faa5f3656a78b2e2d450d27fe8382c778bc2b6bb5ea29c986664a6a435056ceb"),
}
NOTO_SC = 2  # the face of the collections: Noto Sans CJK SC

# The characters the old DroidSansCombined.ttf drew that neither Droid Sans
# nor Droid Sans Fallback 2.55b has (taken from that file's cmap).
LEGACY_SYMBOLS = [
    0x01CE, 0x01D0, 0x01D2, 0x01D4, 0x01D6, 0x01D8, 0x01DA, 0x01DC, (0x02CA, 0x02CB),
    0x02CD, 0x02D0, 0x2010, 0x2016, 0x2025, 0x2027, 0x2035, 0x203B, 0x2074,
    (0x2081, 0x2084), 0x2103, 0x2109, 0x2121, 0x212B, (0x2153, 0x2154),
    (0x2160, 0x216B), (0x2170, 0x2179), (0x2190, 0x2199), 0x21D2, 0x21D4, 0x2200,
    0x2203, (0x2207, 0x2208), 0x220B, 0x2215, 0x221D, (0x221F, 0x2220), 0x2223,
    0x2225, (0x2227, 0x222A), 0x222C, 0x222E, (0x2234, 0x2237), (0x223C, 0x223D),
    0x224C, 0x2252, 0x2261, (0x2266, 0x2267), (0x226A, 0x226B), (0x226E, 0x226F),
    (0x2282, 0x2283), (0x2286, 0x2287), 0x2295, 0x2299, 0x22A5, 0x22BF, 0x2312,
    (0x2460, 0x24B5), (0x24D0, 0x24E9), (0x2500, 0x254B), (0x2550, 0x2574),
    (0x2581, 0x258F), (0x2592, 0x2595), (0x25A0, 0x25A1), (0x25A3, 0x25A9),
    (0x25B2, 0x25B3), (0x25B6, 0x25B7), (0x25BC, 0x25BD), (0x25C0, 0x25C1),
    (0x25C6, 0x25C8), 0x25CB, (0x25CE, 0x25D1), (0x25E2, 0x25E5), 0x25EF,
    (0x2605, 0x2606), (0x260E, 0x260F), 0x261C, 0x261E, 0x2640, 0x2642,
    (0x2660, 0x2661), (0x2663, 0x2665), (0x2667, 0x266A), (0x266C, 0x266D), 0x266F,
    (0x3008, 0x3009),
]

# Tables every part keeps, so that the parts merge. Hinting tables stay only
# in the first (Droid Sans) part, as the old file had them.
PART_TABLES = {"cmap", "glyf", "loca", "head", "hhea", "hmtx", "maxp", "name",
               "post", "OS/2"}

LICENSE_TEXT = (
    "This font is licensed under the SIL Open Font License, Version 1.1. "
    "It is made from Droid Sans and Droid Sans Fallback (Copyright 2006-2007 "
    "Google Corporation, Licensed under the Apache License, Version 2.0), "
    "with symbols from DejaVu Sans (Bitstream Vera Fonts Copyright 2003 "
    "Bitstream, Inc.; DejaVu changes are in the public domain) and Noto Sans "
    "CJK (Copyright 2014-2021 Adobe, SIL Open Font License, Version 1.1).")
LICENSE_URL = "https://openfontlicense.org"
VERSION_SUFFIX = "; OXT-Beyond web font 1"


def codepoints(spec):
    for item in spec:
        if isinstance(item, tuple):
            yield from range(item[0], item[1] + 1)
        else:
            yield item


def load(sources_dir, key, index=None):
    rel, digest = SOURCES[key]
    path = os.path.join(sources_dir, rel)
    with open(path, "rb") as f:
        data = f.read()
    if hashlib.sha256(data).hexdigest() != digest:
        sys.exit(f"{path}: SHA-256 is not the pinned {digest}")
    if index is None:
        return TTFont(io.BytesIO(data), recalcTimestamp=False)
    return TTCollection(io.BytesIO(data)).fonts[index]


def keep_tables(font, tables):
    for tag in list(font.keys()):
        if tag != "GlyphOrder" and tag not in tables:
            del font[tag]


def subset(font, chars):
    options = Options()
    options.layout_features = []
    options.name_IDs = ["*"]
    options.notdef_outline = True
    options.recalc_timestamp = False
    subsetter = Subsetter(options)
    subsetter.populate(unicodes=chars)
    subsetter.subset(font)


def to_truetype(font):
    """Replace a CFF font's outlines with TrueType quadratic ones."""
    glyph_set = font.getGlyphSet()
    glyf = newTable("glyf")
    glyf.glyphOrder = font.getGlyphOrder()
    glyf.glyphs = {}
    for name in glyf.glyphOrder:
        pen = TTGlyphPen(glyph_set)
        glyph_set[name].draw(Cu2QuPen(pen, max_err=1.0, reverse_direction=True))
        glyf.glyphs[name] = pen.glyph()
    font["glyf"] = glyf
    font["loca"] = newTable("loca")
    del font["CFF "]
    font["maxp"] = maxp = newTable("maxp")
    maxp.tableVersion = 0x00010000
    for attr in ("maxZones", "maxTwilightPoints", "maxStorage", "maxFunctionDefs",
                 "maxInstructionDefs", "maxStackElements", "maxSizeOfInstructions"):
        setattr(maxp, attr, 0 if attr != "maxZones" else 1)
    maxp.numGlyphs = len(glyf.glyphOrder)
    font["post"].formatType = 2.0
    font["post"].extraNames = []
    font["post"].mapping = {}
    font["post"].glyphOrder = glyf.glyphOrder
    font.sfntVersion = "\x00\x01\x00\x00"
    font["head"].glyphDataFormat = 0
    return font


def part_bytes(font):
    buffer = io.BytesIO()
    font.save(buffer)
    return io.BytesIO(buffer.getvalue())


def build(sources_dir, bold):
    suffix = "-bold" if bold else ""
    base = load(sources_dir, "droid" + suffix)
    for tag in ("LTSH", "hdmx"):
        del base[tag]
    base_chars = set(base.getBestCmap())

    fallback = load(sources_dir, "fallback")
    keep_tables(fallback, PART_TABLES | {"cvt ", "fpgm", "prep", "gasp"})
    scale_upem(fallback, 2048)
    fallback_chars = set(fallback.getBestCmap())

    wanted = [c for c in codepoints(LEGACY_SYMBOLS)
              if c not in base_chars and c not in fallback_chars]
    dejavu = load(sources_dir, "dejavu" + suffix)
    dejavu_chars = sorted(set(wanted) & set(dejavu.getBestCmap()))
    noto = load(sources_dir, "noto" + suffix, NOTO_SC)
    noto_chars = sorted(set(wanted) - set(dejavu_chars))
    missing = sorted(set(noto_chars) - set(noto.getBestCmap()))
    if missing:
        sys.exit("no source has " + ", ".join("U+%04X" % c for c in missing))

    subset(dejavu, dejavu_chars)
    keep_tables(dejavu, PART_TABLES)
    subset(noto, noto_chars)
    keep_tables(noto, PART_TABLES | {"CFF "})
    to_truetype(noto)
    scale_upem(noto, 2048)
    keep_tables(noto, PART_TABLES)

    parts = [part_bytes(base), part_bytes(fallback), part_bytes(dejavu), part_bytes(noto)]
    merged = Merger().merge(parts)

    # Merging takes the largest ascent and descent of the parts (Noto's
    # are larger); lines keep Droid Sans' height and baseline, as in the
    # old file
    for attr in ("ascent", "descent", "lineGap"):
        setattr(merged["hhea"], attr, getattr(base["hhea"], attr))
    for attr in ("sTypoAscender", "sTypoDescender", "sTypoLineGap", "usWinAscent",
                 "usWinDescent", "sxHeight", "sCapHeight"):
        setattr(merged["OS/2"], attr, getattr(base["OS/2"], attr))

    name = merged["name"]
    for record in list(name.names):
        if record.nameID in (13, 14):
            name.removeNames(nameID=record.nameID)
    for record in list(name.names):
        if record.nameID == 5 and VERSION_SUFFIX not in str(record):
            name.setName(str(record) + VERSION_SUFFIX, 5, record.platformID,
                         record.platEncID, record.langID)
    for platform, encoding, language in ((1, 0, 0), (3, 1, 0x409)):
        name.setName(LICENSE_TEXT, 13, platform, encoding, language)
        name.setName(LICENSE_URL, 14, platform, encoding, language)
    # The dates of Droid Sans itself, so that every build is the same
    merged["head"].created = base["head"].created
    merged["head"].modified = base["head"].modified
    merged.recalcTimestamp = False

    check(base, fallback, merged)
    buffer = io.BytesIO()
    merged.save(buffer)
    return buffer.getvalue(), len(dejavu_chars), len(noto_chars)


def check(base, fallback, merged):
    """Every character of Droid Sans and the fallback keeps its width."""
    out_cmap = merged.getBestCmap()
    out_hmtx = merged["hmtx"]
    for part in (base, fallback):
        for char, glyph in part.getBestCmap().items():
            if char in out_cmap and out_hmtx[out_cmap[char]][0] != part["hmtx"][glyph][0]:
                if part is base or char not in base.getBestCmap():
                    sys.exit("U+%04X changed width" % char)
    for table, attrs in (("hhea", ("ascent", "descent", "lineGap")),
                         ("OS/2", ("sTypoAscender", "sTypoDescender", "sTypoLineGap",
                                   "usWinAscent", "usWinDescent"))):
        for attr in attrs:
            if getattr(merged[table], attr) != getattr(base[table], attr):
                sys.exit("the %s %s is not Droid Sans'" % (table, attr))
    for char in codepoints(LEGACY_SYMBOLS):
        if char not in out_cmap:
            sys.exit("U+%04X is missing" % char)


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("sources", help="folder the packages were extracted into")
    parser.add_argument("--check", action="store_true",
                        help="fail if the committed files differ from a fresh build")
    parser.add_argument("--out", default=OUT_DIR, help="folder to write to")
    args = parser.parse_args()

    status = 0
    for bold, file_name in ((False, "DroidSansCombined.ttf"),
                            (True, "DroidSansCombined-Bold.ttf")):
        data, from_dejavu, from_noto = build(args.sources, bold)
        path = os.path.join(args.out, file_name)
        if args.check:
            with open(path, "rb") as f:
                if f.read() != data:
                    print(f"{path} is not what this script builds")
                    status = 1
        else:
            with open(path, "wb") as f:
                f.write(data)
            print(f"{path}: {len(data)} bytes, {from_dejavu} symbols from "
                  f"DejaVu Sans, {from_noto} from Noto Sans CJK SC")
    return status


if __name__ == "__main__":
    sys.exit(main())
