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
icon (from 0.2.7 SVG Lab's SVG logo, tools/pages/games/svg-lab/beyond-logo.svg,
still and moving), the splash screens (from rc.6.14 like the web IDE's
loading screen), and the 0.2.7 "Make It So" installer
image and banner, each with the logo (the release candidates had the
"Bug Hunt" beetle there).

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
  tools/pages/brand/                          the web pages' logo, favicon
                                              and link preview
  tools/web-player/assets/oxt-beyond-128.png  the Stack Player's icon
  tools/web-ide/index.html                    its favicon (in the page)

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
CHARCOAL = '#15171A'
# 0.2.7 "Make It So": the splash's name, the installer art and the banner.
# A star-streak "jump" on a night-blue sky, as in the 0.2.7 promo stills:
# you say what you want in xTalk, and it happens. (The release candidates'
# "Bug Hunt" beetle, magnifying glass and footprints are in the history of
# this file.)
SKY_TOP = '#22314F'       # the sky, lighter at the vanishing point
SKY = '#0D1322'
STREAK = '#CFE0FF'        # the star streaks and the stars
GOLD = '#FFB547'          # the release's name, on the dark
GOLD_DEEP = '#A0560A'     # the release's name, on the light splash

ICON_SIZES = (16, 24, 32, 48, 64, 128, 256, 512, 1024)
SMALL_ICON_MAX = 48     # sizes up to this use the icon without its lower line

# The splash is 591 x 306 (1x) and 1182 x 612 (@extra-high); see splash()
# for where the IDE writes over it.


def lcg(seed):
    """Numbers in [0, 1) from a fixed little generator, so the drawings
    come out the same on every machine and every Python."""
    state = seed
    while True:
        state = (state * 1103515245 + 12345) % 2147483648
        yield state / 2147483648


def streaks(cx, cy, count, inner, reach, seed, width=1.0, opacity=1.0):
    """Star streaks rushing out of a vanishing point at cx, cy: thin wedges,
    a point at the inner end and wider at the outer, the "jump"."""
    import math
    r = lcg(seed)
    out = []
    for i in range(count):
        a = 2 * math.pi * (i + next(r)) / count
        r1 = inner * (0.6 + 0.9 * next(r))
        r2 = r1 + reach * (0.25 + 0.75 * next(r))
        w = width * (1.2 + 3.2 * next(r))
        op = opacity * (0.12 + 0.5 * next(r))
        ca, sa = math.cos(a), math.sin(a)
        x1, y1 = cx + ca * r1, cy + sa * r1
        x2, y2 = cx + ca * r2, cy + sa * r2
        px, py = -sa * w / 2, ca * w / 2
        out.append(f'<path d="M{x1:.1f} {y1:.1f} L{x2 + px:.1f} {y2 + py:.1f} L{x2 - px:.1f} {y2 - py:.1f} Z" '
                   f'fill="{STREAK}" fill-opacity="{op:.2f}"/>')
    return ''.join(out)


def stars(x1, y1, x2, y2, count, seed):
    """Still stars, small and faint, scattered over a box."""
    r = lcg(seed)
    out = []
    for _ in range(count):
        x = x1 + (x2 - x1) * next(r)
        y = y1 + (y2 - y1) * next(r)
        out.append(f'<circle cx="{x:.1f}" cy="{y:.1f}" r="{0.8 + 1.6 * next(r):.1f}" '
                   f'fill="{STREAK}" fill-opacity="{0.25 + 0.6 * next(r):.2f}"/>')
    return ''.join(out)


def sparkle(x, y, s, colour):
    """A four-pointed sparkle centred at x, y, s from the centre to a tip
    (drawn, so it needs no font with a sparkle in it)."""
    k = s * 0.22
    return (f'<path d="M{x:g} {y - s:g} Q{x + k:g} {y - k:g} {x + s:g} {y:g} Q{x + k:g} {y + k:g} {x:g} {y + s:g} '
            f'Q{x - k:g} {y + k:g} {x - s:g} {y:g} Q{x - k:g} {y - k:g} {x:g} {y - s:g} Z" fill="{colour}"/>')


def sky(w, h, cx, cy, gid):
    """The night-blue sky, lighter round the vanishing point at cx, cy."""
    return (f'<defs><radialGradient id="{gid}" gradientUnits="userSpaceOnUse" cx="{cx}" cy="{cy}" r="{max(w, h)}">'
            f'<stop offset="0" stop-color="{SKY_TOP}"/><stop offset="0.6" stop-color="{SKY}"/></radialGradient>'
            f'<radialGradient id="{gid}-core" cx="0.5" cy="0.5" r="0.5">'
            f'<stop offset="0" stop-color="{STREAK}" stop-opacity="0.35"/>'
            f'<stop offset="1" stop-color="{STREAK}" stop-opacity="0"/></radialGradient></defs>'
            f'<rect width="{w}" height="{h}" fill="url(#{gid})"/>')


def word(x, y, size, text, fill, outline=None, width=0, anchor='start', bold=True, sx=0.82):
    """Text in DejaVu Sans; an outline is drawn as a wider copy behind it."""
    t = (f'<text transform="translate({x},{y}) scale({sx},1)" font-family="DejaVu Sans" '
         f'font-weight="{"bold" if bold else "normal"}" font-size="{size}" text-anchor="{anchor}" ')
    under = (t + f'fill="{outline}" stroke="{outline}" stroke-width="{width}" stroke-linejoin="round">{text}</text>'
             if width else '')
    return under + t + f'fill="{fill}">{text}</text>'


def svg(w, h, body):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}">'
            f'{body}</svg>\n')


# The logo: "OXT" struck by lightning, a stitched seam and "BEYOND", rebuilt in
# 0.2.7 as SVG with its words as paths (no font needed), gradients, a glow
# clipped to the tile, light rays, electric arcs and sparks. Its one source
# is SVG Lab's still (tools/pages/games/svg-lab/beyond-logo.svg, written by
# genlogo.py there); every file below is made from it, so the icons, the
# splash screens, the installer, the banner and the web pages show the same
# drawing as SVG Lab.
LOGO = os.path.join(REPO, 'tools', 'pages', 'games', 'svg-lab', 'beyond-logo.svg')


def logo():
    with open(LOGO, encoding='utf-8') as f:
        text = f.read()
    for part in ('class="tick"', 'class="beyond"', 'class="arc"', 'url(#glow-1)', 'url(#halo-1)',
                 'transform="rotate(0 740 300)"', 'transform="translate(620 0)"', 'fill="#FFF4B0"'):
        if part not in text:
            raise SystemExit('%s has no %s: genlogo.py has changed, so change draw_branding.py too'
                             % (os.path.relpath(LOGO, REPO), part))
    return text


def logo_lines():
    """The logo's lines: its <svg> line, its style sheet and defs, its body
    and its closing tag. genlogo.py writes one element (or group) a line."""
    lines = logo().rstrip('\n').split('\n')
    if not lines[0].startswith('<svg ') or lines[-1] != '</svg>':
        raise SystemExit('%s is not one <svg> element a line' % os.path.relpath(LOGO, REPO))
    return lines


def icon():
    # The logo as it is
    return logo()


def icon_small():
    # "OXT" and the lightning alone, larger: the seam, "BEYOND", the arcs and
    # the sparks would be a pixel or two at 16 to 48 px. The tile and its rim
    # keep their size; everything on them is scaled about the middle.
    lines = logo_lines()
    keep, body = [], []
    tile_done = False
    for line in lines[1:-1]:
        if 'class="tick"' in line or 'class="beyond"' in line or 'class="arc"' in line:
            continue
        if 'fill="#FFF4B0"' in line and line.startswith('<circle cx="850"'):
            continue    # the sparks
        if tile_done:
            body.append(line)
        else:
            keep.append(line)
            tile_done = line.startswith('<rect class="rim"')
    return '\n'.join([lines[0]] + keep
                     + ['<g transform="translate(512 520) scale(1.2) translate(-518 -397)">']
                     + body + ['</g>', '</svg>']) + '\n'


def icon_animated():
    """The logo, moving, as SMIL in the file itself, so it plays wherever an
    SVG image does (an <img> on a web page, GitHub's README): the rays turn,
    the glow and the halo breathe, the arcs crackle, the sparks twinkle and
    a shine sweeps across "OXT" every few seconds. SVG Lab's stack draws the
    same effects frame by frame (beyond-logo-live.svg)."""
    text = logo()

    def once(old, new):
        nonlocal text
        if text.count(old) != 1:
            raise SystemExit('%s: expected one %r' % (os.path.relpath(LOGO, REPO), old))
        text = text.replace(old, new)

    once('transform="rotate(0 740 300)">',
         'transform="rotate(0 740 300)"><animateTransform attributeName="transform" type="rotate" '
         'from="0 740 300" to="360 740 300" dur="120s" repeatCount="indefinite"/>')
    once('fill="url(#glow-1)" opacity="0.34"/>',
         'fill="url(#glow-1)" opacity="0.34"><animate attributeName="opacity" '
         'values="0.26;0.44;0.26" dur="4s" repeatCount="indefinite"/></rect>')
    once('fill="url(#halo-1)" opacity="0.6"/>',
         'fill="url(#halo-1)" opacity="0.6"><animate attributeName="opacity" '
         'values="0.45;0.8;0.5;0.75;0.45" dur="2.6s" repeatCount="indefinite"/></circle>')
    # The shine waits off the letters, sweeps across them, and waits again
    shine = ('transform="translate(620 0)" points="-40,380 130,380 40,680 -130,680" fill="url(#shine-1)" '
             'opacity="0.8"/>')
    once('<polygon ' + shine,
         '<polygon ' + shine.replace('translate(620 0)', 'translate(-200 0)')[:-2]
         + '><animateTransform attributeName="transform" type="translate" values="-200 0;1100 0;1100 0" '
         'keyTimes="0;0.3;1" dur="5s" repeatCount="indefinite"/></polygon>')
    # The arcs: each jumps between three zigzags and flickers
    arcs = (('705,250 650,215 662,180 610,150 622,118',
             '705,250 660,222 648,184 618,160 610,122',
             '705,250 644,226 670,190 600,168 630,124', '1.3s'),
            ('790,300 836,272 828,236 878,214 884,180',
             '790,300 826,262 846,240 868,206 892,186',
             '790,300 846,282 820,244 886,226 876,176', '1.7s'))
    for first, second, third, dur in arcs:
        once('opacity="0.8" points="%s"/>' % first,
             'opacity="0.8" points="%s"><animate attributeName="points" values="%s;%s;%s" dur="%s" '
             'calcMode="discrete" repeatCount="indefinite"/><animate attributeName="opacity" '
             'values="0.9;0.2;1;0;0.7;0.9" dur="%s" calcMode="discrete" repeatCount="indefinite"/></polyline>'
             % (first, first, second, third, dur, dur))
    # The sparks twinkle, each in its own time
    import re
    sparks = re.findall(r'<circle cx="\d+" cy="\d+" r="\d+" fill="#FFF4B0" opacity="[\d.]+"/>', text)
    if len(sparks) < 5:
        raise SystemExit('%s: expected the sparks' % os.path.relpath(LOGO, REPO))
    for i, spark in enumerate(sparks):
        dur = 1.4 + (i * 0.37) % 1.1
        once(spark, spark[:-2] + '><animate attributeName="opacity" values="0;1;0.2;0" dur="%.2fs" '
             'begin="%.2fs" repeatCount="indefinite"/></circle>' % (dur, -i * 0.43))
    return text


def nested_logo(x, y, size):
    """The logo, size x size, at x, y, as an <svg> inside another drawing."""
    lines = logo_lines()
    return ('<svg x="%g" y="%g" width="%g" height="%g" viewBox="0 0 1024 1024">\n' % (x, y, size, size)
            + '\n'.join(lines[1:]) + '\n')


def codename():
    """The release's name (ide/.codename), which the splash shows."""
    with open(os.path.join(REPO, 'ide', '.codename'), encoding='utf-8') as f:
        return f.read().strip()


# The splash, from 0.2.7-rc.6.14, looks like the web IDE's loading screen
# (tools/web-ide/index.html, #loading): one centred card on the web IDE's
# slate desktop (a light one for the light appearance), the logo above
# "OXT-Beyond" with "OXT" in orange, the release's name in a small pill,
# and a thin track for the loading bar. Everything below the pill is the
# IDE's, written over the art at 1x (revsplashstackbehavior.livecodescript):
# the version line (field "moreinfo"), the bar's orange fill (graphic
# "progress", over the track drawn here) and the loading status (field
# "Status"). SPLASH_* are those places at 1x, which the tests hold the
# script and the art to.
SPLASH_LOGO = (243, 24, 105)          # x, y and size of the logo
SPLASH_ART_BOTTOM = 196               # the drawing's words end above this
SPLASH_MOREINFO = (0, 199, 591, 225)  # field "moreinfo"
SPLASH_TRACK = (196, 242, 395, 245)   # the loading bar's track
SPLASH_STATUS = (0, 252, 591, 276)    # field "Status"
# "OXT-Beyond" is two words of DejaVu Sans Bold at 66 px (at 2x), "OXT"
# 149.7 px wide and "-Beyond" 305.1: the line is centred when they meet at
# 591 + (149.7 - 305.1) / 2. CairoSVG does not centre a line of <tspan>s.
WORDMARK_JOIN = 513


def splash(dark):
    if dark:
        top, bottom, fg, track, pill, shade = '#3B4B5E', '#1D2733', '#F4F6F8', '#FFFFFF', GOLD, 0.45
        track_opacity = 0.12
    else:
        top, bottom, fg, track, pill, shade = '#FFFFFF', '#DCE3EA', '#17202A', '#17202A', GOLD_DEEP, 0.22
        track_opacity = 0.10
    lx, ly, ls = (2 * n for n in SPLASH_LOGO)
    cx = 591
    tx1, ty1, tx2, ty2 = (2 * n for n in SPLASH_TRACK)
    name = codename().upper()
    # The pill fits its words: DejaVu Sans Bold at 19 px with 0.18 em
    # between letters is about 16 px a letter
    pw = 16 * len(name) + 44
    return svg(1182, 612, f'''<defs><radialGradient id="desk" gradientUnits="userSpaceOnUse" cx="591" cy="0" r="1000">
<stop offset="0" stop-color="{top}"/><stop offset="0.75" stop-color="{bottom}"/></radialGradient>
<radialGradient id="warm" cx="0.5" cy="0.5" r="0.5"><stop offset="0" stop-color="{ORANGE}" stop-opacity="{0.22 if dark else 0.14}"/>
<stop offset="1" stop-color="{ORANGE}" stop-opacity="0"/></radialGradient>
<radialGradient id="drop" cx="0.5" cy="0.5" r="0.5"><stop offset="0" stop-color="#000" stop-opacity="{shade}"/>
<stop offset="1" stop-color="#000" stop-opacity="0"/></radialGradient></defs>
<rect width="1182" height="612" fill="url(#desk)"/>
<circle cx="{cx}" cy="{ly + ls // 2}" r="{ls}" fill="url(#warm)"/>
<ellipse cx="{cx}" cy="{ly + ls - 6}" rx="{ls * 0.42:g}" ry="22" fill="url(#drop)"/>
{nested_logo(lx, ly, ls)}<text x="{WORDMARK_JOIN}" y="336" text-anchor="end" font-family="DejaVu Sans" font-weight="bold" font-size="66" fill="{ORANGE}">OXT</text>
<text x="{WORDMARK_JOIN}" y="336" font-family="DejaVu Sans" font-weight="bold" font-size="66" fill="{fg}">-Beyond</text>
<rect x="{cx - pw / 2:g}" y="356" width="{pw}" height="30" rx="15" fill="{pill}" fill-opacity="0.14" stroke="{pill}" stroke-opacity="0.55" stroke-width="2"/>
<text x="{cx + 2}" y="378" text-anchor="middle" font-family="DejaVu Sans" font-weight="bold" font-size="19" letter-spacing="3.4" fill="{pill}">{name}</text>
<rect x="{tx1}" y="{ty1}" width="{tx2 - tx1}" height="{ty2 - ty1}" rx="{(ty2 - ty1) / 2:g}" fill="{track}" fill-opacity="{track_opacity}"/>''')


def wizard():
    # Inno Setup's tall image at 250 % (534 x 1022); 202 x 386 at 100 %.
    # The logo at the vanishing point of the streaks, the words below.
    cx, cy = 267, 400
    return svg(534, 1022, f'''{sky(534, 1022, cx, cy, 'wsky')}
{stars(0, 0, 534, 1022, 70, 7)}
{streaks(cx, cy, 64, 150, 520, 11, width=1.2)}
<circle cx="{cx}" cy="{cy}" r="250" fill="url(#wsky-core)"/>
{nested_logo(cx - 175, cy - 175, 350)}
{word(267, 720, 82, 'OXT-Beyond', ORANGE, '#000', 10, 'middle', sx=0.8)}
{sparkle(62, 790, 18, GOLD)}{sparkle(472, 790, 18, GOLD)}
{word(267, 812, 64, 'MAKE IT SO', GOLD, anchor='middle', sx=0.78)}
{word(267, 900, 40, 'Version 0.2.7', '#AEB8C4', anchor='middle', bold=False, sx=0.9)}''')


def banner():
    # The streaks rush out from behind the logo, at the left; the words
    # sit on the calmer sky at the right of it.
    cx, cy = 210, 320
    return svg(1280, 640, f'''{sky(1280, 640, cx, cy, 'bsky')}
{stars(0, 0, 1280, 640, 110, 5)}
{streaks(cx, cy, 90, 170, 1150, 3, width=1.4, opacity=0.8)}
<circle cx="{cx}" cy="{cy}" r="300" fill="url(#bsky-core)"/>
{nested_logo(cx - 170, cy - 170, 340)}
{word(440, 250, 100, 'OXT-Beyond', ORANGE, '#000', 10, sx=0.8)}
{sparkle(466, 318, 22, GOLD)}
{word(506, 340, 66, 'MAKE IT SO', GOLD, sx=0.78)}
{word(444, 430, 38, 'Version 0.2.7  ·  Thank you, bug hunters!', '#C3CCD6', bold=False, sx=1)}
{word(444, 520, 24, 'Windows · macOS · Linux · the web  ·  free, open source xTalk', '#8A95A3', bold=False, sx=1)}''')


DRAWINGS = {
    'icon.svg': icon,
    'icon-small.svg': icon_small,
    'splash-dark.svg': lambda: splash(True),
    'splash-light.svg': lambda: splash(False),
    'wizard.svg': wizard,
    'banner.svg': banner,
    'icon-animated.svg': icon_animated,
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

    # The web pages: the front page's logo, still and moving, its favicon
    # and its link preview (tools/pages/build_pages.py copies tools/pages/brand
    # beside the page), and the Stack Player's icon
    import shutil
    site = os.path.join(REPO, 'tools', 'pages', 'brand')
    os.makedirs(site, exist_ok=True)
    for name, out in (('icon-small.svg', 'icon.svg'), ('icon.svg', 'logo.svg'),
                      ('icon-animated.svg', 'logo-animated.svg')):
        shutil.copyfile(os.path.join(HERE, 'svg', name), os.path.join(site, out))
        print('wrote %s' % os.path.relpath(os.path.join(site, out), REPO))
    for src, out in ((os.path.join(HERE, 'art', 'oxt-beyond-banner.png'), os.path.join(site, 'social.png')),
                     (os.path.join(png, 'oxt-beyond-128.png'),
                      os.path.join(REPO, 'tools', 'web-player', 'assets', 'oxt-beyond-128.png'))):
        shutil.copyfile(src, out)
        print('wrote %s' % os.path.relpath(out, REPO))
    # The web IDE's favicon is in its page, so the page stays one file
    import base64
    import re
    with open(os.path.join(HERE, 'svg', 'icon-small.svg'), 'rb') as f:
        favicon = 'data:image/svg+xml;base64,' + base64.b64encode(f.read()).decode('ascii')
    ide_page = os.path.join(REPO, 'tools', 'web-ide', 'index.html')
    with open(ide_page, encoding='utf-8') as f:
        text = f.read()
    text, n = re.subn(r'<link rel="icon" href="[^"]*">', '<link rel="icon" href="%s">' % favicon, text)
    if n != 1:
        raise SystemExit('tools/web-ide/index.html: expected one <link rel="icon" href="...">')
    with open(ide_page, 'w', encoding='utf-8', newline='\n') as f:
        f.write(text)
    print('wrote the favicon of %s' % os.path.relpath(ide_page, REPO))

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
