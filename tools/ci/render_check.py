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

"""Measure the images written by tools/ci/render-test.livecodescript.

  python tools/ci/render_check.py --mode dark|light [--system dark|light]
                                  [--label <run>] --dir <folder>
  python tools/ci/render_check.py --compare <folder A> <folder B>
                                  [--only <glob>]... [--exclude <glob>]...
                                  [--rename <prefix>=<prefix>] [--info <key>]...
  python tools/ci/render_check.py --self-test

<folder> holds render.txt and the PNG files of one run of the render test
(tools/ci/render-test.ps1 runs it with Windows set to dark or light mode and
the appAppearance set to "system", "dark" or left at its default). --mode is
the appearance the run draws stacks that set none in (the effective
appAppearance), and --system the Windows setting (the systemAppearance
reported); it defaults to --mode. Every check prints one line,

  PASS <run> <check>: <measurement>
  FAIL <run> <check>: <what is wrong and where to look>

(<run> is --label, or the mode) and the last line is
"SUMMARY passed=<n> failed=<n>". The exit code is the number of failed
checks (at most 100), or 101 when the folder cannot be read.

--compare compares the images of two runs, those of folder A that match the
--only patterns (all when none is given) and none of the --exclude ones,
with the images of the same name in folder B (--rename maps a prefix of the
name in A to one in B). Two images match when the mean absolute difference
of their channels is at most 0.5 and at most 0.2% of their pixels differ by
more than 16 in a channel: the same colours give the same ClearType pixels,
so a real difference is a bug. --info compares INFO values of render.txt.
screen.png (a snapshot of the desktop) is never compared.

What is checked, for the native Windows theme:

* Disabled labels (push button, checkbox, radio button, graphic, tab) are
  drawn once, flat, in the disabled grey: the screen's gray_pixel, 137 in
  dark mode and 128 in light mode (Tom Perry's values,
  MCWin32UpdateSystemColors in engine/src/w32dcs.cpp). Before the fix they
  were engraved: a copy in the 3D highlight colour (white) one pixel down and
  right, under the label in the 3D shadow colour (160), in
  engine/src/buttondraw.cpp and, for a graphic showing its name,
  MCGraphic::draw in engine/src/graphic.cpp. The graphic has a foreColor of
  its own, which its label must not take while it is disabled.
  - "copy": no pixel of the label on the far side of its background (a
    light copy on a light background), and in dark mode no pixel brighter
    than L=170 (a white copy on a dark background).
  - "colour": the label's own colour (the far end of its pixels, the 2%
    quantile) is the disabled grey, within 12.
  - "single run": every pixel of the label lies between its background and
    the disabled grey (within 12), as one run of grey glyphs blended with
    the background does; a second copy in another colour does not.
  - "contrast" (dark mode): at least 4.5:1 between the label and its
    background (WCAG AA for text).
  - "shape": the label has the shape of the same control's label when it is
    enabled, which is drawn once, in the same grey (render-test sets its
    foreColor: ClearType draws text a pixel heavier or lighter with the
    contrast of its colour, so labels in different colours differ in shape).
    The core of a label is its pixels at least half way from their
    background to the label colour (the disabled grey, or for the enabled
    label its measured colour). The disabled core may be at most 15%
    larger than the enabled one, and the two must overlap by at least 0.85
    (intersection over union). A second copy of the label in the same grey,
    offset by a pixel or two, passes the checks above but fails this one.
  The label's pixels are those that change when the label is hidden: the
  test renders each button again with showName false (<name>-nolabel.png),
  which also gives the background under every pixel, and both again with the
  control enabled (<name>-enabled.png, <name>-enabled-nolabel.png) for the
  shape. Tabs cannot hide their text, so there the background is the colour
  of the tab face, and they have no shape check.
* Scrollbars (a scrollbar control and a field's vertical scrollbar): the
  mean luminance of the track is below 80 in dark mode and above 200 in
  light mode (engine/src/w32theme.cpp, OpenScrollbarTheme), and there is a
  thumb, at the top: at least 4 consecutive rows between the up arrow and
  the track whose mean luminance differs from the track's by 20 or more, and
  in dark mode is brighter. The track alone cannot tell a dark scrollbar from
  none at all, or from one whose theme part draws nothing.
* The appearance: the engine starts with the appAppearance "light"
  (INFO appAppearanceAtStart), draws in the appearance the run asked for
  (INFO effectiveAppAppearance is --mode) and reports the Windows setting as
  the systemAppearance (--system). Engines without the appAppearance (the
  reference release) are not checked for it.
* The appearance scenarios (text, face and region shots, EXPECT below): the
  owner's libMQTTxt colours (s1-*) look as designed, light, in every run;
  a stack with no colours (s2-*) is dark in the dark appearance and light in
  the light one; a dark card (s3), black text of a field's own (s4), text
  runs (s6) and button colours (s7) get fitting unset colours. A text shot
  is the pixels that change when the text is taken away, a face shot those
  that change when the control is hidden, a region the mean of a rectangle.

Luminance L is 0.299 R + 0.587 G + 0.114 B on the 0-255 scale; contrast
ratios use the WCAG relative luminance.

Only the Python 3 standard library is used (Python 3.8 or later); the PNG
decoder handles the non-interlaced 8-bit files the engine writes.
"""

import argparse
import os
import struct
import sys
import zlib

# The disabled grey, gray_pixel in MCWin32UpdateSystemColors
# (engine/src/w32dcs.cpp): 0x8989 in dark mode, 0x8080 in light mode.
DISABLED_GREY = {'dark': 137, 'light': 128}
# How far the label colour may be from the disabled grey. The engraved labels
# were 160 (COLOR_3DSHADOW), 23 above the dark grey and 32 above the light one.
GREY_TOLERANCE = 12
# In dark mode no label pixel may be brighter than this (the engraved copy
# is white, 255, on a background of 32).
DARK_MAX_LABEL_L = 170
# A pixel belongs to a label when one of its channels differs by more than
# this from the render without the label. The two renders are otherwise the
# same, so this only needs to be above rounding; it must stay below 15, the
# difference between the white engraved copy and the light card (240).
LABEL_DIFF = 6
# Label pixels further than this on the far side of the background are a copy.
OPPOSITE_TOLERANCE = 10
# At most this many stray pixels are tolerated in the copy and single-run
# checks (antialiasing at a clip edge, for example).
STRAY_PIXELS = 3
MIN_LABEL_PIXELS = 20
MIN_CONTRAST = 4.5
# The shape check: a pixel is in the core of a label when it is at least
# CORE_SHARE of the way from its background to the label colour. The disabled
# core may be at most SHAPE_MAX_GROWTH times the enabled one and must overlap
# it by SHAPE_MIN_OVERLAP (intersection over union). On the self-test's
# glyphs a flat label has the enabled core exactly (overlap 1.00); the same
# grey drawn twice, (+1,+1) apart, is 28% larger with an overlap of 0.78.
CORE_SHARE = 0.5
SHAPE_MAX_GROWTH = 1.15
SHAPE_MIN_OVERLAP = 0.85
TRACK_DARK_MAX = 80
TRACK_LIGHT_MIN = 200
# A scrollbar's thumb: at least THUMB_MIN_ROWS consecutive rows between the
# up arrow and the track whose mean L differs from the track's by
# THUMB_MIN_DIFF, brighter in dark mode. The light uxtheme thumb is about 205
# on a track of 240, DarkMode_Explorer's about 77 on 23 and the one of
# drawdarkscrollbarpart 0x6E on 0x2B. A track alone, or no scrollbar at all
# (the card colour), passes the track check but not this one.
THUMB_MIN_ROWS = 4
THUMB_MIN_DIFF = 20
# The mode the engine must report, and the background luminance behind the
# labels, dark below 100 and light above 150 (the dark theme background is
# 32, the light card 240).
DARK_BACKGROUND_MAX = 100
LIGHT_BACKGROUND_MIN = 150
# Two images of a comparison match when the mean absolute difference of their
# channels is at most COMPARE_MAX_MEAN and at most COMPARE_MAX_SHARE of their
# pixels differ by more than COMPARE_PIXEL_DIFF in a channel.
COMPARE_MAX_MEAN = 0.5
COMPARE_MAX_SHARE = 0.002
COMPARE_PIXEL_DIFF = 16
# Never compared: a snapshot of the desktop
COMPARE_NEVER = ('screen.png',)
# The core of a text shot: its pixels at least this share of the way from
# their background to the far end
TEXT_CORE_SHARE = 0.85


def _l(r, g, b):
    return 0.299 * r + 0.587 * g + 0.114 * b


# What the text, face and region shots of the appearance scenarios are
# checked for, by name and by the appearance of the run ('*' for both):
#   ('text_min_l', v)        the text colour's L is at least v
#   ('text_max_l', v)        ... at most v
#   ('text_near_l', v, tol)  ... within tol of v
#   ('text_red',)            the text is red: R > 150, G < 80, B < 80
#   ('contrast', r)          at least r:1 between the text and what is under it
#   ('interior_min_l', v)    the inside of a face's outline has a mean L of
#                            at least v (a checkbox's box)
#   ('face_median_min_l', v) the median L of a face's pixels is at least v
#   ('face_far_min_l', v)    the far end of a face's pixels from what is
#                            under them has an L of at least v (a line)
#   ('face_far_max_l', v)    ... at most v
#   ('region_min_l', v)      the mean L of the region is at least v
#   ('region_near_l', v, tol) ... within tol of v
#   ('record',)              only measured and printed (a known limit)
# Names that start with "s8-" are only compared with s2 of another run.
EXPECT = {
    # S1, the owner's libMQTTxt colours: as designed, light, in every run
    's1-title': {'*': [('text_min_l', 240)]},
    's1-section': {'*': [('text_near_l', _l(28, 34, 46), 12)]},
    's1-caption': {'*': [('text_near_l', _l(138, 146, 158), 12)]},
    's1-host': {'*': [('contrast', 7.0), ('text_max_l', 60)]},
    's1-check': {'*': [('contrast', 4.5), ('text_max_l', 90)]},
    's1-check-on': {'*': [('contrast', 4.5), ('text_max_l', 90)]},
    's1-check-box': {'*': [('interior_min_l', 200)]},
    's1-push': {'*': [('contrast', 4.5), ('text_max_l', 90)]},
    's1-push-face': {'*': [('face_median_min_l', 180)]},
    's1-messages': {'*': [('region_min_l', 200)]},
    # S2, no colours: dark in the dark appearance, light in the light one
    's2-field': {'dark': [('text_min_l', 200), ('contrast', 4.5)], 'light': [('text_max_l', 60)]},
    's2-field-fill': {'dark': [('region_near_l', 32, 12)], 'light': [('region_min_l', 245)]},
    's2-label': {'dark': [('text_min_l', 200), ('contrast', 4.5)], 'light': [('text_max_l', 60)]},
    's2-check': {'dark': [('text_min_l', 200), ('contrast', 4.5)], 'light': [('text_max_l', 60)]},
    's2-push': {'*': [('contrast', 4.5)]},
    's2-line': {'dark': [('face_far_min_l', 200)], 'light': [('face_far_max_l', 60)]},
    's2-card': {'dark': [('region_near_l', 32, 8)], 'light': [('region_near_l', 240, 8)]},
    # S3, a card of 30,30,30: white text in the dark appearance
    's3-text': {'dark': [('text_min_l', 200), ('contrast', 4.5)], 'light': [('record',)]},
    # S4, black text of a field's own and no background: a light fill
    's4-bordered-fill': {'dark': [('region_min_l', 200)], 'light': [('region_min_l', 200)]},
    's4-borderless-fill': {'dark': [('region_min_l', 200)], 'light': [('region_min_l', 200)]},
    's4-label': {'*': [('record',)]},
    # S6, text runs
    's6-plain': {'*': [('text_max_l', 60)]},
    's6-red': {'*': [('text_red',)]},
    's6-yellow': {'*': [('text_max_l', 60)]},
    's6-unstyled-yellow': {'*': [('text_max_l', 60)]},
    's6-unstyled-plain': {'dark': [('text_min_l', 200)], 'light': [('text_max_l', 60)]},
    # S7, a button's own background: the label fits it in the dark appearance
    's7-white': {'dark': [('text_max_l', 90), ('contrast', 4.5)]},
    's7-dark': {'dark': [('text_min_l', 200)]},
}

# Where a failing label is drawn, by the render test's names. The buttons and
# tabs are drawn in engine/src/buttondraw.cpp.
LABEL_SOURCES = {
    'graphic': 'MCGraphic::draw in engine/src/graphic.cpp; the graphic\'s own '
               'foreColor (200,0,0) is L=60',
}
BUTTON_SOURCE = 'engine/src/buttondraw.cpp'


# --------------------------------------------------------------------------
# PNG reading and writing

PNG_SIGNATURE = b'\x89PNG\r\n\x1a\n'


class PNGError(Exception):
    pass


def _paeth(a, b, c):
    p = a + b - c
    pa = abs(p - a)
    pb = abs(p - b)
    pc = abs(p - c)
    if pa <= pb and pa <= pc:
        return a
    if pb <= pc:
        return b
    return c


def read_png(path):
    """Return (width, height, rows), rows a list of lists of (r, g, b, a)."""
    with open(path, 'rb') as f:
        data = f.read()
    if data[:8] != PNG_SIGNATURE:
        raise PNGError('%s is not a PNG file' % path)
    pos = 8
    header = None
    palette = []
    transparency = b''
    idat = []
    while pos + 8 <= len(data):
        length, kind = struct.unpack('>I4s', data[pos:pos + 8])
        body = data[pos + 8:pos + 8 + length]
        pos += 12 + length
        if kind == b'IHDR':
            header = struct.unpack('>IIBBBBB', body)
        elif kind == b'PLTE':
            palette = [tuple(body[i:i + 3]) for i in range(0, len(body), 3)]
        elif kind == b'tRNS':
            transparency = body
        elif kind == b'IDAT':
            idat.append(body)
        elif kind == b'IEND':
            break
    if header is None:
        raise PNGError('%s has no IHDR chunk' % path)
    width, height, depth, colour, compression, filtering, interlace = header
    if compression != 0 or filtering != 0:
        raise PNGError('%s: unknown compression or filter method' % path)
    if interlace != 0:
        raise PNGError('%s is interlaced, which this reader does not handle' % path)
    channels = {0: 1, 2: 3, 3: 1, 4: 2, 6: 4}.get(colour)
    if channels is None:
        raise PNGError('%s: unknown colour type %d' % (path, colour))
    if depth not in (1, 2, 4, 8, 16) or (depth < 8 and colour not in (0, 3)):
        raise PNGError('%s: unsupported bit depth %d for colour type %d' % (path, depth, colour))

    raw = zlib.decompress(b''.join(idat))
    bits = channels * depth
    stride = (width * bits + 7) // 8
    bpp = max(1, bits // 8)
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
                upper_left = previous[i - bpp] if i >= bpp else 0
                line[i] = (line[i] + _paeth(left, previous[i], upper_left)) & 0xFF
        elif kind != 0:
            raise PNGError('%s: unknown filter type %d' % (path, kind))
        previous = line

        if depth == 16:
            samples = line[0::2]
        elif depth == 8:
            samples = line
        else:
            per_byte = 8 // depth
            mask = (1 << depth) - 1
            samples = []
            for i in range(width):
                byte = line[i // per_byte]
                shift = 8 - depth * (i % per_byte + 1)
                samples.append((byte >> shift) & mask)
            if colour == 0:
                scale = 255 // mask
                samples = [s * scale for s in samples]

        row = []
        for x in range(width):
            if colour == 6:
                row.append(tuple(samples[4 * x:4 * x + 4]))
            elif colour == 2:
                row.append(tuple(samples[3 * x:3 * x + 3]) + (255,))
            elif colour == 0:
                v = samples[x]
                row.append((v, v, v, 255))
            elif colour == 4:
                v = samples[2 * x]
                row.append((v, v, v, samples[2 * x + 1]))
            else:
                index = samples[x]
                if index >= len(palette):
                    raise PNGError('%s: palette index out of range' % path)
                alpha = transparency[index] if index < len(transparency) else 255
                row.append(palette[index] + (alpha,))
        rows.append(row)
    return width, height, rows


def write_png(path, rows):
    """Write rows of (r, g, b) or (r, g, b, a) as an 8-bit RGBA PNG."""
    height = len(rows)
    width = len(rows[0]) if height else 0
    raw = bytearray()
    for row in rows:
        raw.append(0)
        for p in row:
            raw.extend((p[0], p[1], p[2], p[3] if len(p) > 3 else 255))

    def chunk(kind, body):
        return (struct.pack('>I', len(body)) + kind + body +
                struct.pack('>I', zlib.crc32(kind + body) & 0xFFFFFFFF))

    with open(path, 'wb') as f:
        f.write(PNG_SIGNATURE)
        f.write(chunk(b'IHDR', struct.pack('>IIBBBBB', width, height, 8, 6, 0, 0, 0)))
        f.write(chunk(b'IDAT', zlib.compress(bytes(raw), 9)))
        f.write(chunk(b'IEND', b''))


# --------------------------------------------------------------------------
# Colour helpers

def flatten(p):
    """An (r, g, b, a) pixel composited over black, as (r, g, b)."""
    a = p[3]
    if a == 255:
        return p[0], p[1], p[2]
    return p[0] * a // 255, p[1] * a // 255, p[2] * a // 255


def luma(p):
    return 0.299 * p[0] + 0.587 * p[1] + 0.114 * p[2]


def _linear(c):
    c = c / 255.0
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def relative_luminance(p):
    return 0.2126 * _linear(p[0]) + 0.7152 * _linear(p[1]) + 0.0722 * _linear(p[2])


def contrast_ratio(a, b):
    la = relative_luminance(a)
    lb = relative_luminance(b)
    if la < lb:
        la, lb = lb, la
    return (la + 0.05) / (lb + 0.05)


def grey(v):
    v = int(round(v))
    return (v, v, v)


def quantile(values, q):
    ordered = sorted(values)
    if not ordered:
        return None
    return ordered[min(len(ordered) - 1, max(0, int(round(q * (len(ordered) - 1)))))]


def median(values):
    return quantile(values, 0.5)


def bbox(points):
    xs = [p[0] for p in points]
    ys = [p[1] for p in points]
    return '%d,%d-%d,%d' % (min(xs), min(ys), max(xs), max(ys))


def best_offset(copy, main):
    """The shift (dx, dy), each 0..3, that maps pixels of the main run onto
    the most pixels of the copy, and the share of the copy it explains. Of
    shifts that explain about as much (bold strokes are several pixels wide,
    so shifting by one more pixel can land inside them too), the shortest."""
    main_set = set(main)
    if not copy or not main_set:
        return (0, 0, 0.0)
    shares = []
    for dy in range(0, 4):
        for dx in range(0, 4):
            if dx or dy:
                hits = sum(1 for (x, y) in copy if (x - dx, y - dy) in main_set)
                shares.append((hits / float(len(copy)), dx, dy))
    top = max(share for (share, _, _) in shares)
    share, dx, dy = min((s for s in shares if s[0] >= top - 0.05), key=lambda s: (s[1] + s[2], -s[0]))
    return (dx, dy, share)


# --------------------------------------------------------------------------
# Checks

class Report(object):
    def __init__(self, mode, label=None):
        self.mode = mode
        self.label = label or mode
        self.passed = 0
        self.failed = 0

    def check(self, name, ok, detail):
        if ok:
            self.passed += 1
        else:
            self.failed += 1
        line = '%s %s %s: %s' % ('PASS' if ok else 'FAIL', self.label, name, detail)
        print(line)
        sys.stdout.flush()


def label_colour(lums):
    """For a label's pixels as (x, y, L, background L): the median
    background, the side of it the label is on (+1 brighter, -1 darker) and
    the label's own colour, the far end of its pixels (the 2% quantile)."""
    background = median([b for (_, _, _, b) in lums])
    sign = 1.0 if sum(l - b for (_, _, l, b) in lums) >= 0 else -1.0
    far = quantile([sign * (l - b) for (_, _, l, b) in lums], 0.98)
    return background, sign, background + sign * far


def analyse_label_pixels(report, name, pixels, mode, where, check_background=True):
    """pixels: list of (x, y, rgb, background rgb) for the label's pixels.
    check_background: whether the background must follow the mode (not for
    tabs, whose native faces are light in both modes)."""
    source = LABEL_SOURCES.get(name, BUTTON_SOURCE)
    if len(pixels) < MIN_LABEL_PIXELS:
        report.check(name + ' drawn', False,
                     'only %d label pixels found (%s); the label was not drawn, '
                     'or was drawn in the background colour' % (len(pixels), where))
        return
    report.check(name + ' drawn', True, '%d label pixels (%s)' % (len(pixels), where))

    target = DISABLED_GREY[mode]
    lums = [(x, y, luma(c), luma(b)) for (x, y, c, b) in pixels]
    background, sign, colour = label_colour(lums)
    dark_background = background < 128

    if not check_background:
        pass
    elif mode == 'dark':
        ok = background < DARK_BACKGROUND_MAX
        report.check(name + ' background', ok,
                     'median background under the label L=%.0f (%s L<%d in dark mode%s)' %
                     (background, 'expected' if ok else 'FAILED: expected', DARK_BACKGROUND_MAX,
                      '' if ok else '; the dark background colours were not applied, see '
                      'MCWin32UpdateSystemColors in engine/src/w32dcs.cpp'))
    else:
        ok = background > LIGHT_BACKGROUND_MIN
        report.check(name + ' background', ok,
                     'median background under the label L=%.0f (%s L>%d in light mode)' %
                     (background, 'expected' if ok else 'FAILED: expected', LIGHT_BACKGROUND_MIN))

    # The copy: pixels on the far side of the background, or near-white on a
    # dark background
    copy = []
    for (x, y, l, b) in lums:
        if sign * (l - b) < -OPPOSITE_TOLERANCE or (b < DARK_BACKGROUND_MAX and l > DARK_MAX_LABEL_L):
            copy.append((x, y, l))
    in_copy = set((x, y) for (x, y, _) in copy)
    main = [(x, y) for (x, y, l, b) in lums
            if (x, y) not in in_copy and abs(l - b) >= 0.25 * abs(target - b)]
    if len(copy) <= STRAY_PIXELS:
        report.check(name + ' copy', True,
                     'no offset copy: %d pixel(s) on the far side of the background%s' %
                     (len(copy), ', none brighter than L=%d' % DARK_MAX_LABEL_L if dark_background else ''))
    else:
        dx, dy, share = best_offset([(x, y) for (x, y, _) in copy], main)
        offset = ''
        if share >= 0.5:
            offset = '; %.0f%% of them are the label shifted by (+%d,+%d) px' % (100 * share, dx, dy)
        brightest = max(l for (_, _, l) in copy)
        report.check(name + ' copy', False,
                     '%d pixels of a second copy of the label (brightest L=%.0f, at %s in %s)%s: '
                     'the disabled label is still drawn engraved, a copy in the 3D highlight colour '
                     'under the label (%s)' %
                     (len(copy), brightest, bbox(copy), where, offset, source))

    # The label's own colour
    ok = abs(colour - target) <= GREY_TOLERANCE
    report.check(name + ' colour', ok,
                 'label colour L=%.0f, %s the disabled grey %d (+-%d)%s' %
                 (colour, 'matches' if ok else 'FAILED: expected', target, GREY_TOLERANCE,
                  '' if ok else '; 160 is the 3D shadow colour of an engraved label and 255 its '
                  'highlight copy (%s)' % source))

    # One run of grey glyphs: every pixel between the background and the grey
    beyond = [(x, y, l) for (x, y, l, b) in lums
              if sign * (l - b) > sign * (target - b) + GREY_TOLERANCE or sign * (l - b) < -OPPOSITE_TOLERANCE]
    ok = len(beyond) <= STRAY_PIXELS
    if ok:
        detail = 'every label pixel lies between the background and the disabled grey (%d outside)' % len(beyond)
    else:
        detail = ('%d label pixels (at %s) are not a blend of the background and the disabled grey %d '
                  '(their L from %.0f to %.0f): something other than one flat grey run is drawn there (%s)' %
                  (len(beyond), bbox(beyond), target, min(l for (_, _, l) in beyond),
                   max(l for (_, _, l) in beyond), source))
    report.check(name + ' single run', ok, detail)

    # On a dark background (the tabs' native faces stay light in dark mode)
    if mode == 'dark' and dark_background:
        ratio = contrast_ratio(grey(colour), grey(background))
        ok = ratio >= MIN_CONTRAST
        report.check(name + ' contrast', ok,
                     '%.2f:1 between the label (L=%.0f) and its background (L=%.0f), %s %.1f:1' %
                     (ratio, colour, background, 'at least' if ok else 'FAILED: needs at least', MIN_CONTRAST))


def label_pixels(rows, ref):
    """The pixels of a label, as (x, y, rgb, background rgb): those of rows
    that differ from ref, the same render without the label."""
    pixels = []
    for y in range(len(rows)):
        for x in range(len(rows[y])):
            c = flatten(rows[y][x])
            b = flatten(ref[y][x])
            if max(abs(c[0] - b[0]), abs(c[1] - b[1]), abs(c[2] - b[2])) > LABEL_DIFF:
                pixels.append((x, y, c, b))
    return pixels


def label_core(pixels, colour):
    """The (x, y) of the label pixels at least CORE_SHARE of the way from
    their background to colour, the label colour's L: the pixels its glyphs
    cover by at least CORE_SHARE, whatever colour they are drawn in, so a
    label drawn once has the same core in any colour."""
    core = set()
    for (x, y, c, b) in pixels:
        lb = luma(b)
        if abs(luma(c) - lb) >= CORE_SHARE * abs(colour - lb):
            core.add((x, y))
    return core


def check_shape(report, name, pixels, enabled_pixels, where):
    """Compares the core of the disabled label (pixels, in the disabled grey)
    with the core of the same control's label enabled (enabled_pixels, in
    the colour measured the way the colour check does it)."""
    source = LABEL_SOURCES.get(name, BUTTON_SOURCE)
    if len(enabled_pixels) < MIN_LABEL_PIXELS:
        report.check(name + ' shape', False,
                     'only %d label pixels in the enabled render (%s), so the disabled label cannot be '
                     'compared with it' % (len(enabled_pixels), where))
        return
    _, _, enabled_colour = label_colour([(x, y, luma(c), luma(b)) for (x, y, c, b) in enabled_pixels])
    disabled_core = label_core(pixels, DISABLED_GREY[report.mode])
    enabled_core = label_core(enabled_pixels, enabled_colour)
    union = disabled_core | enabled_core
    overlap = len(disabled_core & enabled_core) / float(len(union)) if union else 0.0
    growth = len(disabled_core) / float(len(enabled_core)) if enabled_core else float('inf')
    ok = growth <= SHAPE_MAX_GROWTH and overlap >= SHAPE_MIN_OVERLAP
    detail = ('core of the disabled label %d px, of the enabled label (L=%.0f) %d px (%+.0f%%), overlap %.2f' %
              (len(disabled_core), enabled_colour, len(enabled_core), 100 * (growth - 1), overlap))
    limits = 'at most %+.0f%% and an overlap of at least %.2f' % (100 * (SHAPE_MAX_GROWTH - 1), SHAPE_MIN_OVERLAP)
    if ok:
        report.check(name + ' shape', True, '%s (%s): drawn once, like the enabled label' % (detail, limits))
        return
    extra = sorted(disabled_core - enabled_core)
    dx, dy, share = best_offset(extra, sorted(enabled_core))
    offset = ''
    if extra and share >= 0.5:
        offset = '; %.0f%% of the %d extra pixels are the label shifted by (+%d,+%d) px' % (
            100 * share, len(extra), dx, dy)
    report.check(name + ' shape', False,
                 '%s, FAILED: expected %s (%s)%s: the disabled label is not drawn once like the enabled one, '
                 'a second copy in the same colour, for example (%s)' % (detail, limits, where, offset, source))


def check_label(report, folder, name, image, reference, enabled=None, enabled_reference=None):
    try:
        w, h, rows = read_png(os.path.join(folder, image))
        rw, rh, ref = read_png(os.path.join(folder, reference))
    except (IOError, OSError, PNGError, zlib.error) as e:
        report.check(name + ' drawn', False, 'cannot read the images: %s' % e)
        return
    if (w, h) != (rw, rh):
        report.check(name + ' drawn', False, '%s is %dx%d but %s is %dx%d' % (image, w, h, reference, rw, rh))
        return
    pixels = label_pixels(rows, ref)
    analyse_label_pixels(report, name, pixels, report.mode, image)

    # The shape, against the enabled renders (when the label was drawn at all)
    if not enabled or not enabled_reference or len(pixels) < MIN_LABEL_PIXELS:
        return
    try:
        ew, eh, enabled_rows = read_png(os.path.join(folder, enabled))
        erw, erh, enabled_ref = read_png(os.path.join(folder, enabled_reference))
    except (IOError, OSError, PNGError, zlib.error) as e:
        report.check(name + ' shape', False, 'cannot read the enabled images: %s' % e)
        return
    if (ew, eh) != (w, h) or (erw, erh) != (w, h):
        report.check(name + ' shape', False, '%s is %dx%d and %s %dx%d, but %s is %dx%d' %
                     (enabled, ew, eh, enabled_reference, erw, erh, image, w, h))
        return
    check_shape(report, name, pixels, label_pixels(enabled_rows, enabled_ref), '%s against %s' % (image, enabled))


def check_tab(report, folder, name, image):
    """The first tabs of the panel are disabled and fill its width. Their
    text is measured against the colour of the tab face."""
    try:
        w, h, rows = read_png(os.path.join(folder, image))
    except (IOError, OSError, PNGError, zlib.error) as e:
        report.check(name + ' drawn', False, 'cannot read %s: %s' % (image, e))
        return
    rgb = [[flatten(p) for p in row] for row in rows]

    # The face colour: the commonest colour in the rows above the text
    counts = {}
    for y in range(4, min(10, h)):
        for x in range(4, w - 4):
            counts[rgb[y][x]] = counts.get(rgb[y][x], 0) + 1
    if not counts:
        report.check(name + ' drawn', False, '%s is too small (%dx%d)' % (image, w, h))
        return
    face = max(counts, key=counts.get)
    face_l = luma(face)

    def is_face(p):
        return abs(luma(p) - face_l) <= 12

    # The bottom of the tab strip: the longest run of face colour down one of
    # the columns left of the first label (which starts 8 to 11 pixels into
    # the tab)
    top = 4
    bottom = top
    for x in range(4, min(10, w)):
        y = top
        while y < h and is_face(rgb[y][x]):
            y += 1
        bottom = max(bottom, y)
    if bottom - top < 10:
        report.check(name + ' drawn', False,
                     'cannot find the tab face in %s: the colour %s runs down no column from row %d '
                     'further than row %d' % (image, face, top, bottom - 1))
        return

    region = [(x, y) for y in range(top, bottom) for x in range(4, w - 4)]
    ink = set((x, y) for (x, y) in region if abs(luma(rgb[y][x]) - face_l) > 24)
    # Tab borders are lines across the whole strip (text never is, there is
    # face above the capitals): leave those rows and columns out
    rows_n = bottom - top
    cols_n = w - 8
    line_cols = set()
    for x in range(4, w - 4):
        if sum(1 for y in range(top, bottom) if (x, y) in ink) >= 0.9 * rows_n:
            line_cols.update((x - 1, x, x + 1))
    line_rows = set()
    for y in range(top, bottom):
        if sum(1 for x in range(4, w - 4) if (x, y) in ink) >= 0.9 * cols_n:
            line_rows.update((y - 1, y, y + 1))

    def inside(x, y):
        return x not in line_cols and y not in line_rows

    target = DISABLED_GREY[report.mode]
    pixels = []
    for (x, y) in region:
        if not inside(x, y):
            continue
        c = rgb[y][x]
        if (x, y) in ink:
            pixels.append((x, y, c, face))
        elif luma(c) - face_l > OPPOSITE_TOLERANCE and face_l > luma(grey(target)):
            # Lighter than a light face: a candidate for the highlight copy.
            # Only pixels next to (right of or below) the text count, so that
            # a highlight line of the face itself does not.
            near = any((x - dx, y - dy) in ink and inside(x - dx, y - dy)
                       for dx in range(0, 4) for dy in range(0, 4) if dx or dy)
            if near:
                pixels.append((x, y, c, face))
    where = '%s, tab face %s L=%.0f, rows %d-%d' % (image, face, face_l, top, bottom - 1)
    analyse_label_pixels(report, name, pixels, report.mode, where, check_background=False)


def parse_region(text):
    """x,y,width,height from render.txt as a tuple of 4 ints, or None."""
    try:
        region = tuple(int(float(v)) for v in text.split(','))
    except ValueError:
        return None
    return region if len(region) == 4 else None


def region_box(region, w, h):
    """The region (x, y, width, height) inside a w x h image, as the box
    (x0, y0, x1, y1) with x1 and y1 exclusive, or None when too little of it
    is inside."""
    x0, y0, rw, rh = region
    x0 = max(0, x0)
    y0 = max(0, y0)
    x1 = min(w, x0 + rw)
    y1 = min(h, y0 + rh)
    if x1 - x0 < 2 or y1 - y0 < 4:
        return None
    return x0, y0, x1, y1


def box_mean(rows, box):
    x0, y0, x1, y1 = box
    values = [luma(flatten(rows[y][x])) for y in range(y0, y1) for x in range(x0, x1)]
    return sum(values) / len(values)


def check_track(report, folder, name, image, region):
    try:
        w, h, rows = read_png(os.path.join(folder, image))
    except (IOError, OSError, PNGError, zlib.error) as e:
        report.check(name + ' track', False, 'cannot read %s: %s' % (image, e))
        return
    box = region_box(region, w, h)
    if box is None:
        report.check(name + ' track', False, 'the track region %s is outside %s (%dx%d)' % (region, image, w, h))
        return
    x0, y0, x1, y1 = box
    mean = box_mean(rows, box)
    where = 'mean L=%.0f over the track at %d,%d-%d,%d of %s' % (mean, x0, y0, x1 - 1, y1 - 1, image)
    if report.mode == 'dark':
        ok = mean < TRACK_DARK_MAX
        report.check(name + ' track', ok,
                     '%s, %s L<%d%s' % (where, 'expected' if ok else 'FAILED: expected', TRACK_DARK_MAX,
                                        '' if ok else ': the scrollbar is drawn with the light theme class; see '
                                        'MCNativeTheme::OpenScrollbarTheme in engine/src/w32theme.cpp'))
    else:
        ok = mean > TRACK_LIGHT_MIN
        report.check(name + ' track', ok,
                     '%s, %s L>%d%s' % (where, 'expected' if ok else 'FAILED: expected', TRACK_LIGHT_MIN,
                                        '' if ok else ': a light-mode scrollbar must stay light; see '
                                        'MCNativeTheme::OpenScrollbarTheme in engine/src/w32theme.cpp'))


def check_thumb(report, folder, name, image, region, track_region):
    """The thumb is somewhere in region, which lies between the up arrow and
    the track region: a run of rows whose mean differs from the track's."""
    check = name + ' thumb'
    if track_region is None:
        report.check(check, False, 'render.txt has no track region for %s to compare the thumb with' % name)
        return
    try:
        w, h, rows = read_png(os.path.join(folder, image))
    except (IOError, OSError, PNGError, zlib.error) as e:
        report.check(check, False, 'cannot read %s: %s' % (image, e))
        return
    box = region_box(region, w, h)
    track_box = region_box(track_region, w, h)
    if box is None or track_box is None:
        report.check(check, False, 'the thumb region %s or the track region %s is outside %s (%dx%d)' %
                     (region, track_region, image, w, h))
        return
    track = box_mean(rows, track_box)
    x0, y0, x1, y1 = box
    means = [box_mean(rows, (x0, y, x1, y + 1)) for y in range(y0, y1)]

    def is_thumb(m):
        # In dark mode a thumb darker than the track is as good as missing
        return m - track >= THUMB_MIN_DIFF if report.mode == 'dark' else abs(m - track) >= THUMB_MIN_DIFF

    best_start, best_length, start = 0, 0, None
    for i, m in enumerate(means + [track]):
        if i < len(means) and is_thumb(m):
            if start is None:
                start = i
        elif start is not None:
            if i - start > best_length:
                best_start, best_length = start, i - start
            start = None
    where = 'rows %d-%d, columns %d-%d of %s' % (y0, y1 - 1, x0, x1 - 1, image)
    wanted = '%d consecutive rows whose mean L differs from the track\'s (L=%.0f) by %d or more%s' % (
        THUMB_MIN_ROWS, track, THUMB_MIN_DIFF, ', brighter' if report.mode == 'dark' else '')
    if best_length >= THUMB_MIN_ROWS:
        thumb = means[best_start:best_start + best_length]
        report.check(check, True, 'thumb at rows %d-%d, mean L=%.0f on the track\'s L=%.0f (%s; expected %s)' %
                     (y0 + best_start, y0 + best_start + best_length - 1, sum(thumb) / len(thumb), track,
                      where, wanted))
    else:
        report.check(check, False,
                     'no thumb in %s, FAILED: expected %s; the rows have a mean L from %.0f to %.0f and the '
                     'longest run is %d: the scrollbar is drawn without a visible thumb; see '
                     'MCNativeTheme::OpenScrollbarTheme, MCWin32ThemePartDrawsDark and drawdarkscrollbarpart '
                     'in engine/src/w32theme.cpp' %
                     (where, wanted, min(means), max(means), best_length))


def read_manifest(folder):
    info = {}
    shots = []
    with open(os.path.join(folder, 'render.txt'), 'r', encoding='utf-8', errors='replace') as f:
        for line in f:
            fields = line.rstrip('\r\n').split('\t')
            if fields[0] == 'INFO' and len(fields) >= 3:
                info[fields[1]] = fields[2]
            elif fields[0] == 'SHOT' and len(fields) >= 4:
                shots.append(fields[1:])
            elif fields[0] == 'ERROR':
                info.setdefault('error', '\t'.join(fields[1:]))
    return info, shots


# --------------------------------------------------------------------------
# The appearance scenarios: text, face and region shots

def _median_rgb(colours):
    return tuple(median([c[i] for c in colours]) for i in range(3))


def measure_text(rows, ref):
    """The text of a text shot: the pixels that differ from the render
    without it. Returns (count, text rgb, background rgb) or (count, None,
    None) when there are too few pixels. The text colour is the median of its
    core, the pixels at least TEXT_CORE_SHARE of the way from their
    background to the far end (the 2% quantile, as for labels): ClearType
    fringes and antialiased edges stay out of it."""
    pixels = label_pixels(rows, ref)
    if len(pixels) < MIN_LABEL_PIXELS:
        return len(pixels), None, None
    lums = [(x, y, luma(c), luma(b)) for (x, y, c, b) in pixels]
    _, sign, colour = label_colour(lums)
    far = quantile([sign * (l - b) for (_, _, l, b) in lums], 0.98)
    core = [c for (x, y, c, b) in pixels if sign * (luma(c) - luma(b)) >= TEXT_CORE_SHARE * far]
    if not core:
        core = [c for (x, y, c, b) in pixels]
    return len(pixels), _median_rgb(core), _median_rgb([b for (_, _, _, b) in pixels])


def measure_face(rows, ref):
    """The pixels of a face shot (those that change when the control is
    hidden): (count, median L of them, far-end L from what is under them,
    mean L inside their bounding box shrunk by 30% on each side, bbox)."""
    pixels = label_pixels(rows, ref)
    if len(pixels) < MIN_LABEL_PIXELS:
        return len(pixels), None, None, None, None
    lums = [(x, y, luma(c), luma(b)) for (x, y, c, b) in pixels]
    _, _, far = label_colour(lums)
    xs = [p[0] for p in pixels]
    ys = [p[1] for p in pixels]
    x0, x1, y0, y1 = min(xs), max(xs), min(ys), max(ys)
    dx = int((x1 - x0) * 0.3)
    dy = int((y1 - y0) * 0.3)
    inside = [luma(flatten(rows[y][x])) for y in range(y0 + dy, y1 - dy + 1) for x in range(x0 + dx, x1 - dx + 1)]
    interior = sum(inside) / len(inside) if inside else None
    return (len(pixels), median([l for (_, _, l, _) in lums]), far, interior,
            '%d,%d-%d,%d' % (x0, y0, x1, y1))


def expected_checks(name, mode):
    table = EXPECT.get(name, {})
    return table.get('*', []) + table.get(mode, [])


def _load_pair(report, folder, name, image, reference):
    try:
        w, h, rows = read_png(os.path.join(folder, image))
        rw, rh, ref = read_png(os.path.join(folder, reference))
    except (IOError, OSError, PNGError, zlib.error) as e:
        report.check(name + ' drawn', False, 'cannot read the images: %s' % e)
        return None, None
    if (w, h) != (rw, rh):
        report.check(name + ' drawn', False, '%s is %dx%d but %s is %dx%d' % (image, w, h, reference, rw, rh))
        return None, None
    return rows, ref


def _fmt(rgb):
    return '%d,%d,%d' % tuple(int(round(v)) for v in rgb)


def check_text(report, folder, name, image, reference):
    wanted = expected_checks(name, report.mode)
    if not wanted:
        return
    rows, ref = _load_pair(report, folder, name, image, reference)
    if rows is None:
        return
    count, text, background = measure_text(rows, ref)
    where = '%s against %s' % (image, reference)
    if text is None:
        report.check(name + ' drawn', False, 'only %d text pixels (%s): the text was not drawn, or was drawn in '
                     'the colour of what is under it' % (count, where))
        return
    l_text = luma(text)
    ratio = contrast_ratio(text, background)
    measured = 'text %s (L=%.0f) on %s (L=%.0f), %.2f:1, %d pixels (%s)' % (
        _fmt(text), l_text, _fmt(background), luma(background), ratio, count, where)
    for want in wanted:
        kind = want[0]
        if kind == 'record':
            report.check(name + ' recorded', True, measured + '; recorded only')
        elif kind == 'text_min_l':
            report.check(name + ' colour', l_text >= want[1], '%s, %s L>=%.0f' % (
                measured, 'expected' if l_text >= want[1] else 'FAILED: expected', want[1]))
        elif kind == 'text_max_l':
            report.check(name + ' colour', l_text <= want[1], '%s, %s L<=%.0f' % (
                measured, 'expected' if l_text <= want[1] else 'FAILED: expected', want[1]))
        elif kind == 'text_near_l':
            ok = abs(l_text - want[1]) <= want[2]
            report.check(name + ' colour', ok, '%s, %s L=%.0f (+-%d): the colour set for it' % (
                measured, 'expected' if ok else 'FAILED: expected', want[1], want[2]))
        elif kind == 'text_red':
            ok = text[0] > 150 and text[1] < 80 and text[2] < 80
            report.check(name + ' colour', ok, '%s, %s red (R>150, G<80, B<80)' % (
                measured, 'expected' if ok else 'FAILED: expected'))
        elif kind == 'contrast':
            ok = ratio >= want[1]
            report.check(name + ' contrast', ok, '%s, %s %.1f:1' % (
                measured, 'at least' if ok else 'FAILED: needs at least', want[1]))


def check_face(report, folder, name, image, reference):
    wanted = expected_checks(name, report.mode)
    if not wanted:
        return
    rows, ref = _load_pair(report, folder, name, image, reference)
    if rows is None:
        return
    count, med, far, interior, box = measure_face(rows, ref)
    where = '%s against %s' % (image, reference)
    if med is None:
        report.check(name + ' drawn', False, 'only %d pixels change when it is hidden (%s)' % (count, where))
        return
    measured = '%d pixels at %s, median L=%.0f, far end L=%.0f, inside L=%s (%s)' % (
        count, box, med, far, '-' if interior is None else '%.0f' % interior, where)
    for want in wanted:
        kind, value = want[0], want[1]
        if kind == 'interior_min_l':
            ok = interior is not None and interior >= value
            report.check(name + ' inside', ok, '%s, %s inside L>=%d' % (
                measured, 'expected' if ok else 'FAILED: expected', value))
        elif kind == 'face_median_min_l':
            ok = med >= value
            report.check(name + ' face', ok, '%s, %s median L>=%d' % (
                measured, 'expected' if ok else 'FAILED: expected', value))
        elif kind == 'face_far_min_l':
            ok = far >= value
            report.check(name + ' colour', ok, '%s, %s far end L>=%d' % (
                measured, 'expected' if ok else 'FAILED: expected', value))
        elif kind == 'face_far_max_l':
            ok = far <= value
            report.check(name + ' colour', ok, '%s, %s far end L<=%d' % (
                measured, 'expected' if ok else 'FAILED: expected', value))


def check_region(report, folder, name, image, region):
    wanted = expected_checks(name, report.mode)
    if not wanted:
        return
    try:
        w, h, rows = read_png(os.path.join(folder, image))
    except (IOError, OSError, PNGError, zlib.error) as e:
        report.check(name + ' drawn', False, 'cannot read %s: %s' % (image, e))
        return
    box = region_box(region, w, h) if region is not None else None
    if box is None:
        report.check(name + ' drawn', False, 'the region %s is outside %s (%dx%d)' % (region, image, w, h))
        return
    mean = box_mean(rows, box)
    measured = 'mean L=%.0f at %d,%d-%d,%d of %s' % (mean, box[0], box[1], box[2] - 1, box[3] - 1, image)
    for want in wanted:
        kind = want[0]
        if kind == 'region_min_l':
            ok = mean >= want[1]
            report.check(name + ' colour', ok, '%s, %s L>=%d' % (measured, 'expected' if ok else 'FAILED: expected', want[1]))
        elif kind == 'region_near_l':
            ok = abs(mean - want[1]) <= want[2]
            report.check(name + ' colour', ok, '%s, %s L=%d (+-%d)' % (
                measured, 'expected' if ok else 'FAILED: expected', want[1], want[2]))


def check_appearance_info(report, info, system):
    """The systemAppearance and the appAppearance the run reports."""
    appearance = info.get('systemAppearance', '')
    report.check('system appearance', appearance == system,
                 'the engine reports the systemAppearance "%s"%s' %
                 (appearance, '' if appearance == system else
                  ' but the test set AppsUseLightTheme for %s mode; see render-test.ps1 and '
                  'MCScreenDC::getsystemappearance in engine/src/w32dc.cpp' % system))
    if info.get('hasAppAppearance') != 'true':
        return
    start = info.get('appAppearanceAtStart', '')
    report.check('appAppearance default', start == 'light',
                 'the appAppearance is "%s" before the test sets it%s' %
                 (start, '' if start == 'light' else ', FAILED: expected "light", the default of every engine '
                  '(MCappappearance, engine/src/appearance.cpp)'))
    effective = info.get('effectiveAppAppearance', '')
    report.check('effective appAppearance', effective == report.mode,
                 'the effective appAppearance is "%s" (the appAppearance "%s", requested "%s", systemAppearance '
                 '"%s")%s' % (effective, info.get('appAppearance', ''), info.get('requestedAppearance', ''),
                              appearance, '' if effective == report.mode else
                              ', FAILED: expected "%s" (MCAppearanceIsDark, engine/src/appearance.cpp)' % report.mode))


def run(mode, folder, system=None, label=None):
    report = Report(mode, label)
    if system is None:
        system = mode
    try:
        info, shots = read_manifest(folder)
    except (IOError, OSError) as e:
        print('FAIL %s engine run: cannot read render.txt in %s: %s' % (report.label, folder, e))
        print('SUMMARY passed=0 failed=1')
        return 101

    if 'error' in info:
        report.check('engine run', False, 'the render script stopped with an error: %s' % info['error'])
    if info.get('done') != 'true':
        report.check('engine run', False, 'render.txt is incomplete (no "done" line); see the engine output')

    look = info.get('lookAndFeel', '')
    report.check('native theme', look == 'Appearance Manager',
                 'the lookAndFeel is "%s"%s' % (look, '' if look == 'Appearance Manager' else
                                                 ', not "Appearance Manager": the native Windows theme did not '
                                                 'load (visual styles are off in this session?), so the flat '
                                                 'labels and dark scrollbars of the native theme are not tested'))
    check_appearance_info(report, info, system)

    # A thumb is compared with the track of the same scrollbar
    tracks = dict((shot[1], parse_region(shot[3])) for shot in shots if shot[0] == 'track' and len(shot) >= 4)
    for shot in shots:
        kind, name = shot[0], shot[1]
        if kind == 'label' and len(shot) >= 4:
            # The enabled pair, for the shape, is optional
            enabled = shot[4:6] if len(shot) >= 6 else [None, None]
            check_label(report, folder, name, shot[2], shot[3], enabled[0], enabled[1])
        elif kind == 'tab':
            check_tab(report, folder, name, shot[2])
        elif kind in ('track', 'thumb') and len(shot) >= 4:
            region = parse_region(shot[3])
            if region is None:
                report.check(name + ' ' + kind, False, 'bad %s region "%s" in render.txt' % (kind, shot[3]))
            elif kind == 'track':
                check_track(report, folder, name, shot[2], region)
            else:
                check_thumb(report, folder, name, shot[2], region, tracks.get(name))
        elif name.startswith('s8-'):
            # Compared with s2 of another run (--compare)
            continue
        elif kind == 'text' and len(shot) >= 4:
            check_text(report, folder, name, shot[2], shot[3])
        elif kind == 'face' and len(shot) >= 4:
            check_face(report, folder, name, shot[2], shot[3])
        elif kind == 'region' and len(shot) >= 4:
            check_region(report, folder, name, shot[2], parse_region(shot[3]))
    if not shots:
        report.check('images', False, 'render.txt lists no images')

    print('SUMMARY passed=%d failed=%d' % (report.passed, report.failed))
    return min(report.failed, 100)


# --------------------------------------------------------------------------
# Comparing the images of two runs

def compare_images(path_a, path_b):
    """(mean absolute channel difference, share of pixels that differ by more
    than COMPARE_PIXEL_DIFF, the bbox of those, None) or (.., .., .., error)."""
    wa, ha, a = read_png(path_a)
    wb, hb, b = read_png(path_b)
    if (wa, ha) != (wb, hb):
        return None, None, None, 'the sizes differ: %dx%d and %dx%d' % (wa, ha, wb, hb)
    total = 0
    count = 0
    xs = []
    ys = []
    for y in range(ha):
        ra = a[y]
        rb = b[y]
        for x in range(wa):
            pa = flatten(ra[x])
            pb = flatten(rb[x])
            d0 = abs(pa[0] - pb[0])
            d1 = abs(pa[1] - pb[1])
            d2 = abs(pa[2] - pb[2])
            total += d0 + d1 + d2
            if max(d0, d1, d2) > COMPARE_PIXEL_DIFF:
                count += 1
                xs.append(x)
                ys.append(y)
    pixels = float(max(1, wa * ha))
    box = '%d,%d-%d,%d' % (min(xs), min(ys), max(xs), max(ys)) if xs else '-'
    return total / (3 * pixels), count / pixels, box, None


def _matches(name, patterns):
    import fnmatch
    return any(fnmatch.fnmatchcase(name, p) for p in patterns)


def compare(folder_a, folder_b, only=None, exclude=None, rename=None, info_keys=None, label=None):
    """Compares the images of folder_a with those of folder_b; see the
    module's description."""
    report = Report('compare', label or 'compare')
    only = only or []
    exclude = list(exclude or []) + list(COMPARE_NEVER)
    old_prefix, new_prefix = None, None
    if rename:
        old_prefix, new_prefix = rename.split('=', 1)
    try:
        names = sorted(n for n in os.listdir(folder_a) if n.lower().endswith('.png'))
    except (IOError, OSError) as e:
        report.check('images', False, 'cannot list %s: %s' % (folder_a, e))
        names = []
    names = [n for n in names if (not only or _matches(n, only)) and not _matches(n, exclude)]
    if not names:
        report.check('images', False, 'no images in %s match %s' % (folder_a, ', '.join(only) or '*'))
    for name in names:
        other = name
        if old_prefix is not None and name.startswith(old_prefix):
            other = new_prefix + name[len(old_prefix):]
        path_a = os.path.join(folder_a, name)
        path_b = os.path.join(folder_b, other)
        title = name if other == name else '%s=%s' % (name, other)
        if not os.path.exists(path_b):
            report.check(title, False, '%s has no %s to compare with' % (folder_b, other))
            continue
        try:
            mean, share, box, error = compare_images(path_a, path_b)
        except (IOError, OSError, PNGError, zlib.error) as e:
            report.check(title, False, 'cannot read the images: %s' % e)
            continue
        if error:
            report.check(title, False, error)
            continue
        ok = mean <= COMPARE_MAX_MEAN and share <= COMPARE_MAX_SHARE
        report.check(title, ok, 'mean difference %.3f (at most %.1f), %.3f%% of the pixels differ by more than %d '
                     '(at most %.1f%%)%s' % (mean, COMPARE_MAX_MEAN, 100 * share, COMPARE_PIXEL_DIFF,
                                             100 * COMPARE_MAX_SHARE, '' if ok else ', at %s' % box))
    if info_keys:
        try:
            info_a, _ = read_manifest(folder_a)
            info_b, _ = read_manifest(folder_b)
        except (IOError, OSError) as e:
            report.check('info', False, 'cannot read render.txt: %s' % e)
            info_a, info_b = None, None
        if info_a is not None:
            for key in info_keys:
                va = info_a.get(key)
                vb = info_b.get(key)
                report.check('INFO ' + key, va is not None and va == vb, '"%s" and "%s"' % (va, vb))
    print('SUMMARY passed=%d failed=%d' % (report.passed, report.failed))
    return min(report.failed, 100)


# --------------------------------------------------------------------------
# Self-test: synthetic labels drawn flat and engraved, and scrollbar tracks

def _glyph_coverage(width, height):
    """Coverage 0..1 of a few bold strokes with antialiased edges, standing
    in for glyphs: vertical stems, a horizontal bar and a diagonal."""
    cover = [[0.0] * width for _ in range(height)]

    def box(x0, y0, x1, y1):
        for y in range(height):
            for x in range(width):
                cx = max(0.0, min(x + 1.0, x1) - max(float(x), x0))
                cy = max(0.0, min(y + 1.0, y1) - max(float(y), y0))
                cover[y][x] = min(1.0, cover[y][x] + cx * cy)

    for i in range(5):
        box(6.3 + 9 * i, 5.0, 8.9 + 9 * i, 17.0)
    box(6.3, 10.4, 46.0, 12.6)
    for k in range(10):
        box(50.2 + k, 5.0 + k, 52.6 + k, 6.2 + k)
    return cover


def _blend(background, colour, a):
    return tuple(int(round(b + (c - b) * a)) for b, c in zip(background, colour))


def _render(background, layers, width=64, height=22):
    cover = _glyph_coverage(width, height)
    rows = [[background] * width for _ in range(height)]
    for colour, dx, dy in layers:
        for y in range(height):
            for x in range(width):
                sx, sy = x - dx, y - dy
                if 0 <= sx < width and 0 <= sy < height and cover[sy][sx] > 0:
                    rows[y][x] = _blend(rows[y][x], colour, cover[sy][sx])
    return rows


def _scrollbar(track, thumb, glyph):
    """A vertical scrollbar 17 pixels wide and 100 high, the thumb at the
    top: the up arrow's glyph in rows 5-10, the thumb in rows 20-39 (inset by
    2, as drawdarkscrollbarpart draws it) and track elsewhere."""
    rows = [[track] * 17 for _ in range(100)]
    for i in range(6):
        for x in range(8 - i, 9 + i):
            rows[5 + i][x] = glyph
    for y in range(20, 40):
        for x in range(2, 15):
            rows[y][x] = thumb
    return rows


def _box(background, ring, inside, size=13, width=30, height=24):
    """A checkbox-like square: a one-pixel ring, filled inside, on background."""
    rows = [[background] * width for _ in range(height)]
    x0, y0 = 8, 5
    for y in range(size):
        for x in range(size):
            edge = y in (0, size - 1) or x in (0, size - 1)
            rows[y0 + y][x0 + x] = ring if edge else inside
    return rows


def _solid(colour, width=40, height=20):
    return [[colour] * width for _ in range(height)]


# Expectations of the self-test's synthetic shots (see EXPECT)
SELF_TEST_EXPECT = {
    'st-black-on-white': {'*': [('contrast', 7.0), ('text_max_l', 60)]},
    'st-white-on-white': {'*': [('contrast', 4.5)]},
    'st-grey-on-white': {'*': [('contrast', 4.5)]},
    'st-red': {'*': [('text_red',)]},
    'st-black-not-red': {'*': [('text_red',)]},
    'st-caption': {'*': [('text_near_l', _l(138, 146, 158), 12)]},
    'st-caption-black': {'*': [('text_near_l', _l(138, 146, 158), 12)]},
    'st-box-light': {'*': [('interior_min_l', 200)]},
    'st-box-dark': {'*': [('interior_min_l', 200)]},
    'st-face-light': {'*': [('face_median_min_l', 180)]},
    'st-face-dark': {'*': [('face_median_min_l', 180)]},
    'st-region-32': {'*': [('region_near_l', 32, 8)]},
    'st-region-240': {'*': [('region_near_l', 32, 8)]},
}


def _self_test_compare(folder):
    """The comparison of two runs on synthetic images; returns the failures."""
    failures = []
    a = os.path.join(folder, 'compare-a')
    b = os.path.join(folder, 'compare-b')
    for d in (a, b):
        if not os.path.isdir(d):
            os.makedirs(d)
    base = _render((240, 240, 240), [((0, 0, 0), 0, 0)])
    write_png(os.path.join(a, 'same.png'), base)
    write_png(os.path.join(b, 'same.png'), base)
    # One pixel off by 20 of 64x22: 0.07%, and a tiny mean
    near = [list(r) for r in base]
    near[3][3] = (220, 220, 220)
    write_png(os.path.join(a, 'near.png'), base)
    write_png(os.path.join(b, 'near.png'), near)
    # The label in another colour: every text pixel differs
    write_png(os.path.join(a, 'other.png'), base)
    write_png(os.path.join(b, 'other.png'), _render((240, 240, 240), [((255, 255, 255), 0, 0)]))
    # A dark card where the other run has a light one
    write_png(os.path.join(a, 'card.png'), _solid((32, 32, 32)))
    write_png(os.path.join(b, 'card.png'), _solid((240, 240, 240)))
    # Different sizes, and an image the other run does not have
    write_png(os.path.join(a, 'size.png'), _solid((240, 240, 240), 40, 20))
    write_png(os.path.join(b, 'size.png'), _solid((240, 240, 240), 41, 20))
    write_png(os.path.join(a, 'alone.png'), base)
    # Renamed: s8-dark-x in A against s2-x in B
    write_png(os.path.join(a, 's8-dark-x.png'), base)
    write_png(os.path.join(b, 's2-x.png'), base)
    # A desktop snapshot is never compared
    write_png(os.path.join(a, 'screen.png'), _solid((1, 2, 3)))
    write_png(os.path.join(b, 'screen.png'), _solid((200, 100, 0)))
    for d, pen in ((a, '0,0,0'), (b, '255,255,255')):
        with open(os.path.join(d, 'render.txt'), 'w', encoding='utf-8', newline='\n') as f:
            f.write('INFO\tbrushColor\t240,240,240\n')
            f.write('INFO\tpenColor\t%s\n' % pen)
            f.write('INFO\tdone\ttrue\n')

    import io
    saved = sys.stdout
    sys.stdout = buffer = io.StringIO()
    try:
        compare(a, b, exclude=['s8-*'], info_keys=['brushColor', 'penColor'])
        compare(a, b, only=['s8-dark-*'], rename='s8-dark-=s2-')
    finally:
        sys.stdout = saved
    output = buffer.getvalue()
    print('--- self-test, compare')
    print(output, end='')
    results = {}
    for line in output.splitlines():
        if line.startswith(('PASS ', 'FAIL ')):
            check = line.split(' ', 2)[2].split(':', 1)[0]
            results[check] = line.startswith('PASS')
    wanted = [('same.png', True), ('near.png', True), ('other.png', False), ('card.png', False),
              ('size.png', False), ('alone.png', False), ('s8-dark-x.png=s2-x.png', True),
              ('INFO brushColor', True), ('INFO penColor', False)]
    for check, passed in wanted:
        if results.get(check) is not passed:
            failures.append('compare %s: expected %s, got %s' % (
                check, 'PASS' if passed else 'FAIL', {True: 'PASS', False: 'FAIL', None: 'no result'}[results.get(check)]))
    if 'screen.png' in results:
        failures.append('compare screen.png: compared, but a desktop snapshot must never be')
    return len(wanted), failures


def self_test(folder):
    import shutil
    import tempfile
    temporary = folder is None
    if temporary:
        folder = tempfile.mkdtemp(prefix='render-check-')
    failures = []
    expectations = []
    try:
        for mode, background in (('dark', (32, 32, 32)), ('light', (240, 240, 240))):
            g = (DISABLED_GREY[mode],) * 3
            path = os.path.join(folder, mode)
            if not os.path.isdir(path):
                os.makedirs(path)
            write_png(os.path.join(path, 'none.png'), _render(background, []))
            write_png(os.path.join(path, 'flat.png'), _render(background, [(g, 0, 0)]))
            # buttondraw.cpp before the fix: highlight copy at +1,+1, then the
            # label in the 3D shadow colour
            write_png(os.path.join(path, 'engraved.png'),
                      _render(background, [((255, 255, 255), 1, 1), ((160, 160, 160), 0, 0)]))
            # graphic.cpp before the fix: a disabled graphic's label in the
            # graphic's own foreColor
            write_png(os.path.join(path, 'graphic.png'), _render(background, [((200, 0, 0), 0, 0)]))
            # The label enabled, in the text colour of the mode, and one that
            # every colour check passes: the (+1,+1) pass kept, both in the
            # disabled grey
            text = (255, 255, 255) if mode == 'dark' else (0, 0, 0)
            write_png(os.path.join(path, 'enabled.png'), _render(background, [(text, 0, 0)]))
            write_png(os.path.join(path, 'double.png'), _render(background, [(g, 1, 1), (g, 0, 0)]))
            # Tabs before the fix: the copy one pixel down only
            face = (240, 240, 240)
            tab_rows = [[face] * 90 for _ in range(34)]
            for y, row in enumerate(_render(face, [((255, 255, 255), 0, 1), ((160, 160, 160), 0, 0)], 64, 22)):
                tab_rows[y + 8][10:74] = row
            write_png(os.path.join(path, 'tab-engraved.png'), tab_rows)
            tab_rows = [[face] * 90 for _ in range(34)]
            for y, row in enumerate(_render(face, [(g, 0, 0)], 64, 22)):
                tab_rows[y + 8][10:74] = row
            write_png(os.path.join(path, 'tab-flat.png'), tab_rows)
            # Scrollbars: the light uxtheme one, the dark one drawn by
            # drawdarkscrollbarpart, and none at all (the card colour)
            write_png(os.path.join(path, 'track-light.png'),
                      _scrollbar((240, 240, 240), (205, 205, 205), (96, 96, 96)))
            write_png(os.path.join(path, 'track-dark.png'),
                      _scrollbar((43, 43, 43), (110, 110, 110), (154, 154, 154)))
            write_png(os.path.join(path, 'blank.png'), [[background] * 17 for _ in range(100)])
            # The appearance scenarios: text on the owner's white fields, a
            # checkbox's box and a push face on a white panel, a card region
            white = (255, 255, 255)
            write_png(os.path.join(path, 'st-bare.png'), _render(white, []))
            write_png(os.path.join(path, 'st-black-on-white.png'), _render(white, [((0, 0, 0), 0, 0)]))
            write_png(os.path.join(path, 'st-white-on-white.png'), _render(white, [(white, 0, 0)]))
            write_png(os.path.join(path, 'st-grey-on-white.png'), _render(white, [((200, 200, 200), 0, 0)]))
            write_png(os.path.join(path, 'st-red.png'), _render(white, [((230, 20, 20), 0, 0)]))
            write_png(os.path.join(path, 'st-caption.png'), _render(white, [((138, 146, 158), 0, 0)]))
            write_png(os.path.join(path, 'st-box-bare.png'), _solid(white, 30, 24))
            write_png(os.path.join(path, 'st-box-light.png'), _box(white, (51, 51, 51), (250, 250, 250)))
            write_png(os.path.join(path, 'st-box-dark.png'), _box(white, (154, 154, 154), (32, 32, 32)))
            write_png(os.path.join(path, 'st-face-light.png'), _box(white, (173, 173, 173), (225, 225, 225), 18))
            write_png(os.path.join(path, 'st-face-dark.png'), _box(white, (110, 110, 110), (55, 55, 55), 18))
            write_png(os.path.join(path, 'st-region-32.png'), _solid((32, 32, 32)))
            write_png(os.path.join(path, 'st-region-240.png'), _solid((240, 240, 240)))
            with open(os.path.join(path, 'render.txt'), 'w', encoding='utf-8', newline='\n') as f:
                f.write('INFO\tlookAndFeel\tAppearance Manager\n')
                f.write('INFO\tsystemAppearance\t%s\n' % mode)
                f.write('INFO\thasAppAppearance\ttrue\n')
                f.write('INFO\tappAppearanceAtStart\tlight\n')
                f.write('INFO\teffectiveAppAppearance\t%s\n' % mode)
                for shot in ('st-black-on-white', 'st-white-on-white', 'st-grey-on-white', 'st-red', 'st-caption'):
                    f.write('SHOT\ttext\t%s\t%s.png\tst-bare.png\n' % (shot, shot))
                f.write('SHOT\ttext\tst-black-not-red\tst-black-on-white.png\tst-bare.png\n')
                f.write('SHOT\ttext\tst-caption-black\tst-black-on-white.png\tst-bare.png\n')
                for shot in ('st-box-light', 'st-box-dark', 'st-face-light', 'st-face-dark'):
                    f.write('SHOT\tface\t%s\t%s.png\tst-box-bare.png\n' % (shot, shot))
                f.write('SHOT\tregion\tst-region-32\tst-region-32.png\t5,5,20,10\n')
                f.write('SHOT\tregion\tst-region-240\tst-region-240.png\t5,5,20,10\n')
                f.write('SHOT\tlabel\tflat\tflat.png\tnone.png\tenabled.png\tnone.png\n')
                f.write('SHOT\tlabel\tdouble\tdouble.png\tnone.png\tenabled.png\tnone.png\n')
                f.write('SHOT\tlabel\tengraved\tengraved.png\tnone.png\n')
                f.write('SHOT\tlabel\tgraphic\tgraphic.png\tnone.png\n')
                f.write('SHOT\ttab\ttab-flat\ttab-flat.png\n')
                f.write('SHOT\ttab\ttab-engraved\ttab-engraved.png\n')
                for bar in ('track-light', 'track-dark', 'blank'):
                    f.write('SHOT\ttrack\t%s\t%s.png\t2,50,13,40\n' % (bar, bar))
                    f.write('SHOT\tthumb\t%s\t%s.png\t2,19,13,31\n' % (bar, bar))
                f.write('INFO\tdone\ttrue\n')

            print('--- self-test, %s mode' % mode)
            import io
            saved = sys.stdout
            sys.stdout = buffer = io.StringIO()
            saved_expect = dict(EXPECT)
            EXPECT.update(SELF_TEST_EXPECT)
            try:
                run(mode, path)
            finally:
                sys.stdout = saved
                EXPECT.clear()
                EXPECT.update(saved_expect)
            output = buffer.getvalue()
            print(output, end='')
            results = {}
            for line in output.splitlines():
                if line.startswith(('PASS ', 'FAIL ')):
                    check = line.split(' ', 2)[2].split(':', 1)[0]
                    results[check] = line.startswith('PASS')

            def expect(check, passed):
                expectations.append((mode, check, passed))
                if results.get(check) is not passed:
                    failures.append('%s %s: expected %s, got %s' %
                                    (mode, check, 'PASS' if passed else 'FAIL',
                                     {True: 'PASS', False: 'FAIL', None: 'no result'}[results.get(check)]))

            for check in ('drawn', 'copy', 'colour', 'single run'):
                expect('flat ' + check, True)
                expect('tab-flat ' + check, True)
            expect('flat background', True)
            expect('flat shape', True)
            expect('double shape', False)
            expect('engraved copy', False)
            expect('engraved colour', False)
            expect('engraved single run', False)
            expect('graphic colour', False)
            expect('tab-engraved copy', False)
            expect('tab-engraved colour', False)
            if mode == 'dark':
                expect('flat contrast', True)
            expect('track-light track', mode == 'light')
            expect('track-dark track', mode == 'dark')
            # A thumb darker than the track does not count in dark mode
            expect('track-light thumb', mode == 'light')
            expect('track-dark thumb', True)
            expect('blank thumb', False)
            # The appearance
            expect('system appearance', True)
            expect('appAppearance default', True)
            expect('effective appAppearance', True)
            expect('st-black-on-white contrast', True)
            expect('st-black-on-white colour', True)
            expect('st-white-on-white drawn', False)
            expect('st-grey-on-white contrast', False)
            expect('st-red colour', True)
            expect('st-black-not-red colour', False)
            expect('st-caption colour', True)
            expect('st-caption-black colour', False)
            expect('st-box-light inside', True)
            expect('st-box-dark inside', False)
            expect('st-face-light face', True)
            expect('st-face-dark face', False)
            expect('st-region-32 colour', True)
            expect('st-region-240 colour', False)

        count, compare_failures = _self_test_compare(folder)
        expectations.extend([('compare', None, None)] * count)
        failures.extend(compare_failures)
    finally:
        if temporary:
            shutil.rmtree(folder, ignore_errors=True)

    print('--- self-test: %d expectations, %d not met' % (len(expectations), len(failures)))
    for f in failures:
        print('  ' + f)
    return 1 if failures else 0


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    parser.add_argument('--mode', choices=('dark', 'light'),
                        help='the appearance the run draws stacks that set none in (the effective appAppearance)')
    parser.add_argument('--system', choices=('dark', 'light'),
                        help='the Windows setting of the run (the systemAppearance); default: --mode')
    parser.add_argument('--label', help='what to call the run in the output; default: --mode')
    parser.add_argument('--dir', help='folder with render.txt and the PNG files')
    parser.add_argument('--compare', nargs=2, metavar=('A', 'B'),
                        help='compare the images of folder A with those of folder B')
    parser.add_argument('--only', action='append', default=[], help='with --compare: images to compare (glob)')
    parser.add_argument('--exclude', action='append', default=[], help='with --compare: images to leave out (glob)')
    parser.add_argument('--rename', help='with --compare: OLD=NEW, a prefix of names in A and its name in B')
    parser.add_argument('--info', action='append', default=[], help='with --compare: an INFO value to compare')
    parser.add_argument('--self-test', action='store_true',
                        help='check the checks on synthetic images, flat and engraved')
    parser.add_argument('--keep', help='with --self-test: write the synthetic images to this folder')
    args = parser.parse_args(argv)
    if args.self_test:
        return self_test(args.keep)
    if args.compare:
        return compare(args.compare[0], args.compare[1], args.only, args.exclude, args.rename, args.info,
                       args.label)
    if not args.mode or not args.dir:
        parser.error('--mode and --dir are required (or --compare, or --self-test)')
    return run(args.mode, args.dir, args.system, args.label)


if __name__ == '__main__':
    sys.exit(main())
