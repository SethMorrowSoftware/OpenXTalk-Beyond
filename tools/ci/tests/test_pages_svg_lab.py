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

"""The SVG Lab page on the GitHub Pages site (tools/pages/games/svg-lab). The
page runs its standalone.zip on the Stack Player's engine, gives the stack the
two file functions it calls in place of the desktop's dialogs, and is listed
on the games page; its sample art is well formed and uses the features the
lab shows.

  python3 -m unittest discover -s tools/ci/tests
"""

import os
import re
import unittest
import xml.etree.ElementTree as ElementTree
import zipfile

CI = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GAMES = os.path.join(os.path.dirname(CI), 'pages', 'games')
LAB = os.path.join(GAMES, 'svg-lab')


def read(*path):
    with open(os.path.join(*path), encoding='utf-8') as f:
        return f.read()


class SvgLabPage(unittest.TestCase):
    def test_the_page_uses_the_players_engine(self):
        page = read(LAB, 'index.html')
        self.assertIn('../../player/@ENGINE_JS@', page)
        self.assertIn("'../../player/' + f", page)

    def test_the_page_answers_the_stacks_file_buttons(self):
        page = read(LAB, 'index.html')
        self.assertRegex(page, r'function oxtPickSvg\(')
        self.assertRegex(page, r'function oxtSaveSvg\(')
        self.assertIn("findStackWithName('SVG Lab').svgWebFile(", page)

    def test_the_package_has_its_stack_and_fonts(self):
        with zipfile.ZipFile(os.path.join(LAB, 'standalone.zip')) as z:
            names = z.namelist()
        self.assertIn('boot/__startup.data', names)
        self.assertIn('boot/standalone/DroidSansCombined.ttf', names)

    def test_the_games_page_lists_it(self):
        page = read(GAMES, 'index.html')
        self.assertIn('href="svg-lab/"', page)
        self.assertIn('src="svg-lab/poster.png"', page)
        self.assertTrue(os.path.isfile(os.path.join(LAB, 'poster.png')))

    def test_the_sample_uses_what_the_lab_shows(self):
        text = read(LAB, 'sample.svg')
        ElementTree.fromstring(text)
        self.assertIn('<style>', text)
        self.assertIn('<clipPath', text)
        self.assertIn('url(#sea.glow)', text)
        self.assertRegex(text, r'<radialGradient [^>]*cx="0\.35"')
        self.assertRegex(text, r' opacity="0?\.\d+"')
        # arc flags written together, and T after T
        self.assertRegex(text, r'a8 8 0 1116 0')
        self.assertRegex(text, r' t[\d.]+ 0 t[\d.]+ 0')


if __name__ == '__main__':
    unittest.main()
