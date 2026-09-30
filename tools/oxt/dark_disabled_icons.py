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

"""Make the dark-appearance twins of the toolbar's disabled icons.

  python tools/oxt/dark_disabled_icons.py [--repo DIR] [--check]

The toolbar (ide/Toolset/palettes/menubar/revmenubar.livecodescript) shows
<name>-disabled.png for a disabled button. Those are drawn for a light
toolbar: dark grey, and nearly invisible on the dark toolbar of the dark
appearance. For every <name>-disabled.png and
<name>-disabled@extra-high.png in ide/Toolset/palettes/menubar/images this
writes <name>-disabled-dark.png (and -dark@extra-high.png), derived from
the ENABLED icon of the same density, <name>.png or <name>@extra-high.png:

  - desaturated: each pixel's grey is its luma (Rec. 709 weights),
  - faded: the alpha is multiplied by OPACITY (50%), the usual look of a
    disabled icon,
  - lifted: the grey is mapped from 0..255 to lift..255, with the smallest
    lift (in steps of 5) that gives the icon's ink TARGET (3.3:1) contrast
    with the toolbar's dark background (32,32,32, the Windows dark window
    colour). Dark icons are lifted more than light ones, and each keeps
    as much of its shading as it can, in the same order.

The pHYs chunk (density) of the enabled icon is copied; other metadata is
not.

--check writes nothing. It checks that every disabled icon has its dark
twin, that each twin has exactly the pixels this script makes from the
enabled icon (so the committed files are this script's output), and that
the mean luminance of each twin's ink (its pixels with at least half of its
highest alpha, composited over 32,32,32) has a contrast of at least 3:1
with the background. tools/ci/check_ide_icons.py runs this check in CI.

Standard library only (PNG decoding and encoding with zlib and struct);
needs Python 3.8 or later.
"""

import argparse
import os
import struct
import sys
import zlib

IMAGES = os.path.join('ide', 'Toolset', 'palettes', 'menubar', 'images')
OPACITY = 0.5
TARGET = 3.3
BACKGROUND = (32, 32, 32)
MIN_CONTRAST = 3.0

PNG_SIGNATURE = b'\x89PNG\r\n\x1a\n'


class PNGError(Exception):
    pass


def _chunks(data):
    if not data.startswith(PNG_SIGNATURE):
        raise PNGError('not a PNG file')
    pos = len(PNG_SIGNATURE)
    while pos + 8 <= len(data):
        length, kind = struct.unpack('>I4s', data[pos:pos + 8])
        body = data[pos + 8:pos + 8 + length]
        if len(body) != length:
            raise PNGError('truncated chunk')
        yield kind, body
        pos += 12 + length
        if kind == b'IEND':
            return
    raise PNGError('no IEND chunk')


def _paeth(a, b, c):
    p = a + b - c
    pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
    if pa <= pb and pa <= pc:
        return a
    return b if pb <= pc else c


def _unfilter(raw, width, height, bpp):
    stride = width * bpp
    rows = []
    previous = bytearray(stride)
    pos = 0
    for _ in range(height):
        kind = raw[pos]
        line = bytearray(raw[pos + 1:pos + 1 + stride])
        pos += 1 + stride
        if kind == 1:
            for i in range(bpp, stride):
                line[i] = (line[i] + line[i - bpp]) & 0xFF
        elif kind == 2:
            for i in range(stride):
                line[i] = (line[i] + previous[i]) & 0xFF
        elif kind == 3:
            for i in range(stride):
                left = line[i - bpp] if i >= bpp else 0
                line[i] = (line[i] + ((left + previous[i]) >> 1)) & 0xFF
        elif kind == 4:
            for i in range(stride):
                left = line[i - bpp] if i >= bpp else 0
                upleft = previous[i - bpp] if i >= bpp else 0
                line[i] = (line[i] + _paeth(left, previous[i], upleft)) & 0xFF
        elif kind != 0:
            raise PNGError('unknown filter type %d' % kind)
        rows.append(line)
        previous = line
    return rows


def read_png(path):
    """(width, height, RGBA rows as bytearrays, pHYs chunk body or None) of
    an 8-bit, non-interlaced PNG of any colour type."""
    with open(path, 'rb') as f:
        data = f.read()
    header = None
    palette = None
    transparency = None
    phys = None
    idat = []
    for kind, body in _chunks(data):
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
        raise PNGError('%s: no IHDR chunk' % path)
    width, height, depth, colour, _, _, interlace = header
    if depth != 8 or interlace != 0:
        raise PNGError('%s: only 8-bit, non-interlaced PNGs are supported' % path)
    channels = {0: 1, 2: 3, 3: 1, 4: 2, 6: 4}.get(colour)
    if channels is None:
        raise PNGError('%s: unknown colour type %d' % (path, colour))
    rows = _unfilter(zlib.decompress(b''.join(idat)), width, height, channels)
    rgba = []
    for line in rows:
        out = bytearray(width * 4)
        for x in range(width):
            if colour == 6:
                out[4 * x:4 * x + 4] = line[4 * x:4 * x + 4]
            elif colour == 2:
                out[4 * x:4 * x + 3] = line[3 * x:3 * x + 3]
                out[4 * x + 3] = 255
            elif colour == 0:
                out[4 * x:4 * x + 3] = bytes([line[x]]) * 3
                out[4 * x + 3] = 255
            elif colour == 4:
                out[4 * x:4 * x + 3] = bytes([line[2 * x]]) * 3
                out[4 * x + 3] = line[2 * x + 1]
            else:
                index = line[x]
                if palette is None or 3 * index + 3 > len(palette):
                    raise PNGError('%s: palette index out of range' % path)
                out[4 * x:4 * x + 3] = palette[3 * index:3 * index + 3]
                out[4 * x + 3] = transparency[index] if transparency and index < len(transparency) else 255
        rgba.append(out)
    return width, height, rgba, phys


def _chunk(kind, body):
    return struct.pack('>I', len(body)) + kind + body + struct.pack('>I', zlib.crc32(kind + body) & 0xFFFFFFFF)


def write_png(path, width, height, rgba, phys=None):
    """Writes RGBA rows as an 8-bit RGBA PNG. Each row gets the filter with
    the smallest sum of absolute values (the usual heuristic)."""
    bpp = 4
    stride = width * bpp
    previous = bytearray(stride)
    filtered = bytearray()
    for line in rgba:
        best = None
        for kind in range(5):
            out = bytearray(stride)
            for i in range(stride):
                left = line[i - bpp] if i >= bpp else 0
                up = previous[i]
                upleft = previous[i - bpp] if i >= bpp else 0
                if kind == 0:
                    predictor = 0
                elif kind == 1:
                    predictor = left
                elif kind == 2:
                    predictor = up
                elif kind == 3:
                    predictor = (left + up) >> 1
                else:
                    predictor = _paeth(left, up, upleft)
                out[i] = (line[i] - predictor) & 0xFF
            cost = sum(v if v < 128 else 256 - v for v in out)
            if best is None or cost < best[0]:
                best = (cost, kind, out)
        filtered.append(best[1])
        filtered += best[2]
        previous = line
    data = PNG_SIGNATURE + _chunk(b'IHDR', struct.pack('>IIBBBBB', width, height, 8, 6, 0, 0, 0))
    if phys is not None:
        data += _chunk(b'pHYs', phys)
    data += _chunk(b'IDAT', zlib.compress(bytes(filtered), 9)) + _chunk(b'IEND', b'')
    with open(path, 'wb') as f:
        f.write(data)


def _faded_grey(rgba, lift):
    out = []
    for line in rgba:
        new = bytearray(len(line))
        for i in range(0, len(line), 4):
            r, g, b, a = line[i], line[i + 1], line[i + 2], line[i + 3]
            luma = 0.2126 * r + 0.7152 * g + 0.0722 * b
            grey = int(round(lift + (255 - lift) * luma / 255.0))
            new[i] = new[i + 1] = new[i + 2] = grey
            new[i + 3] = int(round(a * OPACITY))
        out.append(new)
    return out


def dark_twin_pixels(rgba):
    """(RGBA rows, lift) of the dark-appearance disabled look of an enabled
    icon's RGBA rows."""
    for lift in range(0, 256, 5):
        out = _faded_grey(rgba, lift)
        if ink_contrast(out) >= TARGET:
            return out, lift
    return _faded_grey(rgba, 255), 255


def relative_luminance(rgb):
    total = 0.0
    for weight, value in zip((0.2126, 0.7152, 0.0722), rgb):
        c = value / 255.0
        c = c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
        total += weight * c
    return total


def ink_contrast(rgba, background=BACKGROUND):
    """Contrast ratio between the background and the mean luminance of the
    icon's ink (pixels with at least half of the icon's highest alpha),
    each composited over the background."""
    top = max((line[i + 3] for line in rgba for i in range(0, len(line), 4)), default=0)
    if top == 0:
        return 1.0
    total = 0.0
    count = 0
    for line in rgba:
        for i in range(0, len(line), 4):
            a = line[i + 3]
            if a * 2 < top:
                continue
            mixed = [(line[i + k] * a + background[k] * (255 - a)) / 255.0 for k in range(3)]
            total += relative_luminance(mixed)
            count += 1
    back = relative_luminance(background)
    mean = total / count
    return (max(mean, back) + 0.05) / (min(mean, back) + 0.05)


def pairs(images):
    """(disabled icon, enabled icon, dark twin) file names in the folder."""
    result = []
    for name in sorted(os.listdir(images)):
        if not name.endswith('.png'):
            continue
        stem = name[:-4]
        density = ''
        if '@' in stem:
            stem, density = stem.split('@', 1)
            density = '@' + density
        if not stem.endswith('-disabled'):
            continue
        base = stem[:-len('-disabled')]
        result.append((name, base + density + '.png', stem + '-dark' + density + '.png'))
    return result


def main(argv=None):
    here = os.path.dirname(os.path.abspath(__file__))
    parser = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    parser.add_argument('--repo', default=os.path.normpath(os.path.join(here, '..', '..')),
                        help='repository root (default: two levels up from this script)')
    parser.add_argument('--check', action='store_true', help='check the twins instead of writing them')
    args = parser.parse_args(argv)

    images = os.path.join(args.repo, IMAGES)
    problems = []
    found = pairs(images)
    if not found:
        problems.append((IMAGES, 'no *-disabled*.png icons'))
    for disabled, enabled, twin in found:
        rel_twin = (IMAGES + '/' + twin).replace(os.sep, '/')
        if not os.path.isfile(os.path.join(images, enabled)):
            problems.append((rel_twin, 'no enabled icon %s to derive it from' % enabled))
            continue
        width, height, rgba, phys = read_png(os.path.join(images, enabled))
        expected, lift = dark_twin_pixels(rgba)
        if args.check:
            path = os.path.join(images, twin)
            if not os.path.isfile(path):
                problems.append((rel_twin, 'missing: the dark twin of %s' % disabled))
                continue
            t_width, t_height, t_rgba, _ = read_png(path)
            if (t_width, t_height) != (width, height) or t_rgba != expected:
                problems.append((rel_twin, 'not the output of tools/oxt/dark_disabled_icons.py for %s' % enabled))
                continue
            contrast = ink_contrast(t_rgba)
            status = 'ok' if contrast >= MIN_CONTRAST else 'LOW'
            print('%-6s %-46s %dx%d  lift %3d  ink contrast %.2f:1 on %d,%d,%d'
                  % ((status, twin, width, height, lift, contrast) + BACKGROUND))
            if contrast < MIN_CONTRAST:
                problems.append((rel_twin, 'ink contrast %.2f:1 on %d,%d,%d is below %.1f:1'
                                 % ((contrast,) + BACKGROUND + (MIN_CONTRAST,))))
        else:
            write_png(os.path.join(images, twin), width, height, expected, phys)
            print('wrote  %-46s %dx%d  lift %3d  ink contrast %.2f:1' % (twin, width, height, lift, ink_contrast(expected)))

    for rel, message in problems:
        print('FAILED %s: %s' % (rel, message))
        if os.environ.get('GITHUB_ACTIONS') == 'true':
            print('::error file=%s,title=Toolbar icons::%s' % (rel, message))
    if args.check:
        summary = os.environ.get('GITHUB_STEP_SUMMARY')
        if summary:
            with open(summary, 'a', encoding='utf-8') as f:
                f.write('### Toolbar icons\n\n%d disabled icon(s): %s\n\n' % (
                    len(found), 'every one has its dark twin, made by tools/oxt/dark_disabled_icons.py, '
                    'with at least %.1f:1 on %d,%d,%d.' % ((MIN_CONTRAST,) + BACKGROUND) if not problems
                    else '%d problem(s).' % len(problems)))
        print('Toolbar icons: %s' % ('passed' if not problems else 'FAILED (%d problem(s))' % len(problems)))
    return 1 if problems else 0


if __name__ == '__main__':
    sys.exit(main())
