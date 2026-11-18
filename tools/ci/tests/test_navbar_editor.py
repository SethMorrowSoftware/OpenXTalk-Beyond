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

"""The Inspector's editor of a navigation bar's items shows every item's
icon in the dark appearance too (bwmilby, issue 568). The editor
(ide/Toolset/palettes/inspector/editors/com.livecode.pi.navbar) is a
navigation bar widget in its edit mode, which draws a white sheet with black
labels in either appearance and each item's icon in the widget's foreground
colour. The editor's widget had no colour of its own, so the icon took the
Inspector's text colour, light in the dark appearance: on a Mac it could not
be seen on the sheet, on Linux hardly. The editor now gives its widget the
labels' black as its own colour, which the widget draws as set in either
appearance (MCWidgetGetMyPaintForAppearance swaps only a colour that is
still the widget's light default, 128,128,128).

The engine's tests run the editor as the Inspector makes it and read its
pixels (tests/lcs/inspector/navbar.livecodescript), and the IDE tour reads
the real Inspector on the screen in the light and the dark appearance
(tools/ci/ui-tour.livecodescript, the step inspector-navbar). These tests
hold the pieces to each other: the editor's colour to the sheet the widget
draws, and where the tests look for an icon to where the widget draws it.

  python3 -m unittest discover -s tools/ci/tests
"""

import os
import re
import unittest

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))

EDITORS = ('ide', 'Toolset', 'palettes', 'inspector', 'editors')


def read(*path):
    with open(os.path.join(REPO, *path), encoding='utf-8-sig') as f:
        return f.read()


def handler(script, kind, name):
    """The handler of a LiveCode Script script, from its first line to the
    line before its end."""
    start = script.index('\n%s %s' % (kind, name))
    return script[start:script.index('\nend %s\n' % name, start)]


def lcb_handler(source, name):
    """The handler of a LiveCode Builder source, public or private."""
    start = re.search(r'^(?:public |private )?handler %s\(' % re.escape(name), source, re.M).start()
    return source[start:source.index('\nend handler', start)]


def colour(text):
    """A LiveCode Builder colour's list ("1, 1, 1", "193/255, ...") as red,
    green and blue of 255."""
    out = []
    for part in text.split(','):
        part = part.strip()
        if '/' in part:
            top, bottom = part.split('/')
            out.append(round(255 * float(top) / float(bottom)))
        else:
            out.append(round(255 * float(part)))
    return tuple(out)


def sheet_paint(source, location, kind):
    """The colour the widget's getPaint gives for pLocation and pType, as
    red, green and blue of 255."""
    get = lcb_handler(source, 'getPaint')
    part = get[get.index('pLocation is "%s"' % location):]
    part = part[part.index('pType is "%s"' % kind):]
    found = re.match(r'pType is "%s" then\s+return solid paint with color \[([^\]]+)\]' % kind, part)
    if found is None:
        raise AssertionError('getPaint has no colour for %s, %s' % (location, kind))
    return colour(found.group(1))


class TheSheet(unittest.TestCase):
    """What the widget draws in its edit mode, which the editor's colour is
    chosen for: a white sheet, black labels, the icon in the widget's
    foreground colour and the highlighted icon in the highlight colour."""

    def setUp(self):
        self.source = read('extensions', 'widgets', 'navbar', 'navbar.lcb')

    def test_the_sheet_is_white_and_its_labels_black(self):
        edit = lcb_handler(self.source, 'drawNavBarEditMode')
        self.assertIn('set the paint of this canvas to getPaint("background","editmode-fill")', edit)
        self.assertEqual(sheet_paint(self.source, 'background', 'editmode-fill'), (255, 255, 255))
        label = lcb_handler(self.source, 'drawEditModeLabel')
        self.assertIn('set the paint of this canvas to getPaint("text","editmode-fill")', label)
        self.assertEqual(sheet_paint(self.source, 'text', 'editmode-fill'), (0, 0, 0))

    def test_an_icon_is_drawn_in_the_widgets_foreground_colour(self):
        content = lcb_handler(self.source, 'drawEditModeContent')
        self.assertIn('drawIcon(mNavData[tX]["icon_path"], false)', content)
        self.assertIn('drawIcon(mNavData[tX]["hilited_icon_path"], true)', content)
        icon = lcb_handler(self.source, 'drawIcon')
        self.assertRegex(icon, r'if pSelected then\s+set the paint of this canvas to my highlight paint\s+else\s+'
                               r'set the paint of this canvas to paintFor\(0, kForeLight, kForeDark\)\s+end if')

    def test_a_colour_set_by_hand_is_not_the_one_the_dark_appearance_swaps(self):
        # paintFor draws kForeDark only for a colour that is still kForeLight
        light = re.search(r'^constant kForeLight is \[([^\]]+)\]', self.source, re.M).group(1)
        self.assertEqual(tuple(int(x) for x in light.split(',')), (128, 128, 128))
        behavior = read(*EDITORS, 'com.livecode.pi.navbar.behavior.livecodescript')
        ink = re.search(r'^constant kSheetInk = "([^"]+)"', behavior, re.M).group(1)
        self.assertNotEqual(tuple(int(x) for x in ink.split(',')), (128, 128, 128))


class TheEditor(unittest.TestCase):
    """The editor gives its widget the labels' colour as its own, when the
    Inspector makes it."""

    def setUp(self):
        self.behavior = read(*EDITORS, 'com.livecode.pi.navbar.behavior.livecodescript')

    def test_the_editor_gives_its_widget_the_labels_black(self):
        ink = re.search(r'^constant kSheetInk = "([^"]+)"', self.behavior, re.M)
        self.assertIsNotNone(ink, 'the editor names no colour for its icons')
        self.assertEqual(ink.group(1), '0,0,0')
        init = handler(self.behavior, 'on', 'editorInitialize')
        self.assertIn('set the editMode of widget 1 of me to true', init)
        self.assertIn('set the foregroundColor of widget 1 of me to kSheetInk', init)
        # nothing else of the editor touches the widget's colours
        self.assertEqual(len(re.findall(r'(?i)(?:fore|foreground|hilite|back|background|border)Color', self.behavior)), 1)

    def test_the_colour_is_the_labels_on_the_sheet(self):
        source = read('extensions', 'widgets', 'navbar', 'navbar.lcb')
        ink = tuple(int(x) for x in re.search(r'^constant kSheetInk = "([^"]+)"', self.behavior, re.M).group(1).split(','))
        self.assertEqual(ink, sheet_paint(source, 'text', 'editmode-fill'))
        self.assertNotEqual(ink, sheet_paint(source, 'background', 'editmode-fill'))

    def test_the_inspector_initializes_an_editor_it_makes(self):
        group = read('ide', 'Toolset', 'palettes', 'inspector', 'behaviors', 'revinspectorgroupbehavior.livecodescript')
        made = group[group.index('copy group "template" of stack tEditor to me'):]
        self.assertIn('dispatch "editorInitialize" to tGroupLongID', made[:made.index('else')])
        self.assertIn('metadata itemArray.editor is "com.livecode.pi.navbar"',
                      read('extensions', 'widgets', 'navbar', 'navbar.lcb'))


class WhereTheIconIs(unittest.TestCase):
    """The engine's test and the tour read an icon's rect where the widget's
    edit mode draws it: 30 points square, 145 points in from the widget's
    right (the highlighted icon 95), 10 down its row of 50."""

    def setUp(self):
        self.source = read('extensions', 'widgets', 'navbar', 'navbar.lcb')
        self.line = int(re.search(r'^constant kEditModeLineHeight is (\d+)', self.source, re.M).group(1))
        self.pad = int(re.search(r'^constant kEditModePaddingUnit is (\d+)', self.source, re.M).group(1))

    def test_the_widgets_rects(self):
        rects = lcb_handler(self.source, 'calculateEditModeIconRects')
        self.assertIn('put mWidth - (4 * kEditModePaddingUnit + 5 * tLineHeight / 2) into tLabelRight', rects)
        self.assertIn('put tLabelRight + kEditModePaddingUnit into tLeft', rects)
        rect = ('put rectangle [tLeft + kEditModePaddingUnit, tLineTop + kEditModePaddingUnit, '
                'tLeft + tLineHeight - kEditModePaddingUnit, tLineBottom - kEditModePaddingUnit] into tIconRect')
        self.assertEqual(rects.count(rect), 2)
        between = rects[rects.index(rect) + len(rect):rects.rindex(rect)]
        self.assertIn('add tLineHeight to tLeft', between)
        self.assertEqual((self.line, self.pad), (50, 10))
        # from the widget's right to the icon's left, the icon's size, and
        # the highlighted icon's left
        left = 4 * self.pad + 5 * self.line // 2 - 2 * self.pad
        self.assertEqual((left, self.line - 2 * self.pad, left - self.line), (145, 30, 95))

    def test_the_engines_test_reads_them(self):
        test = read('tests', 'lcs', 'inspector', 'navbar.livecodescript')
        rect = handler(test, 'private function', 'iconRect')
        self.assertIn('put the width of pWidget - 145 into tLeft', rect)
        self.assertIn('if pHilited is true then add 50 to tLeft', rect)
        self.assertIn('put (pRow - 1) * 50 + 10 into tTop', rect)
        self.assertIn('return tLeft & comma & tTop & comma & (tLeft + 30) & comma & (tTop + 30)', rect)

    def test_the_tour_reads_them(self):
        tour = read('tools', 'ci', 'ui-tour.livecodescript')
        icon = handler(tour, 'function', 'tourNbIcon')
        self.assertIn('put item 1 of tStack + item 3 of tRect - 145 into tLeft', icon)
        self.assertIn('put item 2 of tStack + item 2 of tRect + (pRow - 1) * 50 + 10 into tTop', icon)
        self.assertIn('export snapshot from rect (tLeft, tTop, tLeft + 30, tTop + 30) to tData as PNG', icon)


class TheTests(unittest.TestCase):
    """The engine's test makes the editor as the Inspector does and fails
    without the editor's colour; the tour reads the real Inspector."""

    def test_the_engines_test_makes_the_editor_as_the_inspector_does(self):
        test = read('tests', 'lcs', 'inspector', 'navbar.livecodescript')
        setup = handler(test, 'on', 'TestSetup')
        # the Inspector is the IDE's: not in a standalone (Android, the web)
        self.assertIn('TestSkipIfNot "ide"', setup)
        self.assertIn('TestLoadExtension "com.livecode.widget.navbar"', setup)
        for name in ('behaviors/revinspectoreditorbehavior.livecodescript',
                     'editors/com.livecode.pi.navbar.behavior.livecodescript',
                     'editors/com.livecode.pi.navbar.livecode'):
            self.assertIn('TestGetIDERepositoryPath() & "/Toolset/palettes/inspector/%s"' % name, setup)
            self.assertTrue(os.path.isfile(os.path.join(REPO, 'ide', 'Toolset', 'palettes', 'inspector', name)), name)
        make = handler(test, 'private function', 'makeEditor')
        self.assertIn('copy group "template" of stack kEditor to card 1 of stack kStack', make)
        self.assertIn('dispatch "editorInitialize" to tEditor', make)
        self.assertIn('dispatch "editorUpdate" to tEditor', make)
        # the test gives the widget no colour itself
        self.assertNotIn('foregroundColor', make)

    def test_the_engines_test_fails_without_the_editors_colour(self):
        test = read('tests', 'lcs', 'inspector', 'navbar.livecodescript')
        dark = handler(test, 'on', 'TestTheIconsShowOnTheSheetInADarkInspector')
        self.assertIn('set the foregroundColor of stack kStack to "255,255,255"', dark)
        self.assertIn('the foregroundColor of tWidget is "0,0,0"', dark)
        self.assertIn('item 1 of tShown >= kSeen', dark)
        # and it shows the report: with the colour taken off, nothing of
        # the icon is on the sheet
        off = dark[dark.index('set the foregroundColor of tWidget to empty'):]
        self.assertIn('tShown is "0,0"', off)
        light = handler(test, 'on', 'TestTheIconsAreAsBeforeInALightInspector')
        self.assertIn('set the foregroundColor of stack kStack to "0,0,0"', light)
        self.assertIn('tBefore is tShown[tRow]', light)

    def test_the_tour_reads_the_inspector_on_the_screen(self):
        tour = read('tools', 'ci', 'ui-tour.livecodescript')
        steps = re.search(r'^constant kSteps = "([^"]+)"', tour, re.M).group(1).split(',')
        self.assertEqual(steps.index('inspector-navbar'), steps.index('inspector-button-menu') + 1)
        step = handler(tour, 'on', 'tour_inspector_navbar')
        self.assertIn('put tourNbMake(tCard) into tNav', step)
        self.assertIn('revIDECreateObject "com.livecode.widget.navbar", pCard',
                      handler(tour, 'function', 'tourNbMake'))
        self.assertIn('put tourInspectorEditor(tPI, "itemArray") into tEditor', step)
        self.assertIn('if item 1 of tShown < 40 then', step)
        self.assertIn('if tRead is 0 then put "no row of the editor is on the screen"', step)
        self.assertIn('tourShotStack tPI, "08-inspector-navbar-items"', step)
        # the look as it was is logged, after the snapshot, and the colour
        # put back
        after = step[step.index('tourShotStack tPI'):]
        self.assertLess(after.index('set the foregroundColor of tWidget to empty'),
                        after.index('set the foregroundColor of tWidget to "0,0,0"'))
        self.assertIn('if tFails is not empty then throw', step)


if __name__ == '__main__':
    unittest.main()
