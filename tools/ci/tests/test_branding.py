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

"""The OXT-Beyond artwork (Installer/oxt-beyond/branding): every drawing
is made from SVG Lab's logo (tools/pages/games/svg-lab/beyond-logo.svg) as
draw_branding.py makes it today, so a logo changed without running it
fails here; the moving logo moves; and every copy elsewhere (the web
pages' brand/ folder, the Stack Player's icon, the web IDE's favicon, the
About window's images) is the file it was made from. CairoSVG is not
needed: only the drawings are compared, and the PNG files are compared
byte for byte with their copies.

  python3 -m unittest discover -s tools/ci/tests
"""

import base64
import os
import re
import struct
import sys
import unittest
import xml.etree.ElementTree as ET

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
BRANDING = os.path.join(REPO, 'Installer', 'oxt-beyond', 'branding')
sys.path.insert(0, BRANDING)

import draw_branding  # noqa: E402

SVG = '{http://www.w3.org/2000/svg}'


def read(*path, mode='r'):
    with open(os.path.join(REPO, *path), mode, **({} if 'b' in mode else {'encoding': 'utf-8'})) as f:
        return f.read()


def png_size(data):
    assert data[:8] == b'\x89PNG\r\n\x1a\n'
    return struct.unpack('>II', data[16:24])


class TheDrawings(unittest.TestCase):

    def test_each_is_as_draw_branding_makes_it(self):
        for name, draw in draw_branding.DRAWINGS.items():
            self.assertEqual(read('Installer', 'oxt-beyond', 'branding', 'svg', name), draw(), name)

    def test_the_icon_is_svg_labs_logo(self):
        self.assertEqual(read('Installer', 'oxt-beyond', 'branding', 'svg', 'icon.svg'),
                         read('tools', 'pages', 'games', 'svg-lab', 'beyond-logo.svg'))

    def test_each_is_svg(self):
        for name in draw_branding.DRAWINGS:
            root = ET.fromstring(read('Installer', 'oxt-beyond', 'branding', 'svg', name))
            self.assertEqual(root.tag, SVG + 'svg', name)

    def test_the_small_icon_leaves_out_the_fine_parts(self):
        small = draw_branding.icon_small()
        for part in ('class="tick"', 'class="beyond"', 'class="arc"', 'fill="#FFF4B0"'):
            self.assertNotIn(part, small)
        for part in ('class="oxt"', 'class="bolt"', 'class="rim"', 'clip-path="url(#oxt.letters)"'):
            self.assertIn(part, small)

    def test_the_moving_logo_moves(self):
        root = ET.fromstring(draw_branding.icon_animated())
        animations = [e for e in root.iter() if e.tag in (SVG + 'animate', SVG + 'animateTransform')]
        moved = {e.get('attributeName') for e in animations}
        self.assertEqual(moved, {'transform', 'opacity', 'points'})
        for e in animations:
            self.assertEqual(e.get('repeatCount'), 'indefinite')
            self.assertRegex(e.get('dur'), r'^\d+(\.\d+)?s$')
        # The rays, the glow, the halo, the shine, two arcs (points and
        # opacity each) and every spark
        self.assertGreaterEqual(len(animations), 4 + 4 + 5)
        # Without the animation it is the still logo
        still = re.sub(r'<animate(Transform)? [^>]*/>', '', draw_branding.icon_animated())
        still = re.sub(r'></(rect|circle|polygon|polyline)>', '/>', still)
        self.assertEqual(still.replace('translate(-200 0)', 'translate(620 0)'), draw_branding.logo())

    def test_a_changed_logo_is_caught(self):
        # draw_branding.py finds the parts it changes, or stops
        here = draw_branding.LOGO
        try:
            draw_branding.LOGO = os.path.join(REPO, 'tools', 'pages', 'games', 'svg-lab', 'sample.svg')
            with self.assertRaises(SystemExit):
                draw_branding.icon_small()
        finally:
            draw_branding.LOGO = here

    def test_the_splash_keeps_off_the_version_line(self):
        # The IDE writes the version at 1x 24,134 to 560,170 (field
        # "moreinfo"): 268 and below at the drawing's 2x. The logo nested in
        # the splash ends above it.
        for dark in (True, False):
            m = re.search(r'<svg x="([\d.]+)" y="([\d.]+)" width="([\d.]+)" height="([\d.]+)"',
                          draw_branding.splash(dark))
            self.assertLess(float(m.group(2)) + float(m.group(4)), 268)


class TheCopies(unittest.TestCase):

    def test_the_web_pages_logo(self):
        for source, copy in (('icon-small.svg', 'icon.svg'), ('icon.svg', 'logo.svg'),
                             ('icon-animated.svg', 'logo-animated.svg')):
            self.assertEqual(read('tools', 'pages', 'brand', copy),
                             read('Installer', 'oxt-beyond', 'branding', 'svg', source), copy)
        social = read('tools', 'pages', 'brand', 'social.png', mode='rb')
        self.assertEqual(social, read('Installer', 'oxt-beyond', 'branding', 'art', 'oxt-beyond-banner.png', mode='rb'))
        self.assertEqual(png_size(social), (1280, 640))

    def test_the_stack_players_icon(self):
        self.assertEqual(read('tools', 'web-player', 'assets', 'oxt-beyond-128.png', mode='rb'),
                         read('Installer', 'oxt-beyond', 'branding', 'png', 'oxt-beyond-128.png', mode='rb'))

    def test_the_web_ides_favicon(self):
        page = read('tools', 'web-ide', 'index.html')
        icons = re.findall(r'<link rel="icon" href="data:image/svg\+xml;base64,([^"]+)">', page)
        self.assertEqual(len(icons), 1)
        self.assertEqual(base64.b64decode(icons[0]).decode('utf-8'),
                         read('Installer', 'oxt-beyond', 'branding', 'svg', 'icon-small.svg'))

    def test_the_icon_sizes(self):
        for n in draw_branding.ICON_SIZES:
            data = read('Installer', 'oxt-beyond', 'branding', 'png', 'oxt-beyond-%d.png' % n, mode='rb')
            self.assertEqual(png_size(data), (n, n))

    def test_the_about_window_takes_the_icons(self):
        # tools/oxt/ide-stack-patch.sh puts these PNG files into the IDE
        # stack; the images keep their size, so the dialogs keep their layout
        patch = read('tools', 'oxt', 'ide-stack-patches', 'branding-dialog-icons.txt')
        images = re.findall(r'^image: (\S+)$', patch, re.M)
        self.assertEqual(images, ['Installer/oxt-beyond/branding/png/oxt-beyond-32.png',
                                  'Installer/oxt-beyond/branding/png/oxt-beyond-64.png'])
        for image, n in zip(images, (32, 64)):
            self.assertEqual(png_size(read(*image.split('/'), mode='rb')), (n, n))


if __name__ == '__main__':
    unittest.main()
