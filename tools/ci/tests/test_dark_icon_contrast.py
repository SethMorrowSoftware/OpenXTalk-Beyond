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
"""Two icons that could hardly be seen in the dark appearance on the Mac
(bwmilby, openxtalk.org, 2026-11-09):

- the Extension Manager's row icon, the row template's purple 96,87,127,
  is lightened in the dark appearance (extensionsIconColor) and is the
  template's in the light one, as before;
- the Project Browser's Refresh button shows revIcons' "white-refresh" in
  the dark appearance and "dark-refresh" in the light one
  (pbRefreshIconForAppearance); on Linux the stack's own choice, by the
  window's colour, which was right there, is left as it is.

The IDE tests ide/tests/extensionmanager/iconcolor and
ide/tests/projectbrowser/refreshicon, and the IDE tours' extension-manager
and project-browser steps, run them on an engine; these hold the pieces
together and check the colour sums here.

  python3 -m unittest discover -s tools/ci/tests
"""

import os
import re
import unittest

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
EM = os.path.join(REPO, 'ide', 'Toolset', 'palettes', 'extension manager')
LIST = os.path.join(EM, 'revideextensionmanagerlistbehavior.livecodescript')
ROW = os.path.join(EM, 'revideextensionmanagerrowbehavior.livecodescript')
PB = os.path.join(REPO, 'ide', 'Toolset', 'palettes', 'project browser', 'revprojectbrowserbehavior.livecodescript')
TOURS = [os.path.join(REPO, 'tools', 'ci', n) for n in ('ui-tour.livecodescript', 'web-ide-tour.livecodescript')]


def read(path):
    with open(path, encoding='utf-8') as f:
        return f.read().lstrip('﻿')


def handler(text, name):
    m = re.search(r'^[ \t]*(?:private[ \t]+)?(?:command|on|function)[ \t]+%s\b(.*?)^[ \t]*end[ \t]+%s\b'
                  % (re.escape(name), re.escape(name)), text, re.M | re.S)
    if m is None:
        raise AssertionError('no handler ' + name)
    return m.group(1)


def code(body):
    return '\n'.join(line.split('--', 1)[0] for line in body.splitlines())


def lighten(rgb):
    # extensionsIconColor's sum: six tenths of the way to white (LiveCode's
    # round rounds half away from zero; no channel here lands on a half)
    return tuple(int(c + (255 - c) * 6 / 10 + 0.5) for c in rgb)


def darken(rgb):
    return tuple(int(c * 4 / 10 + 0.5) for c in rgb)


def luminance(rgb):
    total = 0
    for c, w in zip(rgb, (0.2126, 0.7152, 0.0722)):
        v = c / 255
        v = v / 12.92 if v <= 0.03928 else ((v + 0.055) / 1.055) ** 2.4
        total += v * w
    return total


def contrast(a, b):
    la, lb = luminance(a) + 0.05, luminance(b) + 0.05
    return max(la, lb) / min(la, lb)


class ExtensionManagerIcon(unittest.TestCase):
    TEMPLATE = (96, 87, 127)

    def test_the_colour_sum(self):
        body = code(handler(read(LIST), 'extensionsIconColor'))
        self.assertIn('if pDark is not true then return pColor', body)
        self.assertIn('if the number of items of pColor is not 3 then return pColor', body)
        self.assertIn('if tChannel is not a number then return pColor', body)
        self.assertIn('round(tChannel + (255 - tChannel) * 6 / 10)', body)
        self.assertEqual(lighten(self.TEMPLATE), (191, 188, 204))

    def test_seen_where_it_was_not(self):
        icon = lighten(self.TEMPLATE)
        selected = darken((226, 238, 185))   # the Mac's dark selected row
        self.assertEqual(selected, (90, 95, 74))
        self.assertLess(contrast(self.TEMPLATE, selected), 1.5)
        for back in (selected, (30, 30, 30), (42, 42, 42)):
            self.assertGreaterEqual(contrast(icon, back), 3, back)

    def test_the_row_sets_it_by_appearance(self):
        body = code(handler(read(ROW), 'LayoutControl'))
        self.assertIn('the foregroundColor of widget "svgicon" of group "extensionRow" of card "templates" of this stack into tIconColor', body)
        dark, light = body.split('if revIDEAppearanceIsDark() then', 1)[1].split('\n   else\n', 1)
        light = light.split('\n   end if', 1)[0]
        self.assertIn('set the foregroundColor of widget "svgicon" of me to extensionsIconColor(tIconColor, true)', dark)
        # the light appearance: the template's, as before
        self.assertIn('set the foregroundColor of widget "svgicon" of me to tIconColor', light)
        self.assertNotIn('extensionsIconColor', light)

    def test_the_tests(self):
        ide = read(os.path.join(REPO, 'ide', 'tests', 'extensionmanager', 'iconcolor.livecodescript'))
        self.assertIn('"191,188,204"', ide)
        tour = handler(read(TOURS[0]), 'tour_extension_manager')
        self.assertIn('tourEmFirstIconColor(tStack)', tour)
        self.assertIn('tRatio < 3', tour)


class ProjectBrowserRefreshIcon(unittest.TestCase):
    def setUp(self):
        self.text = read(PB)

    def test_set_with_the_rows_colours(self):
        body = code(handler(self.text, 'setUpProjectView'))
        self.assertIn('pbKeepRowsDark\n   pbRefreshIconForAppearance', body)
        # setUpProjectView runs when the stack opens and on a switch
        self.assertIn('setUpProjectView', code(handler(self.text, 'preOpenStack')))
        self.assertIn('setUpProjectView', code(handler(self.text, 'ideSystemAppearanceChanged')))

    def test_linux_left_as_it_was(self):
        body = code(handler(self.text, 'pbRefreshIconForAppearance'))
        first = [l.strip() for l in body.splitlines() if l.strip() and not l.strip().startswith('local')][0]
        self.assertEqual(first, 'if the platform is "Linux" then exit pbRefreshIconForAppearance')
        self.assertIn('pbRefreshIconName(revIDEAppearanceIsDark())', body)
        self.assertIn('if there is not an image tName of card 1 of stack "revIcons" then exit', body)

    def test_the_names(self):
        body = code(handler(self.text, 'pbRefreshIconName'))
        self.assertIn('if pDark is true then return "white-refresh"', body)
        self.assertIn('return "dark-refresh"', body)
        with open(os.path.join(REPO, 'ide', 'Toolset', 'palettes', 'revicons.rev'), 'rb') as f:
            icons = f.read()
        self.assertIn(b'white-refresh', icons)
        self.assertIn(b'dark-refresh', icons)

    def test_both_tours_check_it(self):
        for path in TOURS:
            check = code(handler(read(path), 'tourRefreshProblem'))
            self.assertIn('if the platform is not "Linux" then', check, path)
            self.assertIn('if revIDEAppearanceIsDark() then put "white-refresh" into tWant', check, path)
        self.assertIn('TestRefreshIconFollowsTheAppearance',
                      read(os.path.join(REPO, 'ide', 'tests', 'projectbrowser', 'refreshicon.livecodescript')))


if __name__ == '__main__':
    unittest.main()
