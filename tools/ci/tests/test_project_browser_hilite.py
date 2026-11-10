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

"""The names on a selected Project Browser row, on every platform.

The Project Browser draws a selected row in its own blue (48,160,209), or
in grey (212,212,212) while its list does not have the focus, and its
names in revIDEHilitedTextColor's colour for that hilite
(ide/Toolset/libraries/revidelibrary.8.livecodescript). LiveCode drew them
white. OpenXTalk made them the accentColor, which is a blue on macOS
(controlAccentColor), Windows and the web (the hiliteColor), so up to
0.2.7-rc.6.18 the names were blue on the blue hilite, the same in the light
and dark appearances (bwmilby, openxtalk.org p=26171, on the Mac;
littlenemo, p=26169, on the web). They are white on the blue again, and
black on a light hilite such as the grey; Linux keeps its own rule, black
or white by the GTK selection colour's luminance (p=25550).

The IDE test ide/tests/projectbrowser/hilite.livecodescript asks the
function for each platform; the IDE tour's project-browser step
(tools/ci/ui-tour.livecodescript) selects the sample's button's row on
every platform's build and reads the colours the row draws. This test
reads the source, and models the rule, so that every platform's checks
hold them.

  python3 -m unittest discover -s tools/ci/tests
"""

import os
import re
import unittest

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))

# the data view's hilites: the Project Browser's own blue and its alternate
# (revIDEColor), and kDefaultDimmedHiliteColor
HILITES = ((48, 160, 209), (34, 154, 206), (212, 212, 212))


def read(*parts):
    with open(os.path.join(REPO, *parts), encoding='utf-8') as f:
        return f.read()


def luminance(rgb):
    total = 0.0
    for value, weight in zip(rgb, (0.2126, 0.7152, 0.0722)):
        value /= 255
        value = value / 12.92 if value <= 0.03928 else ((value + 0.055) / 1.055) ** 2.4
        total += value * weight
    return total


def contrast(one, two):
    a, b = luminance(one) + 0.05, luminance(two) + 0.05
    return max(a, b) / min(a, b)


def hilited_text(rgb, platform):
    """The rule revIDEHilitedTextColor follows for a colour given as RGB."""
    if platform == 'Linux':
        return (0, 0, 0) if luminance(rgb) > 0.179 else (255, 255, 255)
    return (0, 0, 0) if luminance(rgb) > 0.5 else (255, 255, 255)


class TheRule(unittest.TestCase):

    def setUp(self):
        src = read('ide', 'Toolset', 'libraries', 'revidelibrary.8.livecodescript')
        start = src.index('function revIDEHilitedTextColor pHiliteColor, pWeb, pPlatform\n')
        self.body = src[start:src.index('end revIDEHilitedTextColor\n', start)]
        self.src = src

    def test_white_on_the_blue_and_black_on_the_grey_beyond_linux(self):
        # numbers are no longer handed to the accentColor on macOS and Windows
        self.assertNotIn('if the platform is not "Linux" or the number of items of pHiliteColor is not 3 then',
                         self.body)
        self.assertIn('if pPlatform is "Linux" and not pWeb then', self.body)
        self.assertIn('if tLuminance > 0.179 then return "0,0,0"', self.body)
        tail = self.body[self.body.index('if pPlatform is "Linux" and not pWeb then'):]
        tail = tail[tail.index('end if'):]
        self.assertIn('if tLuminance > 0.5 then return "0,0,0"\n   return "255,255,255"', tail)
        # a colour given by name answers as before
        self.assertIn('if pWeb then return "255,255,255"\n      return revIDEColor("dataView_TextHiliteColor")',
                      self.body)
        # the platform can be given, so that one platform's IDE tests ask
        # for every platform's answer
        self.assertIn('put the platform into pPlatform', self.body)

    def test_the_hilites_the_project_browser_draws(self):
        # the colours the model is checked on are the IDE's
        self.assertIn('case "dataView_hiliteColor"\n         return "48,160,209"', self.src)
        self.assertIn('case "dataView_alternateHiliteColor"\n         return "34,154,206"', self.src)
        dataview = read('stack-scripts', 'ide', 'Toolset', 'palettes', 'revCore.8.livecode.bst', 'scripts',
                        'stack_revDataViewControl_button_id_1003.livecodescript')
        self.assertIn('constant kDefaultDimmedHiliteColor = "212,212,212"', dataview)
        pb = read('ide', 'Toolset', 'palettes', 'project browser', 'revprojectbrowserbehavior.livecodescript')
        self.assertIn('set the viewProp["hilite color"] of group "objectList" of me to revIDEColor("dataView_HiliteColor")',
                      pb)

    def test_every_platform_reads_on_every_hilite(self):
        for platform in ('MacOS', 'Win32', 'Linux', 'web'):
            for hilite in HILITES:
                text = hilited_text(hilite, platform)
                # LiveCode's white on its blue is 2.97 to 1
                self.assertGreaterEqual(contrast(hilite, text), 2.9, (platform, hilite, text))
        # LiveCode's white on the blue beyond Linux, black on the grey
        for platform in ('MacOS', 'Win32', 'web'):
            self.assertEqual(hilited_text((48, 160, 209), platform), (255, 255, 255))
            self.assertEqual(hilited_text((34, 154, 206), platform), (255, 255, 255))
            self.assertEqual(hilited_text((212, 212, 212), platform), (0, 0, 0))
        # the blue the names were, on the blue hilite: what was reported
        self.assertLess(contrast((48, 160, 209), (0, 122, 255)), 1.5)


class TheIDETest(unittest.TestCase):

    def test_it_asks_for_each_platform(self):
        test = read('ide', 'tests', 'projectbrowser', 'hilite.livecodescript')
        self.assertIn('on TestHilitedNamesAreWhiteOnMacAndWindows', test)
        self.assertIn('repeat for each item tPlatform in "MacOS,Win32"', test)
        self.assertIn('revIDEHilitedTextColor(revIDEColor("dataView_hiliteColor"), false, tPlatform) is "255,255,255"',
                      test)
        self.assertIn('revIDEHilitedTextColor(kDimmed, false, tPlatform) is "0,0,0"', test)
        self.assertIn('on TestHilitedNamesCanBeRead', test)
        self.assertIn('__Contrast(tHilite, tText) >= 2.9', test)
        self.assertIn('constant kDimmed = "212,212,212"', test)


class TheTourStep(unittest.TestCase):

    def setUp(self):
        self.tour = read('tools', 'ci', 'ui-tour.livecodescript')
        self.step = self.tour[self.tour.index('\non tour_project_browser\n'):
                              self.tour.index('\nend tour_project_browser\n')]
        start = self.tour.index('\nfunction tourPBHiliteProblem pStack, pObject\n')
        self.check = self.tour[start:self.tour.index('\nend tourPBHiliteProblem\n', start)]

    def test_every_platform_measures_it(self):
        self.assertIn('put tourPBHiliteProblem(tStack, tButton) into tProblem', self.step)
        # not inside the Linux branch: it ends before the call
        call = self.step.index('put tourPBHiliteProblem(tStack, tButton) into tProblem')
        linux = self.step.index('if the platform is "Linux" then')
        self.assertGreater(call, self.step.index('end if', self.step.index('set the itemDelimiter to comma\n   end if',
                                                                             linux)))
        # the stack closes before the step throws
        self.assertLess(self.step.index('close stack tStack', call), self.step.index('if tProblem is not empty then throw'))

    def test_the_hilites_and_the_row(self):
        self.assertIn('revIDEColor("dataView_hiliteColor")', self.check)
        self.assertIn('revIDEColor("dataView_alternateHiliteColor")', self.check)
        self.assertIn('kPBDimmed into tHilites', self.check)
        self.assertIn('tRatio < 2.9', self.check)
        # the row the list draws for the sample's button, selected
        self.assertIn('dispatch function "getVisibleRow" to card "list" of stack pStack with pObject', self.check)
        self.assertIn('set the dvHilitedRows of tList to tRow', self.check)
        self.assertIn('put the dvControlOfRow[tRow] of tList into tControl', self.check)
        self.assertIn('put the foregroundColor of field "name" of tControl into tName', self.check)
        self.assertIn('put the backgroundColor of graphic "background" of tControl into tBack', self.check)
        self.assertIn('if tName is not revIDEHilitedTextColor(tBack) then', self.check)
        self.assertIn('tourShotStack pStack, "12b-project-browser-selected"', self.check)
        self.assertIn('set the dvHilitedRows of tList to empty', self.check)
        self.assertLess(self.tour.index('constant kPBDimmed = "212,212,212"'),
                        self.tour.index('function tourPBHiliteProblem'))

    def test_the_rows_draw_with_the_rule(self):
        # each row behaviour of the Project Browser takes its selected
        # names' colour from the function
        folder = os.path.join('ide', 'Toolset', 'palettes', 'project browser', 'behaviors')
        for name in ('container', 'control', 'group', 'library', 'section'):
            src = read(folder, 'revideprojectbrowser%srowbehavior.livecodescript' % name)
            self.assertIn('set the foregroundColor of field "type" of me to revIDEHilitedTextColor(pHiliteColor)', src,
                          name)


if __name__ == '__main__':
    unittest.main()
