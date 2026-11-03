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

"""The Waterwheel page on the GitHub Pages site
(tools/pages/games/waterwheel). The page runs its standalone.zip on SVG Lab's
copy of the engine, which has Box2Dxt, and the package carries the stack and
the Box2Dxt module; the gallery lists it.

  python3 -m unittest discover -s tools/ci/tests
"""

import os
import unittest
import zipfile

CI = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GAMES = os.path.join(os.path.dirname(CI), 'pages', 'games')
PAGE = os.path.join(GAMES, 'waterwheel')
ENGINE = 'standalone-community-9.7.1-BeyondEngine'


def read(*path):
    with open(os.path.join(*path), encoding='utf-8') as f:
        return f.read()


class WaterwheelPage(unittest.TestCase):
    def test_the_page_runs_on_svg_labs_engine(self):
        page = read(PAGE, 'index.html')
        self.assertIn('src="../svg-lab/%s.js"' % ENGINE, page)
        self.assertIn("'../svg-lab/' + f", page)
        self.assertTrue(os.path.isfile(os.path.join(GAMES, 'svg-lab', ENGINE + '.wasm')))
        self.assertFalse(os.path.exists(os.path.join(PAGE, ENGINE + '.wasm')))

    def test_the_package_has_its_stack_and_fonts(self):
        with zipfile.ZipFile(os.path.join(PAGE, 'standalone.zip')) as z:
            self.assertIn('boot/standalone/DroidSansCombined.ttf', z.namelist())
            data = z.read('boot/__startup.data')
        self.assertGreater(len(data), 10000)

    def test_the_page_sets_its_own_colours(self):
        # the same in a browser's light and dark mode
        page = read(PAGE, 'index.html')
        self.assertIn('--ink:', page)
        self.assertNotIn('prefers-color-scheme', page)

    def test_the_gallery_lists_it(self):
        page = read(GAMES, 'index.html')
        self.assertIn('href="waterwheel/"', page)
        self.assertIn('src="waterwheel/poster.png"', page)
        self.assertTrue(os.path.isfile(os.path.join(PAGE, 'poster.png')))


if __name__ == '__main__':
    unittest.main()
