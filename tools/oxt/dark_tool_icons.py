#!/usr/bin/env python3
# Copyright (C) 2026 OXT-Beyond contributors.
#
# This file is part of OXT-Beyond.
#
# OXT-Beyond is free software; you can redistribute it and/or modify it under
# the terms of the GNU General Public License v3 as published by the Free
# Software Foundation.
#
# OXT-Beyond is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
# details.
#
# You should have received a copy of the GNU General Public License
# along with OXT-Beyond.  If not see <http://www.gnu.org/licenses/>.

"""Make the outline icons of the dark Tools palette light.

  python tools/oxt/dark_tool_icons.py [--repo DIR] [--check]

In the dark appearance the Tools palette (generatePalette in
ide/Toolset/palettes/tools/revtools.livecodescript) takes its icons from
the "dark" folder of the platform's theme,
ide/Toolset/resources/supporting_files/themes/com.livecode.theme.*/dark.
Most of those are drawn for a dark palette, but the outline icons (GLYPHS:
the graphic shapes, the arrow, the label field and some options of the
graphic and paint tools) kept the light sets' grey strokes, 88,88,88, which
have 1.7 to 2.3:1 contrast with the dark palettes, and the line size icon of
the Windows sets is black.

For each icon in GLYPHS in a dark folder whose ink has less than
MIN_CONTRAST (3:1) with that platform's dark palette (BACKGROUNDS), this
inverts the colour of every pixel and keeps its alpha: the grey 88 becomes
167, 4.9:1 or more on each palette, and the icon's light parts become dark.
The palette also draws the icons in TOOLS on its tool highlight (orange,
unless the user picks another colour in the Preferences): the line and
select tools when they are chosen, the options under the mouse. A light
stroke does not read on orange, so those get a shadow too, as the white
arrows of the browse and pointer tools have a black edge: the canvas grows by a pixel on each
side and each transparent pixel next to the ink becomes black at
SHADOW_ALPHA, less than half, so the shadow barely shows on the dark palette
and is not ink. The icon is written as an 8-bit RGBA PNG (some were palette
PNGs, and some GIF files with a .png name); the pHYs chunk (density) of a PNG
is kept, other metadata is not. Icons with enough contrast are left as they
are, so running this again changes nothing. The palette does not use the
*.icon-hilite.png variants, so they are left as they are too.

--check writes nothing. It checks that every *.icon.png of a theme is in its
dark folder too (the dark palette looks only there), and that each icon in
GLYPHS in a dark folder has at least MIN_CONTRAST with that platform's dark
palette: the mean luminance of the icon's ink (its pixels with at least half
of its highest alpha, composited over the palette), as
tools/oxt/dark_disabled_icons.py measures it. tools/ci/check_ide_icons.py
runs this check in CI.

Standard library only (PNG and GIF decoding with zlib and struct, PNG
encoding with tools/oxt/dark_disabled_icons.py); needs Python 3.8 or later.
"""

import argparse
import os
import struct
import sys
import zlib

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import dark_disabled_icons  # noqa: E402  (found through the path above)
from dark_disabled_icons import ink_contrast, rgb, write_png  # noqa: E402

THEMES = os.path.join('ide', 'Toolset', 'resources', 'supporting_files', 'themes')

# The dark palette the icons are drawn on, by the platform in the theme's
# name (com.livecode.theme.<platform>[.<version>]): the Windows dark window
# colour, the macOS dark window background, and the window colour of
# Adwaita-dark, the dark GTK 2 theme of the IDE tour in CI (the user's GTK
# theme decides on Linux; the common dark ones are about as dark)
BACKGROUNDS = {'win': (32, 32, 32), 'mac': (50, 50, 50), 'linux': (51, 57, 59)}
MIN_CONTRAST = 3.0

# com.livecode.<glyph>.icon.png: the icons drawn as a grey (or black)
# outline on nothing, which read the same inverted
GLYPHS = (
    'interface.classic.Arrow',
    'interface.classic.FivePointStar',
    'interface.classic.LabelField',
    'interface.classic.LineGraphic',
    'interface.classic.OvalGraphic',
    'interface.classic.RectangleGraphic',
    'interface.classic.RegularGraphic',
    'interface.classic.RoundRectGraphic',
    'interface.classic.SpeechBubble',
    'interface.classic.TenPointStar',
    'tool.BrushPattern',
    'tool.LineSize',
    'tool.RoundRadius',
    'tool.Select',
)

# The glyphs that are tools or tool options (cTool in revtools.livecodescript),
# which the palette draws on its tool highlight, and their shadow's alpha
TOOLS = (
    'interface.classic.LineGraphic',
    'tool.BrushPattern',
    'tool.LineSize',
    'tool.RoundRadius',
    'tool.Select',
)
SHADOW_ALPHA = 127

GIF_SIGNATURES = (b'GIF87a', b'GIF89a')


class ImageError(Exception):
    pass


def _lzw_decode(data, min_size):
    """The colour indexes in GIF image data (LZW with variable-length codes,
    least significant bit first)."""
    clear = 1 << min_size
    end = clear + 1
    size = min_size + 1
    table = [bytes([i]) for i in range(clear)] + [b'', b'']
    out = bytearray()
    previous = None
    bits = 0
    count = 0
    for byte in data:
        bits |= byte << count
        count += 8
        while count >= size:
            code = bits & ((1 << size) - 1)
            bits >>= size
            count -= size
            if code == clear:
                del table[clear + 2:]
                size = min_size + 1
                previous = None
                continue
            if code == end:
                return out
            if code < len(table):
                entry = table[code]
                if previous is not None and len(table) < 4096:
                    table.append(previous + entry[:1])
            elif code == len(table) and previous is not None:
                entry = previous + previous[:1]
                table.append(entry)
            else:
                raise ImageError('bad LZW code %d' % code)
            out += entry
            previous = entry
            if len(table) == 1 << size and size < 12:
                size += 1
    return out


def _gif_blocks(data, pos):
    """(the data of the sub-blocks starting at pos, the position after them)."""
    parts = []
    while pos < len(data) and data[pos]:
        parts.append(data[pos + 1:pos + 1 + data[pos]])
        pos += 1 + data[pos]
    if pos >= len(data):
        raise ImageError('truncated GIF')
    return b''.join(parts), pos + 1


def _read_gif(data, path):
    width, height, flags = struct.unpack('<HHB', data[6:11])
    pos = 13
    palette = b''
    if flags & 0x80:
        size = 3 << ((flags & 7) + 1)
        palette = data[pos:pos + size]
        pos += size
    transparent = None
    rgba = [bytearray(width * 4) for _ in range(height)]
    while pos < len(data):
        kind = data[pos]
        pos += 1
        if kind == 0x3B:
            break
        if kind == 0x21:
            label = data[pos]
            body, pos = _gif_blocks(data, pos + 1)
            if label == 0xF9 and len(body) >= 4:
                transparent = body[3] if body[0] & 1 else None
            continue
        if kind != 0x2C:
            raise ImageError('%s: unknown GIF block 0x%02x' % (path, kind))
        left, top, w, h, flags = struct.unpack('<HHHHB', data[pos:pos + 9])
        pos += 9
        colours = palette
        if flags & 0x80:
            size = 3 << ((flags & 7) + 1)
            colours = data[pos:pos + size]
            pos += size
        min_size = data[pos]
        body, pos = _gif_blocks(data, pos + 1)
        indexes = _lzw_decode(body, min_size)
        if len(indexes) < w * h:
            raise ImageError('%s: short GIF image data' % path)
        order = list(range(h))
        if flags & 0x40:
            order = (list(range(0, h, 8)) + list(range(4, h, 8)) + list(range(2, h, 4))
                     + list(range(1, h, 2)))
        for row, y in enumerate(order):
            if not 0 <= top + y < height:
                continue
            line = rgba[top + y]
            for x in range(w):
                index = indexes[row * w + x]
                if index == transparent or not 0 <= left + x < width:
                    continue
                if 3 * index + 3 > len(colours):
                    raise ImageError('%s: colour index out of range' % path)
                line[4 * (left + x):4 * (left + x) + 4] = colours[3 * index:3 * index + 3] + b'\xff'
        # The icons have one image; a GIF's later images are animation frames
        break
    return width, height, rgba, None


def _read_png(data, path):
    header = None
    palette = None
    transparency = None
    phys = None
    idat = []
    for kind, body in dark_disabled_icons._chunks(data):
        if kind == b'IHDR':
            header = struct.unpack('>IIBBBBB', body)
        elif kind == b'PLTE':
            palette = body
        elif kind == b'tRNS':
            transparency = body
        elif kind == b'pHYs':
            phys = body
        elif kind == b'IDAT':
            idat.append(body)
    if header is None:
        raise ImageError('%s: no IHDR chunk' % path)
    width, height, depth, colour, _, _, interlace = header
    if depth == 8:
        return dark_disabled_icons.read_png(path)
    if depth not in (1, 2, 4) or colour not in (0, 3) or interlace != 0:
        raise ImageError('%s: PNGs of bit depth %d, colour type %d, interlace %d are not supported'
                         % (path, depth, colour, interlace))
    # Samples of less than a byte: a row is packed, and filtered bytewise
    stride = (width * depth + 7) // 8
    rows = dark_disabled_icons._unfilter(zlib.decompress(b''.join(idat)), stride, height, 1)
    top = (1 << depth) - 1
    key = struct.unpack('>H', transparency[:2])[0] if colour == 0 and transparency else None
    rgba = []
    for line in rows:
        out = bytearray(width * 4)
        for x in range(width):
            bit = x * depth
            value = (line[bit >> 3] >> (8 - depth - (bit & 7))) & top
            if colour == 3:
                if palette is None or 3 * value + 3 > len(palette):
                    raise ImageError('%s: palette index out of range' % path)
                out[4 * x:4 * x + 3] = palette[3 * value:3 * value + 3]
                out[4 * x + 3] = transparency[value] if transparency and value < len(transparency) else 255
            else:
                out[4 * x:4 * x + 3] = bytes([value * 255 // top]) * 3
                out[4 * x + 3] = 0 if value == key else 255
        rgba.append(out)
    return width, height, rgba, phys


def read_icon(path):
    """(width, height, RGBA rows as bytearrays, pHYs chunk body or None) of
    a PNG (8-bit, or a 1, 2 or 4-bit palette or grey one) or a GIF, whatever
    its name says."""
    with open(path, 'rb') as f:
        data = f.read()
    if data[:6] in GIF_SIGNATURES:
        return _read_gif(data, path)
    if data.startswith(dark_disabled_icons.PNG_SIGNATURE):
        return _read_png(data, path)
    raise ImageError('%s: neither a PNG nor a GIF file' % path)


def inverted(rgba):
    """RGBA rows with each pixel's colour inverted and its alpha kept."""
    out = []
    for line in rgba:
        new = bytearray(line)
        for i in range(0, len(new), 4):
            new[i] = 255 - new[i]
            new[i + 1] = 255 - new[i + 1]
            new[i + 2] = 255 - new[i + 2]
        out.append(new)
    return out


def with_shadow(width, height, rgba):
    """(width + 2, height + 2, RGBA rows): the icon on a canvas a pixel
    larger on each side, with each transparent pixel next to its ink (alpha
    of at least half of the icon's highest) black at SHADOW_ALPHA."""
    top = max((line[i + 3] for line in rgba for i in range(0, len(line), 4)), default=0)

    def ink(x, y):
        return 0 <= x < width and 0 <= y < height and rgba[y][4 * x + 3] * 2 >= top > 0

    out = []
    for y in range(-1, height + 1):
        line = bytearray((width + 2) * 4)
        for x in range(-1, width + 1):
            at = 4 * (x + 1)
            if 0 <= x < width and 0 <= y < height and rgba[y][4 * x + 3]:
                line[at:at + 4] = rgba[y][4 * x:4 * x + 4]
            elif any(ink(x + dx, y + dy) for dy in (-1, 0, 1) for dx in (-1, 0, 1)):
                line[at:at + 4] = bytes((0, 0, 0, SHADOW_ALPHA))
        out.append(line)
    return width + 2, height + 2, out


def dark_folders(repo, problems):
    """(theme folder name, its dark folder, the dark palette) of every theme
    with a dark folder."""
    root = os.path.join(repo, THEMES)
    result = []
    for name in sorted(os.listdir(root)):
        dark = os.path.join(root, name, 'dark')
        if not os.path.isdir(dark):
            continue
        parts = name.split('.')
        background = BACKGROUNDS.get(parts[3]) if len(parts) > 3 else None
        if background is None:
            problems.append(('/'.join((THEMES.replace(os.sep, '/'), name)),
                             'no dark palette colour for this theme in BACKGROUNDS of tools/oxt/dark_tool_icons.py'))
            continue
        result.append((name, dark, background))
    return result


def main(argv=None):
    here = os.path.dirname(os.path.abspath(__file__))
    parser = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    parser.add_argument('--repo', default=os.path.normpath(os.path.join(here, '..', '..')),
                        help='repository root (default: two levels up from this script)')
    parser.add_argument('--check', action='store_true', help='check the icons instead of writing them')
    args = parser.parse_args(argv)

    problems = []
    checked = 0
    folders = dark_folders(args.repo, problems)
    if not folders:
        problems.append((THEMES.replace(os.sep, '/'), 'no theme with a dark folder'))
    for theme, dark, background in folders:
        base = '/'.join((THEMES.replace(os.sep, '/'), theme))
        if args.check:
            for name in sorted(os.listdir(os.path.dirname(dark))):
                if name.endswith('.icon.png') and not os.path.isfile(os.path.join(dark, name)):
                    problems.append((base + '/' + name, 'not in the dark folder: the dark Tools palette has no icon for it'))
        for glyph in GLYPHS:
            name = 'com.livecode.%s.icon.png' % glyph
            path = os.path.join(dark, name)
            if not os.path.isfile(path):
                continue
            rel = base + '/dark/' + name
            width, height, rgba, phys = read_icon(path)
            contrast = ink_contrast(rgba, background)
            checked += 1
            if args.check or contrast >= MIN_CONTRAST:
                print('%-6s %-62s %2dx%-2d  ink contrast %.2f:1 on %s'
                      % ('ok' if contrast >= MIN_CONTRAST else 'LOW', theme + '/dark/' + name, width, height,
                         contrast, rgb(background)))
                if contrast < MIN_CONTRAST:
                    problems.append((rel, 'ink contrast %.2f:1 on %s is below %.1f:1 (tools/oxt/dark_tool_icons.py '
                                     'inverts it)' % (contrast, rgb(background), MIN_CONTRAST)))
                continue
            light = inverted(rgba)
            if glyph in TOOLS:
                width, height, light = with_shadow(width, height, light)
            new = ink_contrast(light, background)
            if new < MIN_CONTRAST:
                problems.append((rel, 'ink contrast %.2f:1 on %s, and %.2f:1 inverted'
                                 % (contrast, rgb(background), new)))
                continue
            write_png(path, width, height, light, phys)
            print('wrote  %-62s %2dx%-2d  ink contrast %.2f:1 -> %.2f:1 on %s%s'
                  % (theme + '/dark/' + name, width, height, contrast, new, rgb(background),
                     ', with a shadow' if glyph in TOOLS else ''))

    for rel, message in problems:
        print('FAILED %s: %s' % (rel, message))
        if os.environ.get('GITHUB_ACTIONS') == 'true':
            print('::error file=%s,title=Tools palette icons::%s' % (rel, message))
    if args.check:
        summary = os.environ.get('GITHUB_STEP_SUMMARY')
        if summary:
            with open(summary, 'a', encoding='utf-8') as f:
                f.write('### Tools palette icons\n\n%d outline icon(s) in %d dark set(s): %s\n\n' % (
                    checked, len(folders),
                    'each has at least %.1f:1 on its dark palette, and every icon is in the dark sets.'
                    % MIN_CONTRAST if not problems else '%d problem(s).' % len(problems)))
        print('Tools palette icons: %s' % ('passed' if not problems else 'FAILED (%d problem(s))' % len(problems)))
    return 1 if problems else 0


if __name__ == '__main__':
    sys.exit(main())
