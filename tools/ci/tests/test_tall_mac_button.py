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

"""A standard button taller than the Mac's push button is drawn its whole
height on the Mac (Skids, openxtalk.org p=25824). AppKit's push bezel is
about 21 points high whatever the frame, so a 50-point standard button kept
a 21-point bezel in its middle; Windows and Linux draw it its whole height.
From macOS 11 the engine draws one taller than kMCMacFlexiblePushHeight
with the bezel AppKit draws at any height (NSBezelStyleRegularSquare, the
flexible push), in the button's own rect. The IDE tour's controls step
reads the rows of its 50-point "Tall" button that differ from the card: on
rc.6.10's Mac screenshots that is rows 13 to 34 (light) and 14 to 33 (dark)
of 0 to 49, and the step wants four fifths of them. These tests hold the
pieces together.

  python3 -m unittest discover -s tools/ci/tests
"""

import os
import re
import unittest

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))


def read(*path):
    with open(os.path.join(REPO, *path), encoding='utf-8') as f:
        return f.read()


class TheEngine(unittest.TestCase):
    def setUp(self):
        self.theme = read('engine', 'src', 'osxtheme.mm')
        start = self.theme.index('else if (p_info.button.info.kind == kThemePushButton)\n')
        self.push = self.theme[start:self.theme.index('t_control = t_button;', start)]

    def test_the_height(self):
        self.assertIn('#define kMCMacFlexiblePushHeight 30', self.theme)

    def test_a_tall_button_takes_the_flexible_bezel(self):
        self.assertIn('if (@available(macOS 11.0, *))\n'
                      '\t\t\t\t\t\tt_flexible = p_info.dest.height > kMCMacFlexiblePushHeight;', self.push)
        self.assertIn('[t_button setBezelStyle:t_flexible ? NSBezelStyleRegularSquare : NSRoundedBezelStyle];',
                      self.push)

    def test_in_its_own_rect(self):
        # the push bezel's frame is 5 points wider either side; the
        # flexible one's is the button's rect
        self.assertIn('t_frame.origin.x -= 5;\n\t\t\t\t\tt_frame.size.width += 10;', self.theme)
        flexible = self.push.split('if (t_flexible)\n', 1)[1].split('}', 1)[0]
        self.assertIn('t_frame.origin.x += 5;', flexible)
        self.assertIn('t_frame.size.width -= 10;', flexible)
        self.assertLess(self.push.index('if (t_flexible)\n'), self.push.index('initWithFrame:t_frame'))


class TheTour(unittest.TestCase):
    def setUp(self):
        self.tour = read('tools', 'ci', 'ui-tour.livecodescript')

    def test_the_button(self):
        stack = self.tour.split('function tourControlsStack', 1)[1].split('end tourControlsStack', 1)[0]
        made = stack.split('create button "Tall"', 1)[1].split('create ', 1)[0]
        # a standard button (no style set), 50 points high
        self.assertNotIn('set the style', made)
        self.assertIn('set the rect of it to "280,210,440,260"', made)

    def test_the_check(self):
        step = self.tour.split('\non tour_controls', 1)[1].split('\nend tour_controls', 1)[0]
        check = step.split('tourGrab "Tall"', 1)[1].split('-- The window colour', 1)[0]
        self.assertIn('put tourRowsDrawn(tBack, 12) into tExtent', check)
        self.assertIn('item 2 of tExtent - item 1 of tExtent + 1 >= sPixHeight * 4 div 5', check)
        # on every platform: Windows and Linux already draw it whole
        self.assertNotIn('the platform', check)
        steps = re.search(r'^constant kSteps = "([^"]+)"', self.tour, re.M).group(1).split(',')
        self.assertIn('controls', steps)


if __name__ == '__main__':
    unittest.main()
