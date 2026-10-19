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
"""Draw the OXT-Beyond artwork and write every file made from it: the
0.2.1 "Frankenstein" icon, and the 0.2.7 "Bug Hunt" splash screens,
installer image and banner.

  python3 Installer/oxt-beyond/branding/draw_branding.py

Writes, from the repository root:
  Installer/oxt-beyond/branding/svg/*.svg     the drawings (the source)
  Installer/oxt-beyond/branding/png/oxt-beyond-<n>.png
                                              the icon, 16 to 1024 px; up
                                              to 48 px "OXT" and the
                                              lightning alone, so it reads
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
BOLT = '#FFE14D'          # the icon's lightning
CHARCOAL = '#15171A'
# 0.2.7 "Bug Hunt": the splash screens, the installer art and the banner
BUG_LIGHT = '#4FD8C4'     # the bug's shell, light to shadow
BUG_DARK = '#16756A'
BUG_SPOT = '#0E4A43'
LENS = '#BDF3FF'
GLOW = '#5FE0CF'          # glow and the trail

ICON_SIZES = (16, 24, 32, 48, 64, 128, 256, 512, 1024)
SMALL_ICON_MAX = 48     # sizes up to this use the icon without its lower line

# The splash is 591 x 306 (1x) and 1182 x 612 (@extra-high). The IDE writes
# over it (ide/Toolset/palettes/splash/revsplashstackbehavior.livecodescript,
# at 1x): the version line "<version> · Happy hunting!" under the trail
# (field "moreinfo", baseline about y 160, grey) and the loading status in
# the darker band at the bottom ("Status", 5,270 to 478,293).


def bug(x, y, s, gid):
    """The bug in a 200 x 250 box at x, y, scaled by s: a round, friendly
    beetle with big eyes, glancing up at the magnifying glass."""
    legs = ''
    for ly, dx in ((128, 0), (162, 8), (196, 0)):
        legs += (f'<path d="M100 {ly} L{30 - dx} {ly - 14} L{12 - dx} {ly + 10}" '
                 f'stroke="#111" stroke-width="9" fill="none" stroke-linecap="round" stroke-linejoin="round"/>'
                 f'<path d="M100 {ly} L{170 + dx} {ly - 14} L{188 + dx} {ly + 10}" '
                 f'stroke="#111" stroke-width="9" fill="none" stroke-linecap="round" stroke-linejoin="round"/>')
    return f'''<g transform="translate({x},{y}) scale({s})">
  <defs>
    <linearGradient id="{gid}" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="{BUG_LIGHT}"/><stop offset="1" stop-color="{BUG_DARK}"/></linearGradient>
  </defs>
  {legs}
  <path d="M84 52 Q70 18 46 14" stroke="#111" stroke-width="6" fill="none" stroke-linecap="round"/>
  <path d="M116 52 Q130 18 154 14" stroke="#111" stroke-width="6" fill="none" stroke-linecap="round"/>
  <circle cx="44" cy="14" r="9" fill="{BUG_LIGHT}" stroke="#111" stroke-width="4"/>
  <circle cx="156" cy="14" r="9" fill="{BUG_LIGHT}" stroke="#111" stroke-width="4"/>
  <ellipse cx="100" cy="166" rx="66" ry="78" fill="url(#{gid})" stroke="#111" stroke-width="6"/>
  <path d="M100 96 V242" stroke="#111" stroke-width="5"/>
  <circle cx="68" cy="150" r="11" fill="{BUG_SPOT}"/><circle cx="132" cy="150" r="11" fill="{BUG_SPOT}"/>
  <circle cx="74" cy="196" r="9" fill="{BUG_SPOT}"/><circle cx="126" cy="196" r="9" fill="{BUG_SPOT}"/>
  <path d="M58 118 Q66 104 80 100" stroke="#FFFFFF" stroke-opacity="0.55" stroke-width="6" fill="none" stroke-linecap="round"/>
  <ellipse cx="100" cy="76" rx="46" ry="38" fill="#2A2E33" stroke="#111" stroke-width="6"/>
  <circle cx="80" cy="70" r="16" fill="#F4F1D0" stroke="#111" stroke-width="3"/>
  <circle cx="120" cy="70" r="16" fill="#F4F1D0" stroke="#111" stroke-width="3"/>
  <circle cx="86" cy="63" r="7" fill="#111"/><circle cx="126" cy="63" r="7" fill="#111"/>
  <circle cx="88" cy="60" r="2.5" fill="#FFF"/><circle cx="128" cy="60" r="2.5" fill="#FFF"/>
  <path d="M86 94 Q100 104 114 94" stroke="#F4F1D0" stroke-width="4" fill="none" stroke-linecap="round"/>
</g>'''


def magnifier(x, y, s):
    """A magnifying glass, its lens centred at x, y, scaled by s."""
    return f'''<g transform="translate({x},{y}) scale({s})">
  <path d="M50 50 L118 118" stroke="#111" stroke-width="30" stroke-linecap="round"/>
  <path d="M56 56 L114 114" stroke="{ORANGE}" stroke-width="20" stroke-linecap="round"/>
  <circle cx="0" cy="0" r="72" fill="{LENS}" fill-opacity="0.16" stroke="#111" stroke-width="22"/>
  <circle cx="0" cy="0" r="72" fill="none" stroke="#C9D1D9" stroke-width="12"/>
  <path d="M-46 -20 A50 50 0 0 1 -20 -46" stroke="#FFFFFF" stroke-opacity="0.8" stroke-width="9" fill="none" stroke-linecap="round"/>
</g>'''


def sparks(x, y, s, colour):
    """Little motion marks: the bug was just found."""
    return (f'<g transform="translate({x},{y}) scale({s})" stroke="{colour}" stroke-width="6" stroke-linecap="round">'
            '<path d="M0 0 L-18 -14"/><path d="M4 22 L-20 24"/><path d="M0 44 L-18 58"/></g>')


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
<rect x="64" y="64" width="896" height="896" rx="200" fill="url(#tile)"/>
<rect x="64" y="64" width="896" height="896" rx="200" fill="none" stroke="{ORANGE}" stroke-width="18"/>'''


def icon():
    # "OXT" struck by lightning, a stitched seam and "BEYOND"
    return svg(1024, 1024, TILE + bolt(600, 150, 4.2)
               + word(512, 640, 330, 'OXT', ORANGE, '#000', 22, 'middle', sx=0.9)
               + stitches(220, 804, 740, '#8A9099')
               + word(512, 860, 120, 'BEYOND', '#E9ECEF', anchor='middle', sx=0.9))


def icon_small():
    # "OXT" and the lightning alone, larger: the seam and "BEYOND" would be
    # a pixel or two at 16 to 48 px
    return svg(1024, 1024, TILE + bolt(590, 120, 5.0)
               + word(512, 690, 400, 'OXT', ORANGE, '#000', 26, 'middle', sx=0.86))


def trail(x1, x2, y, colour):
    """A dotted trail of little bug footprints, where 0.2.1 had stitches."""
    t = ''
    for i, px in enumerate(range(x1 + 6, x2, 22)):
        dy = -5 if i % 2 else 5
        t += f'<circle cx="{px}" cy="{y + dy}" r="4" fill="{colour}"/>'
    return t


def splash(dark):
    if dark:
        bg1, bg2, fg, glow, shade = '#1E2126', CHARCOAL, '#F1F3F5', GLOW, 0.25
    else:
        bg1, bg2, fg, glow, shade = '#F7F8F5', '#DCE6E4', CHARCOAL, '#2FA897', 0.06
    return svg(1182, 612, f'''<defs><linearGradient id="sb" x1="0" y1="0" x2="1" y2="0">
<stop offset="0" stop-color="{bg2}"/><stop offset="1" stop-color="{bg1}"/></linearGradient>
<radialGradient id="gl" cx="0.5" cy="0.5" r="0.5"><stop offset="0" stop-color="{glow}" stop-opacity="0.45"/>
<stop offset="1" stop-color="{glow}" stop-opacity="0"/></radialGradient></defs>
<rect width="1182" height="612" fill="url(#sb)"/>
<circle cx="900" cy="300" r="330" fill="url(#gl)"/>
{bug(740, 150, 1.4, 'shell')}
{sparks(735, 250, 1.3, glow)}
{magnifier(900, 230, 1.55)}
{word(60, 150, 112, 'OXT-Beyond', ORANGE, '#000', 10, sx=0.8)}
{word(64, 240, 82, 'BUG HUNT', fg, sx=0.78)}
{trail(64, 660, 268, glow)}
<rect x="0" y="520" width="1182" height="92" fill="#000" fill-opacity="{shade}"/>''')


def wizard():
    # Inno Setup's tall image at 250 % (534 x 1022); 202 x 386 at 100 %
    return svg(534, 1022, f'''<rect width="534" height="1022" fill="{CHARCOAL}"/>
<circle cx="267" cy="410" r="270" fill="{GLOW}" fill-opacity="0.16"/>
{bug(97, 250, 1.7, 'shell')}
{sparks(100, 380, 1.4, GLOW)}
{magnifier(268, 372, 1.5)}
{word(267, 800, 82, 'OXT-Beyond', ORANGE, '#000', 10, 'middle', sx=0.8)}
{word(267, 885, 64, 'BUG HUNT', '#F1F3F5', anchor='middle', sx=0.78)}
{trail(75, 460, 920, GLOW)}''')


def banner():
    return svg(1280, 640, f'''<defs><radialGradient id="g5" cx="0.72" cy="0.5" r="0.5">
<stop offset="0" stop-color="{GLOW}" stop-opacity="0.4"/><stop offset="1" stop-color="{GLOW}" stop-opacity="0"/></radialGradient></defs>
<rect width="1280" height="640" fill="{CHARCOAL}"/><rect width="1280" height="640" fill="url(#g5)"/>
{bug(820, 170, 1.5, 'shell')}
{sparks(815, 280, 1.4, GLOW)}
{magnifier(990, 260, 1.65)}
{word(70, 200, 120, 'OXT-Beyond', ORANGE, '#000', 10, sx=0.8)}
{word(74, 320, 108, 'BUG HUNT', '#F1F3F5', sx=0.78)}
{trail(74, 720, 352, GLOW)}
{word(74, 430, 44, 'Version 0.2.7  ·  Happy hunting!', '#9AA3AD', bold=False, sx=1)}
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
