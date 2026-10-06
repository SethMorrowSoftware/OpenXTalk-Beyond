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

"""Make the Project Browser's grey row icons for the dark appearance.

  python tools/oxt/dark_pb_icons.py [--repo DIR] [--check]

The Project Browser (loadImages in ide/Toolset/palettes/project browser/
revprojectbrowserbehavior.livecodescript) shows the icons of
ide/Toolset/resources/supporting_files/images: in each row the object's
type and the toggles of its visible and cantSelect properties. ICONS are
drawn grey on white: on the dark rows (36,36,38 and 44,44,46) the type
icons are dim, and a toggle that is on (dark grey, *_on) is dimmer than one
that is off (light grey, *_off), so every row seemed to have cantSelect set.

In the dark appearance the browser takes an icon from the dark folder of
that folder when it has one. For each icon in ICONS this writes its twin
there, with the same name: each pixel's grey (each channel) is inverted and
scaled so that white becomes BACKGROUND, the dark row colour between the
two, and black stays white (255 - value * (255 - BACKGROUND) / 255), its
alpha kept. The grey ink becomes light grey, the white fill becomes the
row, and a toggle that is off stays fainter than one that is on, about as
faint as on the light rows. The pHYs chunk (density) of a PNG is kept,
other metadata is not; the twin is an 8-bit RGBA PNG.

--check writes nothing. It checks that every icon in ICONS has its twin,
that each twin has exactly the pixels this script makes from the icon (so
the committed files are this script's output), that nothing else is in the
dark folder, and that the mean luminance of each twin's ink (its pixels with
at least half of its highest alpha, composited over the row), as
tools/oxt/dark_disabled_icons.py measures it, has at least MIN_CONTRAST
(3:1) with both dark rows; the toggles that are off (*_off) are faint on
purpose and are not measured. tools/ci/check_ide_icons.py runs this check
in CI.

Standard library only (with tools/oxt/dark_tool_icons.py and
tools/oxt/dark_disabled_icons.py); needs Python 3.8 or later.
"""

import argparse
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from dark_disabled_icons import ink_contrast, read_png, rgb, write_png  # noqa: E402
from dark_tool_icons import read_icon  # noqa: E402

IMAGES = os.path.join('ide', 'Toolset', 'resources', 'supporting_files', 'images')
DARK = 'dark'

# The dark rows of the browser (dataView_rowColor and
# dataView_rowAlternateColor of the dark appearance in
# revcorestackbehavior.livecodescript), and the grey white becomes
BACKGROUNDS = ((36, 36, 38), (44, 44, 46))
BACKGROUND = 40
MIN_CONTRAST = 3.0

# The grey icons of the rows, by file name: the object types (the image of
# card "templates" named <type>.png, or the container rows' "audioclips"
# and "videoclips"), and the visible and cantSelect toggles. The blue icons
# of the script and library rows read on the dark rows as they are.
ICONS = (
    'audioclip.png',
    'audioclips.png',
    'button.png.png',
    'card.png.png',
    'field.png.png',
    'graphic.png',
    'group.png',
    'image.png',
    'player.png',
    'scrollbar.png',
    'stack.png',
    'substack.png',
    'videoclip.png',
    'videoclips.png',
    'widget.png',
    'cantSelect_off.png',
    'cantSelect_on.png',
    'visible_off.png',
    'visible_on.png',
)


def dark_twin_pixels(rgba):
    """RGBA rows with each colour channel inverted and scaled so that white
    becomes BACKGROUND, the alpha kept."""
    out = []
    for line in rgba:
        new = bytearray(line)
        for i in range(0, len(new), 4):
            for k in range(i, i + 3):
                new[k] = 255 - (line[k] * (255 - BACKGROUND) + 127) // 255
        out.append(new)
    return out


def main(argv=None):
    here = os.path.dirname(os.path.abspath(__file__))
    parser = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    parser.add_argument('--repo', default=os.path.normpath(os.path.join(here, '..', '..')),
                        help='repository root (default: two levels up from this script)')
    parser.add_argument('--check', action='store_true', help='check the twins instead of writing them')
    args = parser.parse_args(argv)

    images = os.path.join(args.repo, IMAGES)
    dark = os.path.join(images, DARK)
    base = IMAGES.replace(os.sep, '/')
    problems = []
    if not args.check:
        os.makedirs(dark, exist_ok=True)
    for name in ICONS:
        source = os.path.join(images, name)
        twin = os.path.join(dark, name)
        rel = '%s/%s/%s' % (base, DARK, name)
        if not os.path.isfile(source):
            problems.append(('%s/%s' % (base, name), 'missing: the Project Browser shows it (ICONS in tools/oxt/dark_pb_icons.py)'))
            continue
        width, height, rgba, phys = read_icon(source)
        pixels = dark_twin_pixels(rgba)
        if not args.check:
            write_png(twin, width, height, pixels, phys)
            print('wrote  %s' % rel)
            continue
        if not os.path.isfile(twin):
            problems.append((rel, 'missing: run tools/oxt/dark_pb_icons.py'))
            continue
        twin_width, twin_height, twin_rgba, _ = read_png(twin)
        if (twin_width, twin_height) != (width, height) or [bytes(line) for line in twin_rgba] != [bytes(line) for line in pixels]:
            problems.append((rel, 'not what tools/oxt/dark_pb_icons.py makes from %s: run it again' % name))
            continue
        if name.endswith('_off.png'):
            print('ok     %-45s %2dx%-2d  (a toggle that is off, faint on purpose)' % (DARK + '/' + name, width, height))
            continue
        contrasts = [ink_contrast(twin_rgba, background) for background in BACKGROUNDS]
        low = [(c, b) for c, b in zip(contrasts, BACKGROUNDS) if c < MIN_CONTRAST]
        print('%-6s %-45s %2dx%-2d  ink contrast %s' % (
            'LOW' if low else 'ok', DARK + '/' + name, width, height,
            ', '.join('%.2f:1 on %s' % (c, rgb(b)) for c, b in zip(contrasts, BACKGROUNDS))))
        for contrast, background in low:
            problems.append((rel, 'ink contrast %.2f:1 on %s is below %.1f:1' % (contrast, rgb(background), MIN_CONTRAST)))
    if args.check and os.path.isdir(dark):
        for name in sorted(os.listdir(dark)):
            if name not in ICONS:
                problems.append(('%s/%s/%s' % (base, DARK, name), 'not in ICONS of tools/oxt/dark_pb_icons.py'))

    for rel, message in problems:
        print('FAILED %s: %s' % (rel, message))
        if os.environ.get('GITHUB_ACTIONS') == 'true':
            print('::error file=%s,title=Project Browser icons::%s' % (rel, message))
    if args.check:
        summary = os.environ.get('GITHUB_STEP_SUMMARY')
        if summary:
            with open(summary, 'a', encoding='utf-8') as f:
                f.write('### Project Browser icons\n\n%d dark twin(s): %s\n\n' % (
                    len(ICONS),
                    'each is what tools/oxt/dark_pb_icons.py makes, and each has at least %.1f:1 on the dark rows.'
                    % MIN_CONTRAST if not problems else '%d problem(s).' % len(problems)))
        print('Project Browser icons: %s' % ('passed' if not problems else 'FAILED (%d problem(s))' % len(problems)))
    return 1 if problems else 0


if __name__ == '__main__':
    sys.exit(main())
