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
"""Draw the OXT-Beyond 0.2.1 "Frankenstein" artwork and write every file
made from it.

  python3 Installer/oxt-beyond/branding/draw_branding.py

Writes, from the repository root:
  Installer/oxt-beyond/branding/svg/*.svg     the drawings (the source)
  Installer/oxt-beyond/branding/png/oxt-beyond-<n>.png
                                              the icon, 16 to 1024 px; at
                                              16 and 24 px the head alone,
                                              so it reads at that size
  Installer/oxt-beyond/branding/art/oxt-beyond-wizard.png
                                              the tall installer image
                                              (534 x 1022), which
                                              make-wizard-images.ps1 scales
  Installer/oxt-beyond/branding/art/oxt-beyond-banner.png
                                              the release banner (1280 x 640)
  ide/Toolset/resources/community/ideSkin/splash.png, splash-light.png
                                              and their @extra-high versions
  ide/OXT-Beyond.ico, engine/rsrc/oxt-beyond.ico
                                              by tools/oxt/ico.py

The macOS .icns and the Linux icons are made from the PNG files when a
package is staged (tools/oxt/package.py). The About window and dialog icon
(revgeneralicons.rev) take oxt-beyond-32.png and oxt-beyond-64.png through
tools/oxt/ide-stack-patches/branding-dialog-icons.txt.

Needs CairoSVG (python3 -m pip install cairosvg) and the DejaVu Sans font;
only this drawing step needs them. The drawings are plain SVG, so they can
also be edited in any vector editor and rendered again with this script's
render step (--render-only).
"""

import argparse
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.normpath(os.path.join(HERE, '..', '..', '..'))

ORANGE = '#FF7700'      # the "OXT" orange of the earlier icon
GREEN_LIGHT = '#9BD36A'
GREEN_DARK = '#4E7F2E'
GLOW = '#B9F56A'
BOLT = '#FFE14D'
CHARCOAL = '#15171A'

ICON_SIZES = (16, 24, 32, 48, 64, 128, 256, 512, 1024)
SMALL_ICON_MAX = 24     # sizes up to this use the head-only icon

# The splash is 591 x 306 (1x) and 1182 x 612 (@extra-high). The IDE writes
# over it (ide/Toolset/palettes/splash/revsplashstackbehavior.livecodescript,
# at 1x): the version line "<version> · It's alive!" under the stitches
# (field "moreinfo", baseline about y 160, grey) and the loading status in
# the darker band at the bottom ("Status", 5,270 to 478,293).


def head(x, y, s, gid):
    """The monster's head in a 200 x 250 box at x, y, scaled by s."""
    return f'''<g transform="translate({x},{y}) scale({s})">
  <defs>
    <linearGradient id="{gid}" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="{GREEN_LIGHT}"/><stop offset="1" stop-color="{GREEN_DARK}"/></linearGradient>
  </defs>
  <rect x="62" y="200" width="76" height="50" fill="{GREEN_DARK}"/>
  <rect x="34" y="208" width="30" height="20" rx="4" fill="#9AA3AD" stroke="#2A2E33" stroke-width="4"/>
  <rect x="136" y="208" width="30" height="20" rx="4" fill="#9AA3AD" stroke="#2A2E33" stroke-width="4"/>
  <rect x="24" y="212" width="12" height="12" rx="2" fill="#C9D1D9" stroke="#2A2E33" stroke-width="3"/>
  <rect x="164" y="212" width="12" height="12" rx="2" fill="#C9D1D9" stroke="#2A2E33" stroke-width="3"/>
  <path d="M30 40 H170 V170 Q170 214 130 218 H70 Q30 214 30 170 Z" fill="url(#{gid})" stroke="#1B2A12" stroke-width="6"/>
  <path d="M24 18 H176 V62 L164 52 L150 66 L134 52 L118 68 L100 52 L82 68 L66 52 L50 66 L36 52 L24 62 Z" fill="#111" stroke="#111" stroke-width="4" stroke-linejoin="round"/>
  <path d="M56 84 L146 78" stroke="#1B2A12" stroke-width="4" fill="none"/>
  <g stroke="#1B2A12" stroke-width="3">
    <path d="M66 76 L68 92"/><path d="M82 75 L84 91"/><path d="M98 74 L100 90"/><path d="M114 73 L116 89"/><path d="M130 72 L132 88"/></g>
  <rect x="44" y="102" width="46" height="12" fill="#111"/><rect x="110" y="102" width="46" height="12" fill="#111"/>
  <path d="M50 122 H86 Q80 136 68 136 Q56 136 50 122 Z" fill="#F4F1D0" stroke="#111" stroke-width="3"/>
  <path d="M114 122 H150 Q144 136 132 136 Q120 136 114 122 Z" fill="#F4F1D0" stroke="#111" stroke-width="3"/>
  <circle cx="68" cy="127" r="5" fill="#111"/><circle cx="132" cy="127" r="5" fill="#111"/>
  <path d="M100 136 L92 166 H108" stroke="#1B2A12" stroke-width="4" fill="none" stroke-linejoin="round"/>
  <path d="M70 188 H130" stroke="#111" stroke-width="6" stroke-linecap="round"/>
  <g stroke="#111" stroke-width="3"><path d="M82 182 V194"/><path d="M100 182 V194"/><path d="M118 182 V194"/></g>
  <path d="M150 150 L160 182" stroke="#1B2A12" stroke-width="3"/>
  <g stroke="#1B2A12" stroke-width="3"><path d="M148 160 L160 156"/><path d="M151 170 L163 166"/></g>
</g>'''


def bolt(x, y, s):
    return (f'<g transform="translate({x},{y}) scale({s})"><path d="M30 0 L0 56 H22 L8 100 L52 36 H28 L44 0 Z" '
            f'fill="{BOLT}" stroke="#7A5A00" stroke-width="3" stroke-linejoin="round"/></g>')


def word(x, y, size, text, fill, outline=None, width=0, anchor='start', bold=True, sx=0.82):
    """Text in DejaVu Sans; an outline is drawn as a wider copy behind it."""
    t = (f'<text transform="translate({x},{y}) scale({sx},1)" font-family="DejaVu Sans" '
         f'font-weight="{"bold" if bold else "normal"}" font-size="{size}" text-anchor="{anchor}" ')
    under = (t + f'fill="{outline}" stroke="{outline}" stroke-width="{width}" stroke-linejoin="round">{text}</text>'
             if width else '')
    return under + t + f'fill="{fill}">{text}</text>'


def stitches(x1, x2, y, colour):
    s = f'<path d="M{x1} {y} H{x2}" stroke="{colour}" stroke-width="3"/>'
    for i in range(x1 + 8, x2, 18):
        s += f'<path d="M{i} {y - 7} L{i + 4} {y + 7}" stroke="{colour}" stroke-width="3"/>'
    return s


def svg(w, h, body):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}">'
            f'{body}</svg>\n')


TILE = f'''<defs><linearGradient id="tile" x1="0" y1="0" x2="0" y2="1">
<stop offset="0" stop-color="#2B2F36"/><stop offset="1" stop-color="{CHARCOAL}"/></linearGradient></defs>
<rect x="64" y="64" width="896" height="896" rx="200" fill="url(#tile)"/>'''


def icon():
    return svg(1024, 1024, TILE + bolt(120, 110, 3.0) + bolt(780, 140, 2.4) + head(262, 96, 2.5, 'skin')
               + word(512, 920, 140, 'OXT', ORANGE, '#000', 16, 'middle', sx=0.9))


def icon_small():
    # The head alone, filling the tile: the lightning and the lettering
    # would be a pixel or two at 16 and 24 px
    return svg(1024, 1024, TILE + head(122, 70, 3.9, 'skin'))


def splash(dark):
    if dark:
        bg1, bg2, fg, glow, shade = '#1E2126', CHARCOAL, '#F1F3F5', GLOW, 0.25
    else:
        bg1, bg2, fg, glow, shade = '#F7F8F5', '#DDE2D8', CHARCOAL, '#7DBA4A', 0.06
    return svg(1182, 612, f'''<defs><linearGradient id="sb" x1="0" y1="0" x2="1" y2="0">
<stop offset="0" stop-color="{bg2}"/><stop offset="1" stop-color="{bg1}"/></linearGradient>
<radialGradient id="gl" cx="0.5" cy="0.5" r="0.5"><stop offset="0" stop-color="{glow}" stop-opacity="0.55"/>
<stop offset="1" stop-color="{glow}" stop-opacity="0"/></radialGradient></defs>
<rect width="1182" height="612" fill="url(#sb)"/>
<circle cx="900" cy="300" r="330" fill="url(#gl)"/>
{bolt(1010, 40, 2.2)}{bolt(700, 70, 1.5)}
{head(730, 70, 1.75, 'skin')}
{word(60, 150, 112, 'OXT-Beyond', ORANGE, '#000', 10, sx=0.8)}
{word(64, 240, 82, 'FRANKENSTEIN', fg, sx=0.78)}
{stitches(64, 660, 268, glow)}
<rect x="0" y="520" width="1182" height="92" fill="#000" fill-opacity="{shade}"/>''')


def wizard():
    # Inno Setup's tall image at 250 % (534 x 1022); 202 x 386 at 100 %
    return svg(534, 1022, f'''<rect width="534" height="1022" fill="{CHARCOAL}"/>
<circle cx="267" cy="410" r="270" fill="{GLOW}" fill-opacity="0.18"/>
{bolt(50, 80, 2.0)}{bolt(400, 110, 1.6)}
{head(81, 210, 1.86, 'skin')}
{word(267, 800, 82, 'OXT-Beyond', ORANGE, '#000', 10, 'middle', sx=0.8)}
{word(267, 885, 56, 'FRANKENSTEIN', '#F1F3F5', anchor='middle', sx=0.78)}
{stitches(75, 460, 920, GLOW)}''')


def banner():
    return svg(1280, 640, f'''<defs><radialGradient id="g5" cx="0.72" cy="0.5" r="0.5">
<stop offset="0" stop-color="{GLOW}" stop-opacity="0.5"/><stop offset="1" stop-color="{GLOW}" stop-opacity="0"/></radialGradient></defs>
<rect width="1280" height="640" fill="{CHARCOAL}"/><rect width="1280" height="640" fill="url(#g5)"/>
{bolt(1120, 40, 2.4)}{bolt(760, 60, 1.6)}
{head(800, 90, 1.8, 'skin')}
{word(70, 200, 120, 'OXT-Beyond', ORANGE, '#000', 10, sx=0.8)}
{word(74, 320, 108, 'FRANKENSTEIN', '#F1F3F5', sx=0.78)}
{stitches(74, 720, 352, GLOW)}
{word(74, 430, 44, 'Version 0.2.1  ·  It’s alive!', '#9AA3AD', bold=False, sx=1)}
{word(74, 560, 30, 'Windows · macOS · Linux  —  free and open source xTalk', '#6C757D', bold=False, sx=1)}''')


DRAWINGS = {
    'icon.svg': icon,
    'icon-small.svg': icon_small,
    'splash-dark.svg': lambda: splash(True),
    'splash-light.svg': lambda: splash(False),
    'wizard.svg': wizard,
    'banner.svg': banner,
}


def render(name, out, width, height):
    import cairosvg
    path = os.path.join(HERE, 'svg', name)
    os.makedirs(os.path.dirname(out), exist_ok=True)
    cairosvg.svg2png(url=path, write_to=out, output_width=width, output_height=height)
    print('wrote %s (%d x %d)' % (os.path.relpath(out, REPO), width, height))


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('--render-only', action='store_true',
                    help='keep the SVG files as they are (edited by hand) and only render them')
    args = ap.parse_args()

    if not args.render_only:
        for name, draw in DRAWINGS.items():
            with open(os.path.join(HERE, 'svg', name), 'w', encoding='utf-8', newline='\n') as f:
                f.write(draw())
            print('wrote %s' % os.path.relpath(os.path.join(HERE, 'svg', name), REPO))

    png = os.path.join(HERE, 'png')
    for n in ICON_SIZES:
        render('icon-small.svg' if n <= SMALL_ICON_MAX else 'icon.svg',
               os.path.join(png, 'oxt-beyond-%d.png' % n), n, n)
    render('wizard.svg', os.path.join(HERE, 'art', 'oxt-beyond-wizard.png'), 534, 1022)
    render('banner.svg', os.path.join(HERE, 'art', 'oxt-beyond-banner.png'), 1280, 640)

    skin = os.path.join(REPO, 'ide', 'Toolset', 'resources', 'community', 'ideSkin')
    for name, base in (('splash-dark.svg', 'splash'), ('splash-light.svg', 'splash-light')):
        render(name, os.path.join(skin, base + '.png'), 591, 306)
        render(name, os.path.join(skin, base + '@extra-high.png'), 1182, 612)

    sys.path.insert(0, os.path.join(REPO, 'tools', 'oxt'))
    import ico
    sizes = (16, 24, 32, 48, 64, 128, 256)
    files = [os.path.join(png, 'oxt-beyond-%d.png' % n) for n in sizes]
    for out in (os.path.join(REPO, 'ide', 'OXT-Beyond.ico'), os.path.join(REPO, 'engine', 'rsrc', 'oxt-beyond.ico')):
        ico.write(out, files)
        print('wrote %s' % os.path.relpath(out, REPO))
    return 0


if __name__ == '__main__':
    sys.exit(main())
