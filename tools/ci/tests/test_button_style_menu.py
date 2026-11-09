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

"""The Inspector's Style menu offers "menu" (OpenXTalkPaul, openxtalk.org
p=26206). The style that makes a button a popup, pulldown or option menu
was missing from every button kind's list, so it could only be chosen by
script; and the menu kinds hid their Style row, so a button made a menu
could not be made a push button again from the Inspector. Every button
kind's row now offers menu, between shadow and checkbox as the dictionary
lists it, and the popup, pulldown and option menus show their row.

Nothing a stack holds changes: these files decide what the Inspector shows
and what a control made from the Tools palette starts as, and every
default (the style, the menuMode) is what it was. The IDE tour's
inspector-button-menu step makes each kind as the palette does, turns a
push button into a menu and back through revIDEPropertySet, and reads the
rows as the Inspector does; these tests hold the files and the step.

  python3 -m unittest discover -s tools/ci/tests
"""

import os
import re
import unittest

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
DEFS = ('ide', 'Toolset', 'resources', 'supporting_files', 'property_definitions')
TOUR = ('tools', 'ci', 'ui-tour.livecodescript')

STYLES = ['standard', 'transparent', 'opaque', 'rectangle', 'roundRect',
          'shadow', 'menu', 'checkbox', 'radioButton']

# Each button kind and the style it is made with (the Default column),
# which must not change: a control made from the Tools palette starts so
BUTTON_KINDS = {
    'Button': 'standard',
    'DefaultButton': 'standard',
    'RectangleButton': 'rectangle',
    'Checkbox': 'checkbox',
    'RadioButton': 'radiobutton',
    'OptionMenu': 'menu',
    'PopupMenu': 'menu',
    'PulldownMenu': 'menu',
}

MENU_MODES = {'OptionMenu': 'option', 'PopupMenu': 'popup', 'PulldownMenu': 'Pulldown'}


def read(*path):
    with open(os.path.join(REPO, *path), encoding='utf-8-sig') as f:
        return f.read()


def rows(kind):
    lines = read(*DEFS, 'com.livecode.interface.classic.%s.tsv' % kind).split('\n')
    header = lines[0].split('\t')
    data = lines[lines.index(next(l for l in lines if l.startswith('-----'))) + 1:]
    out = {}
    for line in data:
        cells = line.split('\t')
        if cells[0]:
            out[cells[0].split(':')[0]] = dict(zip(header[1:], cells[1:]))
    return header, out


class TheStyleRows(unittest.TestCase):
    def test_every_button_kind_offers_menu(self):
        for kind in BUTTON_KINDS:
            with self.subTest(kind=kind):
                _, props = rows(kind)
                self.assertEqual(props['style']['Options'].split(','), STYLES)

    def test_every_row_is_shown(self):
        for kind in BUTTON_KINDS:
            with self.subTest(kind=kind):
                _, props = rows(kind)
                self.assertNotEqual(props['style']['User Visible'], 'false')

    def test_the_defaults_are_as_they_were(self):
        for kind, style in BUTTON_KINDS.items():
            with self.subTest(kind=kind):
                _, props = rows(kind)
                self.assertEqual(props['style']['Default'], style)
        for kind, mode in MENU_MODES.items():
            with self.subTest(kind=kind):
                _, props = rows(kind)
                self.assertEqual(props['menuMode']['Default'], mode)

    def test_the_rows_keep_their_columns(self):
        for kind in BUTTON_KINDS:
            with self.subTest(kind=kind):
                header, _ = rows(kind)
                line = next(l for l in read(*DEFS, 'com.livecode.interface.classic.%s.tsv' % kind).split('\n')
                            if l.startswith('style\t'))
                self.assertEqual(len(line.split('\t')), len(header))

    def test_the_inspector_uses_an_enum(self):
        info = [l.split('\t') for l in read(*DEFS, 'propertyInfo.tsv').splitlines()]
        style = next(r for r in info if r[0] == 'style')
        self.assertEqual(style[1:5], ['Style', 'Basic', 'com.livecode.pi.enum', 'true'])


class TheTour(unittest.TestCase):
    def setUp(self):
        self.tour = read(*TOUR)

    def handler(self, kind, name):
        start = self.tour.index('\n%s %s' % (kind, name))
        return self.tour[start:self.tour.index('\nend %s\n' % name, start)]

    def test_the_step_runs(self):
        steps = re.search(r'^constant kSteps = "([^"]+)"', self.tour, re.M).group(1).split(',')
        self.assertIn('inspector-button-menu', steps)

    def test_what_it_does(self):
        step = self.handler('on', 'tour_inspector_button_menu')
        self.assertIn('"PopupMenu,popup" & return & "PulldownMenu,Pulldown" & return & "OptionMenu,option"', step)
        self.assertIn('revIDEPropertySet tButton, "style", "menu"', step)
        self.assertIn('revIDEPropertySet tButton, "style", "standard"', step)
        self.assertIn('tourInspectorEditor(tPI, "style") is empty', step)
        self.assertIn('if tFails is not empty then throw', step)

    def test_how_it_reads_the_row(self):
        check = self.handler('function', 'tourBmCheckRow')
        self.assertIn('revIDEPropertiesInfoOfSection(pButton, "Basic")', check)
        self.assertIn('if tRow["user_visible"] is false then', check)
        self.assertIn('if "menu" is not among the lines of tRow["options"] then', check)
        make = self.handler('function', 'tourBmMake')
        self.assertIn('revIDECreateObject "com.livecode.interface.classic." & pKind, pCard', make)


if __name__ == '__main__':
    unittest.main()
