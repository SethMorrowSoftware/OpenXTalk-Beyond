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

"""The words of a menu's items on a window's own colour, on Linux, where the
engine draws its menus (engine/src/buttondraw.cpp,
MCButtonMenuItemTextInkOnOwnColour).

A menu takes the first background colour from its button up, so a window's
colour of its own reaches its menus. Until 0.2.7-rc.6.16 the items' words
were the theme's text colour whatever that colour was: in a window of
236,236,236 under Adwaita-dark they were its #eeeeec, 2 in luma from the
menu, and in a window of 48,52,58 under Adwaita its #2e3436, 2 in luma
again. The engine now draws them black or white by the colour behind them,
as it draws the item's tick, when the theme's text and that colour are both
dark or both light; nothing else changes. The tour's menu-words step
(tools/ci/ui-tour.livecodescript) measures it on the screen; it failed on
the released rc.6.15 in both appearances.

  python3 -m unittest discover -s tools/ci/tests
"""

import os
import re
import unittest

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))


def read(*parts):
    with open(os.path.join(REPO, *parts), encoding='utf-8') as f:
        return f.read()


def c_function(text, name):
    m = re.search(r'^[^\n;]*\b%s\([^\n;]*\n\{.*?^\}' % re.escape(name), text, re.M | re.S)
    if m is None:
        raise AssertionError('no function %s' % name)
    return m.group(0)


def luma(rgb):
    """Rec. 601 luma out of 65535 of an 8-bit colour, as the engine reckons
    it from its 16-bit one (a byte b is b * 257 there)."""
    r, g, b = (c * 257 for c in rgb)
    return (299 * r + 587 * g + 114 * b) // 1000


def ink(back, fore):
    """The model of the engine's choice for an item with no text colour of
    its own and a background colour of its own: None keeps the theme's."""
    dark_back = luma(back) < 32768
    if dark_back != (luma(fore) < 32768):
        return None
    return (255, 255, 255) if dark_back else (0, 0, 0)


class TheInk(unittest.TestCase):
    def setUp(self):
        self.source = read('engine', 'src', 'buttondraw.cpp')
        self.ink = c_function(self.source, 'MCButtonMenuItemTextInkOnOwnColour')

    def test_only_a_menu_item(self):
        self.assertIn('if (p_item -> getmenucontrol() != MENUCONTROL_ITEM)\n\t\treturn false;', self.ink)

    def test_a_colour_of_the_users_own_on_the_way(self):
        # the way getforecolor goes, item to the dispatcher
        self.assertIn('t_object != MCdispatcher; t_object = t_object -> getparent()', self.ink)
        # a text colour or pattern of the user's keeps the words
        self.assertIn('if (t_object -> getcindex(DI_FORE, t_index) || t_object -> getpindex(DI_FORE, t_index))\n'
                      '\t\t\treturn false;', self.ink)
        # the theme's background keeps them (a menu without a colour of
        # its own does not change), and so does a pattern
        self.assertIn('if (!t_own_back)\n\t\treturn false;', self.ink)
        self.assertIn('if (t_object -> getpindex(DI_BACK, t_index) && !t_object -> getcindex(DI_BACK, t_index))\n'
                      '\t\t\t\treturn false;', self.ink)
        self.assertEqual(self.ink.count('t_pattern != nil)\n\t\treturn false;'), 2)

    def test_black_or_white_only_when_the_theme_cannot_be_read(self):
        self.assertIn('if (t_dark_back != (t_fore_luma < 32768))\n\t\treturn false;', self.ink)
        self.assertIn('r_ink = t_dark_back ? p_dc -> getwhite() : p_dc -> getblack();', self.ink)

    def test_linux_only(self):
        # declared and defined only on Linux, beside the tick's
        at = self.source.index('static bool MCButtonMenuItemTextInkOnOwnColour(MCButton *p_item, MCDC *p_dc, MCColor &r_ink)\n{')
        before = self.source[:at]
        self.assertGreater(before.rindex('#if defined(TARGET_PLATFORM_LINUX)'), before.rindex('#endif'))
        decl = self.source.index('static bool MCButtonMenuItemTextInkOnOwnColour(MCButton *p_item, MCDC *p_dc, MCColor &r_ink);')
        self.assertTrue(self.source[:decl].rstrip().endswith('#if defined(TARGET_PLATFORM_LINUX)'))

    def test_the_label_uses_it(self):
        draw = c_function(self.source, 'MCButton::draw')
        call = ('MCColor t_ink;\n'
                '\t\t\t\tif (MCButtonMenuItemTextInkOnOwnColour(this, dc, t_ink))\n'
                '\t\t\t\t{\n'
                '\t\t\t\t\tdc->setforeground(t_ink);')
        self.assertIn(call, draw)
        # after the words' usual colour, in its branch: not for an armed
        # item, whose words stay the theme's on the theme's hilite
        at = draw.index(call)
        usual = draw.rindex('setforeground(dc, DI_FORE, ((state & CS_HILITED && flags & F_HILITE_FILL)', 0, at)
        armed = draw.rindex('setforeground(dc, DI_PSEUDO_BUTTON_TEXT_SEL, False, True);', 0, at)
        self.assertLess(armed, usual)
        self.assertNotIn('\n\t\t\t}\n', draw[usual:at])
        self.assertTrue(draw[:at].rstrip().endswith('(MCButtonMenuItemTextInkOnOwnColour)'))
        self.assertIn('#if defined(TARGET_PLATFORM_LINUX)', draw[usual:at])


class TheChoice(unittest.TestCase):
    """The colours of the tour's menu-words step."""

    ADWAITA_DARK_TEXT = (0xee, 0xee, 0xec)
    ADWAITA_TEXT = (0x2e, 0x34, 0x36)

    def test_the_two_that_could_not_be_read(self):
        self.assertEqual(ink((236, 236, 236), self.ADWAITA_DARK_TEXT), (0, 0, 0))
        self.assertEqual(ink((48, 52, 58), self.ADWAITA_TEXT), (255, 255, 255))

    def test_the_theme_where_it_can_be_read(self):
        self.assertIsNone(ink((48, 52, 58), self.ADWAITA_DARK_TEXT))
        self.assertIsNone(ink((236, 236, 236), self.ADWAITA_TEXT))

    def test_the_tick_agrees(self):
        # the tick is white when the colour is dark (luma under half), and
        # so are the words when they change
        for back in ((48, 52, 58), (236, 236, 236), (127, 127, 127), (128, 128, 128)):
            for fore in ((0, 0, 0), (255, 255, 255)):
                chosen = ink(back, fore)
                if chosen is not None:
                    self.assertEqual(chosen == (255, 255, 255), luma(back) < 32768)


class TheTour(unittest.TestCase):
    def test_the_step_measures_it(self):
        tour = read('tools', 'ci', 'ui-tour.livecodescript')
        self.assertIn('on tour_menu_words', tour)
        self.assertIn('MCButtonMenuItemTextInkOnOwnColour', read('.github', 'workflows', 'build-linux.yml'))


if __name__ == '__main__':
    unittest.main()
