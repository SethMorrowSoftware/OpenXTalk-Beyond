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


"""What the audit of the user-facing stacks for 0.2.8-dp.2 found and mended,
read from the files without an engine: words the dark look left unreadable
in two examples, a checkbox drawn over its label, a code sample cut off on
Home, and the Academy's tagline cut off at the window's smallest size.

  python3 -m unittest discover -s tools/ci/tests
"""

import os
import re
import unittest

CI = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REPO = os.path.dirname(os.path.dirname(CI))
EXAMPLES = os.path.join(REPO, 'tools', 'examples')
PALETTES = os.path.join(REPO, 'ide', 'Toolset', 'palettes')


def read(*parts):
    with open(os.path.join(*parts), encoding='utf-8') as f:
        return f.read()


def handler(script, kind, name):
    found = re.search(r'^(?:private )?%s %s\b[^\n]*\n(.*?)^end %s$' % (kind, name, name), script, re.M | re.S)
    if found is None:
        raise AssertionError('no %s %s' % (kind, name))
    return found.group(1)


class DataGridTourInTheDark(unittest.TestCase):
    """A grid's rows are its own properties, light in both looks; its words
    had the kit's ink, which the dark look made white on those rows."""

    def setUp(self):
        self.look = handler(read(EXAMPLES, 'data-grid-tour.livecodescript'), 'command', 'gridLook')

    def test_the_rows_are_light_in_both_looks(self):
        self.assertIn('set the dgProps["row color"] of pGrid to "255,255,255"', self.look)

    def test_the_words_on_them_are_dark_in_both_looks(self):
        self.assertIn('set the dgProps["text color"] of pGrid to "15,23,42"', self.look)
        self.assertIn('set the dgProps["header text color"] of pGrid to "71,85,105"', self.look)
        self.assertNotRegex(self.look, r'text color"\] of pGrid to lkColor')


class SqliteTourInTheDark(unittest.TestCase):
    """The stage is light in both looks, and so are the colours the stack
    script puts on it: they were the dark look's, under the stage's dark
    words."""

    def setUp(self):
        self.script = read(EXAMPLES, 'sqlite-tour.livecodescript')
        self.looks = handler(self.script, 'command', 'setLooks')

    def test_the_stage_colours_are_the_light_looks_in_both_builds(self):
        light = self.looks.index('lkSetDark false')
        back = self.looks.index('lkSetDark tDark')
        self.assertLess(self.looks.index('put lkDark() into tDark'), light)
        for name in ('cOkBack', 'cOkEdge', 'cErrorBack', 'cErrorEdge', 'cInfoBack', 'cInfoEdge', 'cOn', 'cOnBack',
                     'cOnEdge', 'cOff', 'cOffInk', 'cOffBack', 'cOffEdge', 'cVennOn', 'cVennMid', 'cVennOff', 'cVennInk'):
            at = self.looks.index('set the %s of this stack to' % name)
            self.assertTrue(light < at < back, name)
        # (and the accents they are mixed from are read after it)
        self.assertLess(light, self.looks.index('put lkColor("sky") into tSky'))

    def test_the_look_is_put_back_for_the_rest_of_the_build(self):
        self.assertEqual(self.looks.count('lkSetDark'), 2)

    def test_the_badge_words_are_dark_on_its_white(self):
        badge = handler(self.script, 'command', 'badge')
        self.assertIn('lkBox("BadgeBg", lkR(758, 27, 884, 55), "255,255,255"', badge)
        self.assertIn('"Not connected", 12, "71,85,105", empty)', badge)


class SvgLabCheckboxes(unittest.TestCase):
    """GTK's box is wider than the engine's left margin of 4 leaves room
    for: it was drawn over each label's first letter."""

    def test_a_checkbox_has_room_for_its_box(self):
        options = handler(read(EXAMPLES, 'svg-lab.livecodescript'), 'command', 'buildOptions')
        self.assertIn('set the style of tObj to "checkbox"', options)
        self.assertIn('set the margins of tObj to "8,4,4,4"', options)
        self.assertIn('set the rect of tObj to kSideLeft - 4, tTop, kSideLeft + 200, tTop + 22', options)


class HomeFirstAppCode(unittest.TestCase):
    """At 13 the longest line wrapped in Linux's Source Code Pro, and the
    script's last lines were under the box's edge."""

    def setUp(self):
        self.home = read(PALETTES, 'web home', 'revwebhome.livecodescript')

    def test_the_sample_is_small_enough_for_its_longest_line(self):
        self.assertIn('put hmCodeField("apCode", "240,356,592,500", 12, 24, "pg_app") into tObj', self.home)

    def test_six_lines_of_24_fit_the_field(self):
        script = handler(self.home, 'function', 'hmFirstAppScript')
        self.assertEqual(script.count('& return'), 5)
        self.assertLessEqual(6 * 24, 500 - 356)

    def test_no_line_is_longer_than_the_field_at_12(self):
        script = handler(self.home, 'function', 'hmFirstAppScript')
        lines = re.findall(r'"((?:[^"])*)"', script)
        longest = max(len(line) for line in lines)
        # (Source Code Pro is 0.6 em wide: 7.2 at 12)
        self.assertLessEqual(longest * 7.2, 592 - 240)
        self.assertGreater(longest * 7.8, 592 - 240 - 12)


class AcademyTagline(unittest.TestCase):
    """At 1024 by 640 the tagline ended at the text size buttons, which are
    above it, and lost the lesson's minutes."""

    def setUp(self):
        self.academy = read(PALETTES, 'academy', 'revacademy.livecodescript')

    def test_the_tagline_has_the_columns_width(self):
        self.assertIn('set the rect of field "hdrTag" to sX, the top of field "hdrTag", tX - kPad, the bottom of field "hdrTag"',
                      self.academy)
        self.assertNotIn('set the rect of field "hdrTag" to sX, the top of field "hdrTag", the left of group "textSmaller"',
                         self.academy)

    def test_the_buttons_are_above_it(self):
        # (the buttons: 30 high from 22; the tagline: from 54)
        self.assertIn('set the topLeft of group "textSmaller" to the left of group "textBigger" - 6 - the width of group "textSmaller", 22',
                      self.academy)
        self.assertRegex(self.academy, r'get lkButton\("textSmaller", kWidth - kPlay - kPad - 92, 22, 30,')
        self.assertIn('put lkLabel("hdrTag", lkR(kSide + kPad, 54,', self.academy)

    def test_a_tagline_too_long_loses_its_units_name_not_its_end(self):
        fit = handler(self.academy, 'command', 'acFitTag')
        self.assertIn('put sTag into tTag', fit)
        self.assertEqual(fit.count('the formattedWidth of field "hdrTag" of me <= the width of field "hdrTag" of me'), 2)
        self.assertIn('put char tAt + 3 to -1 of tTag into field "hdrTag" of me', fit)
        self.assertRegex(self.academy, r'(?m)^local sTag$')

    def test_everything_that_writes_the_tagline_fits_it(self):
        self.assertNotRegex(self.academy, r'(into|after) field "hdrTag"\n')
        header = handler(self.academy, 'command', 'acHeader')
        self.assertIn('put pTag into sTag\n   acFitTag', header)
        check = handler(self.academy, 'command', 'acLessonCheck')
        self.assertIn('after sTag\n   acFitTag', check)


if __name__ == '__main__':
    unittest.main()
