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

"""A scrollbar's Orientation can be set in the Inspector (TerryL,
openxtalk.org p=25821). The engine has no setter (a scrollbar is horizontal
when it is wider than it is tall), so the Inspector showed it read only and
the only way to turn one round was to drag it. The Inspector's row now
names a setter that swaps the width and height about the centre, and a
getter that reads the orientation from the rect at once (the property
itself catches up only when the scrollbar is drawn, which on macOS is after
the script). The IDE tour's scrollbar-orientation step sets it through
revIDEPropertySet, the Inspector's own call, and reads it back as the
Inspector does and as a script does; these tests hold the pieces together.

  python3 -m unittest discover -s tools/ci/tests
"""

import os
import re
import unittest

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
PROPERTY_INFO = ('ide', 'Toolset', 'resources', 'supporting_files', 'property_definitions', 'propertyInfo.tsv')
LIBRARY = ('ide', 'Toolset', 'libraries', 'revidelibrary.8.livecodescript')
TOUR = ('tools', 'ci', 'ui-tour.livecodescript')


def read(*path):
    with open(os.path.join(REPO, *path), encoding='utf-8-sig') as f:
        return f.read()


def handler(script, kind, name):
    start = script.index('\n%s %s' % (kind, name))
    return script[start:script.index('\nend %s\n' % name, start)]


class TheInspectorRow(unittest.TestCase):
    def setUp(self):
        rows = [line.split('\t') for line in read(*PROPERTY_INFO).splitlines()]
        header = rows[0]
        self.read_only = header.index('Read Only')
        self.row = [r for r in rows if r[0].split(':')[0] == 'orientation']

    def test_one_row(self):
        self.assertEqual(len(self.row), 1)

    def test_it_names_a_getter_and_a_setter(self):
        self.assertEqual(self.row[0][0],
                         'orientation:revIDEGetScrollbarOrientationProperty:revIDESetScrollbarOrientationProperty')

    def test_it_is_not_read_only(self):
        self.assertEqual(self.row[0][self.read_only], 'false')

    def test_its_choices(self):
        self.assertEqual(self.row[0][1:5], ['Orientation', 'Basic', 'com.livecode.pi.enum', 'true'])
        self.assertIn('Horizontal,Vertical', self.row[0])


class TheHandlers(unittest.TestCase):
    def setUp(self):
        self.library = read(*LIBRARY)

    def test_the_setter_swaps_about_the_centre(self):
        setter = handler(self.library, 'command', 'revIDESetScrollbarOrientationProperty')
        self.assertIn('if word 1 of the name of pObject is not "scrollbar" then', setter)
        self.assertIn('if (pValue is "horizontal") is (tWidth > tHeight) then', setter)
        self.assertIn('set the width of pObject to tHeight', setter)
        self.assertIn('set the height of pObject to tWidth', setter)
        self.assertIn('set the width of pObject to tWidth + 1', setter)
        self.assertIn('set the loc of pObject to tLoc', setter)

    def test_the_getter_reads_the_rect(self):
        getter = handler(self.library, 'function', 'revIDEGetScrollbarOrientationProperty')
        self.assertIn('if the width of pObject > the height of pObject then', getter)


class TheTour(unittest.TestCase):
    def setUp(self):
        self.tour = read(*TOUR)

    def test_the_step(self):
        steps = re.search(r'^constant kSteps = "([^"]+)"', self.tour, re.M).group(1).split(',')
        self.assertIn('scrollbar-orientation', steps)
        step = handler(self.tour, 'on', 'tour_scrollbar_orientation')
        self.assertIn('revIDEPropertySet tBar, "orientation", "Vertical"', step)
        self.assertIn('revIDEPropertySet tBar, "orientation", "Horizontal"', step)
        self.assertIn('revIDEPropertySet tSquare, "orientation", "Horizontal"', step)
        self.assertIn('"132,0,148,200"', step)
        self.assertIn('"260,40,301,80"', step)
        self.assertIn('if tFails is not empty then throw', step)

    def test_what_it_checks(self):
        check = handler(self.tour, 'function', 'tourSbCheck')
        self.assertIn('revIDEPropertiesOfSection(the long id of pBar, "Basic")', check)
        self.assertIn('if tShown is not pOrientation then', check)
        self.assertIn('if the orientation of pBar is not pOrientation then', check)
        self.assertIn('if the rect of pBar is not pRect then', check)


if __name__ == '__main__':
    unittest.main()
