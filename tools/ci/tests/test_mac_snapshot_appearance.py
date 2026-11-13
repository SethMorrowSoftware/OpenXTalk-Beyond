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

"""A Mac button's snapshot in the dark appearance (queued for 0.2.8 in the
0.2.7 release post; the IDE tour's background-default step).

engine/src/osxtheme.mm draws a push button (and a checkbox, radio button,
option menu, combo box) by drawing an AppKit control's cell into an image
with no view. Such a cell draws in the CURRENT DRAWING appearance, not the
one set on its control. Inside a window's drawing that is the window's, so
the screen was right; outside one, as for `import snapshot from button`,
0.2.7 drew in the light appearance in the dark: an opaque white face under
the dark appearance's light label (seen on macOS 15: 255,255,255 at alpha
255; AppKit asked for the dark appearance draws white at alpha 64, which on
the dark card, 37,37,37, is the screen's 91,91,91). The cell is now drawn
with the appearance it is meant to have as the current one.

Printing keeps the light appearance: a button drawn for a printer
(CONTEXT_TYPE_PRINTER, whose marks are played back later) is drawn as the
light appearance shows it, as the printer's labels are (MCObject::
getforecolor leaves the dark colours out of printing).

The IDE tour's background-default step measures it on the Mac. This test
reads the source, so every platform's checks hold the rule.

  python3 -m unittest discover -s tools/ci/tests
"""

import os
import unittest

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))


def read(*parts):
    with open(os.path.join(REPO, *parts), encoding='utf-8') as f:
        return f.read()


class TheCellIsDrawnInItsAppearance(unittest.TestCase):

    def setUp(self):
        self.src = read('engine', 'src', 'osxtheme.mm')

    def test_helper_makes_the_appearance_current(self):
        src = self.src
        helper = src[src.index('static void MCMacThemeDrawInAppearance('):]
        helper = helper[:helper.index('\n}\n')]
        self.assertIn('[p_appearance performAsCurrentDrawingAppearance:p_draw];', helper)
        # before macOS 11: set, draw, and put the old one back
        self.assertIn('[NSAppearance setCurrentAppearance:p_appearance];', helper)
        self.assertIn('[NSAppearance setCurrentAppearance:t_old];', helper)
        self.assertLess(helper.index('setCurrentAppearance:p_appearance'), helper.index('setCurrentAppearance:t_old'))
        # defined before the theme drawing that uses it
        self.assertLess(src.index('static void MCMacThemeDrawInAppearance('),
                        src.index('void MCMacDrawTheme(MCThemeDrawType p_type'))

    def test_the_button_cell_is_drawn_inside_it(self):
        src = self.src
        draw = '[[t_control cell] drawWithFrame:t_draw_rect inView:nil];'
        self.assertEqual(src.count(draw), 1)
        at = src.index(draw)
        wrap = src.rindex('MCMacThemeDrawInAppearance(t_appearance, ^{', 0, at)
        self.assertLess(at - wrap, 80)
        # between the image's lockFocus and unlockFocus
        self.assertLess(src.rindex('[t_image lockFocus];', 0, at), wrap)
        self.assertLess(at, src.index('[t_image unlockFocus];', at))

    def test_printing_keeps_the_light_appearance(self):
        src = self.src
        appearance = src[src.index('NSAppearance *t_appearance = MCPlatformGetSystemAppearanceIsDark()'):]
        appearance = appearance[:appearance.index(';')]
        self.assertIn('&& !p_info.light_appearance', appearance)
        self.assertIn('[NSAppearance appearanceNamed:NSAppearanceNameDarkAqua]', appearance)
        self.assertIn('[NSAppearance appearanceNamed:NSAppearanceNameAqua]', appearance)
        button = src[src.index('static void drawthemebutton('):]
        button = button[:button.index('dc -> drawtheme(THEME_DRAW_TYPE_BUTTON, &t_info);')]
        self.assertIn('t_info . light_appearance = dc -> gettype() == CONTEXT_TYPE_PRINTER;', button)

    def test_the_flag_starts_false(self):
        # every other MCThemeDrawInfo (the scroll bars, sliders, tabs) is
        # made without it: it must start false, or one could draw light
        header = read('engine', 'src', 'osxtheme.h')
        info = header[header.index('struct MCThemeDrawInfo'):]
        info = info[:info.index('union')]
        self.assertIn('bool light_appearance = false;', info)
        # a printer's marks copy the whole struct, the flag with it
        self.assertIn('return sizeof(MCThemeDrawInfo);', self.src)


if __name__ == '__main__':
    unittest.main()
