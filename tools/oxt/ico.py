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
"""Write and check Windows icon files (.ico), with the Python standard
library only.

  python tools/oxt/ico.py write OUT.ico PNG...
  python tools/oxt/ico.py check FILE.ico

"write" takes square PNG files (8-bit RGB or RGBA, not interlaced), one
per size, and writes one image per file, smallest first: sizes below 256
pixels as 32-bit bitmaps (BGRA rows bottom up, then an all-zero AND mask;
what the resource compiler, Explorer and Inno Setup read everywhere), 256
pixels as the PNG file itself, unchanged, as Windows Vista and later
store it. The same PNG files give the same bytes.

"check" reads an .ico file back: the header, each directory entry, and
each image (a PNG signature, or a 32-bit bitmap header whose size matches
the entry), and prints one line per image.

Exit code: 0 on success, 1 when a check fails or a file cannot be read,
2 for a usage error.
"""

import struct
import sys
import zlib

PNG_SIGNATURE = b'\x89PNG\r\n\x1a\n'


class IcoError(Exception):
    pass


def png_size(data):
    if data[:8] != PNG_SIGNATURE or data[12:16] != b'IHDR':
        raise IcoError('not a PNG file')
    return struct.unpack('>II', data[16:24])


def png_rgba(data):
    """The pixels of a PNG file as (width, height, rows of RGBA bytes)."""
    width, height = png_size(data)
    depth, colour, compression, filtering, interlace = data[24:29]
    if depth != 8 or colour not in (2, 6) or compression or filtering or interlace:
        raise IcoError('only 8-bit RGB or RGBA PNG files that are not interlaced are supported')
    channels = 4 if colour == 6 else 3
    pos, idat = 8, b''
    while pos < len(data):
        length, kind = struct.unpack('>I4s', data[pos:pos + 8])
        if kind == b'IDAT':
            idat += data[pos + 8:pos + 8 + length]
        pos += 12 + length
    raw = zlib.decompress(idat)
    stride = width * channels
    rows, prev = [], bytearray(stride)
    for y in range(height):
        start = y * (stride + 1)
        kind = raw[start]
        line = bytearray(raw[start + 1:start + 1 + stride])
        for i in range(stride):
            a = line[i - channels] if i >= channels else 0
            b = prev[i]
            c = prev[i - channels] if i >= channels else 0
            if kind == 1:
                line[i] = (line[i] + a) & 255
            elif kind == 2:
                line[i] = (line[i] + b) & 255
            elif kind == 3:
                line[i] = (line[i] + ((a + b) >> 1)) & 255
            elif kind == 4:
                p = a + b - c
                pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                line[i] = (line[i] + (a if pa <= pb and pa <= pc else b if pb <= pc else c)) & 255
            elif kind != 0:
                raise IcoError('unknown PNG filter type %d' % kind)
        prev = line
        if channels == 3:
            line = bytearray(b''.join(bytes(line[i:i + 3]) + b'\xff' for i in range(0, stride, 3)))
        rows.append(bytes(line))
    return width, height, rows


def bitmap(data):
    """A 32-bit icon bitmap (header, BGRA rows bottom up, AND mask) from a PNG file."""
    width, height, rows = png_rgba(data)
    header = struct.pack('<IiiHHIIiiII', 40, width, height * 2, 1, 32, 0, 0, 0, 0, 0, 0)
    pixels = bytearray()
    for row in reversed(rows):
        for i in range(0, len(row), 4):
            r, g, b, a = row[i:i + 4]
            pixels += bytes((b, g, r, a))
    mask_stride = ((width + 31) // 32) * 4
    return header + bytes(pixels) + bytes(mask_stride * height)


def build(pngs):
    images = []
    for data in pngs:
        w, h = png_size(data)
        if w != h or not 1 <= w <= 256:
            raise IcoError('%d x %d: icon images are square, 1 to 256 pixels' % (w, h))
        images.append((w, data if w == 256 else bitmap(data)))
    images.sort(key=lambda image: image[0])
    if len({w for w, _ in images}) != len(images):
        raise IcoError('two images have the same size')
    out = struct.pack('<HHH', 0, 1, len(images))
    offset = 6 + 16 * len(images)
    body = b''
    for w, blob in images:
        out += struct.pack('<BBBBHHII', w % 256, w % 256, 0, 0, 1, 32, len(blob), offset + len(body))
        body += blob
    return out + body


def write(out, files):
    pngs = []
    for path in files:
        with open(path, 'rb') as f:
            pngs.append(f.read())
    data = build(pngs)
    with open(out, 'wb') as f:
        f.write(data)
    return data


def check(data):
    """One line per image; raises IcoError when the file is not a valid icon."""
    if len(data) < 6:
        raise IcoError('too short')
    reserved, kind, count = struct.unpack('<HHH', data[:6])
    if reserved != 0 or kind != 1 or count == 0:
        raise IcoError('not an icon file')
    lines = []
    for i in range(count):
        w, h, _, _, _, bpp, size, offset = struct.unpack('<BBBBHHII', data[6 + 16 * i:22 + 16 * i])
        w, h = w or 256, h or 256
        blob = data[offset:offset + size]
        if len(blob) != size:
            raise IcoError('image %d runs past the end of the file' % (i + 1))
        if blob[:8] == PNG_SIGNATURE:
            pw, ph = png_size(blob)
            if (pw, ph) != (w, h):
                raise IcoError('image %d: the PNG is %d x %d, the entry says %d x %d' % (i + 1, pw, ph, w, h))
            lines.append('%d x %d PNG, %d bytes' % (w, h, size))
        else:
            hsize, bw, bh, _, bbits = struct.unpack('<IiiHH', blob[:16])
            if hsize != 40 or bw != w or bh != 2 * h or bbits != 32:
                raise IcoError('image %d: not a 32-bit %d x %d bitmap' % (i + 1, w, h))
            if size != 40 + w * h * 4 + ((w + 31) // 32) * 4 * h:
                raise IcoError('image %d: the bitmap has the wrong size' % (i + 1))
            lines.append('%d x %d 32-bit bitmap, %d bytes' % (w, h, size))
    return lines


def main(argv):
    if len(argv) >= 3 and argv[1] == 'write':
        try:
            write(argv[2], argv[3:])
        except (OSError, IcoError, zlib.error) as e:
            print('ico: %s' % e, file=sys.stderr)
            return 1
        return 0
    if len(argv) == 3 and argv[1] == 'check':
        try:
            with open(argv[2], 'rb') as f:
                for line in check(f.read()):
                    print(line)
        except (OSError, IcoError) as e:
            print('ico: %s: %s' % (argv[2], e), file=sys.stderr)
            return 1
        return 0
    print(__doc__.split('\n\n')[1], file=sys.stderr)
    return 2


if __name__ == '__main__':
    sys.exit(main(sys.argv))
