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

"""The words of an older stack's fields and buttons in the dark appearance
(engine/src/object.cpp, MCObject::getlegacywords and getwordsbackcolor).

A stack made before there was a dark appearance sets the backgroundColor of
a field, a button, a group or a card to a light colour and leaves its words
to the engine, which drew them black in LiveCode Community. In the dark
appearance the theme gives words with no colour of their own white, so up
to 0.2.8-dp.2 they were white on that light colour: a field with a white
background of its own showed white words on white (0.2.8-dp.1 on seth's
Windows 11 PC, 2026-11-21, the xTalk Suite's xlsxt and pdfxt demos; the
effective foregroundColor of such a field was 255,255,255).

The engine now draws the words of a field or button that take the theme's
colour black, as LiveCode Community did, when in the dark appearance that
colour is light and the colour they are drawn on is light too; everything
else is as before: the light appearance, a dark colour, words with a colour
of their own or one they inherit, selected and disabled words, menus, and a
stack with no colours at all. The effective foregroundColor reads the colour
the words are drawn in. The dark switch check (tools/ci/dark_switch_check.py,
LEGACY) measures it on Windows in both appearances; what it measures failed
with 0.2.8-dp.1 on seth's PC.

  python3 -m unittest discover -s tools/ci/tests
"""

import math
import os
import re
import unittest

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))


def read(*parts):
    with open(os.path.join(REPO, *parts), encoding='utf-8') as f:
        return f.read()


def c_function(text, name):
    """The definition of a C function, its parameters on one line or more."""
    m = re.search(r'^[^\n;]*\b%s\([^;{]*?\)\s*\n\{.*?^\}' % re.escape(name), text, re.M | re.S)
    if m is None:
        raise AssertionError('no function %s' % name)
    return m.group(0)


def c_expression(text):
    """A C expression of bit tests, comparisons, &&, || and ! as Python. &
    binds tighter than && and || in C as it does than and/or in Python; a
    bit test meeting == or != without brackets would read differently, and
    the expressions read here have none."""
    text = re.sub(r'\s+', ' ', text).strip()
    text = text.replace('&&', ' and ').replace('||', ' or ')
    text = re.sub(r'!(?!=)', ' not ', text)
    return compile(text, '<c>', 'eval')


def the_expression(source, assignment):
    """The expression assigned in `<assignment> = <expression>;`."""
    m = re.search(r'%s = (.*?);' % re.escape(assignment), source, re.S)
    if m is None:
        raise AssertionError('no %s' % assignment)
    return m.group(1)


# Distinct values for the engine's constants (engine/src/objdefs.h): only
# whether a bit is there, or which value a word has, matters here
BITS = ('CS_HILITED', 'CS_ARMED', 'CS_KFOCUSED', 'CS_SUBMENU')
FLAGS = ('F_HILITE_FILL', 'F_ARM_FILL', 'F_SHOW_BORDER', 'F_SHOW_ICON', 'F_AUTO_ARM', 'F_3D', 'F_F_AUTO_ARM')
CONSTANTS = dict({name: 1 << n for n, name in enumerate(BITS)},
                 **{name: 1 << n for n, name in enumerate(FLAGS)})
CONSTANTS.update(F_STANDARD=0, F_ROUNDRECT=1, F_CHECK=3, F_RADIO=4, F_MENU=5, F_OVAL_BUTTON=6, F_RECTANGLE=7,
                 LF_MOTIF=0, LF_MAC=1, LF_WIN95=2, WM_OPTION=10, WM_COMBO=11, WM_PULLDOWN=12)
# the styles of the buttons getlegacywords gives words to: not a menu
STYLES = ('F_STANDARD', 'F_ROUNDRECT', 'F_CHECK', 'F_RADIO', 'F_OVAL_BUTTON', 'F_RECTANGLE')
LOOKS = ('LF_MOTIF', 'LF_MAC', 'LF_WIN95')


def every_state():
    """Every state, flags, look and style of a button that is not a menu."""
    for state in range(1 << len(BITS)):
        for flags in range(1 << len(FLAGS)):
            for look in LOOKS:
                for style in STYLES:
                    yield dict(CONSTANTS, state=state, flags=flags, MClook=CONSTANTS[look],
                               style=CONSTANTS[style], t_style=CONSTANTS[style])


def luminance(rgb):
    """The WCAG's relative luminance of an 8-bit colour, as
    MCObjectColorLuminance reckons it from the engine's 16-bit one."""
    out = []
    for c in rgb:
        v = c * 257 / 65535.0
        out.append(v / 12.92 if v <= 0.03928 else ((v + 0.055) / 1.055) ** 2.4)
    return 0.2126 * out[0] + 0.7152 * out[1] + 0.0722 * out[2]


def contrast(a, b):
    la, lb = luminance(a), luminance(b)
    return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)


def is_light(rgb):
    """MCObjectColorIsLight."""
    return luminance(rgb) > 0.179129


def words(appearance, theme_words, back, own_back=True):
    """The model of getlegacywords: the colour words that take the theme's
    are drawn in, on `back` (None: what they are drawn on cannot be told);
    own_back, whether anything from the control up to its stack has a
    background colour or pattern of its own."""
    if appearance != 'dark' or not is_light(theme_words):
        return theme_words
    if not own_back:
        return theme_words
    if back is None or not is_light(back):
        return theme_words
    return (0, 0, 0)


WHITE, BLACK = (255, 255, 255), (0, 0, 0)
# Windows' dark mode (engine/src/windows-theme.cpp): white words, and a
# background of 32,32,32 for a field, a button and a window
DARK_THEME_WORDS, DARK_THEME_BACK = WHITE, (32, 32, 32)
# Windows' accent, its hilite colour by default
ACCENT = (0, 120, 215)


class TheRule(unittest.TestCase):
    def test_light_is_where_black_reads_better_than_white(self):
        # the luminance at which black and white have the same contrast
        self.assertAlmostEqual(math.sqrt(1.05 * 0.05) - 0.05, 0.179129, places=6)
        for grey in range(256):
            rgb = (grey, grey, grey)
            self.assertEqual(is_light(rgb), contrast(BLACK, rgb) > contrast(WHITE, rgb), rgb)

    def test_the_colours_of_seths_pc(self):
        # a field with a white background of its own: black, as LiveCode
        # Community drew it; it was white on white
        self.assertEqual(words('dark', DARK_THEME_WORDS, WHITE), BLACK)
        # the UI kit's card and a light panel
        self.assertEqual(words('dark', DARK_THEME_WORDS, (240, 242, 246)), BLACK)
        self.assertEqual(words('dark', DARK_THEME_WORDS, (225, 229, 236)), BLACK)

    def test_what_stays_as_it_was(self):
        # a stack with no colours: the dark appearance's own
        self.assertEqual(words('dark', DARK_THEME_WORDS, DARK_THEME_BACK), WHITE)
        # and so it is if a theme gave such a stack a light background (no
        # theme is asked: nothing from the control up has a colour)
        self.assertEqual(words('dark', DARK_THEME_WORDS, WHITE, own_back=False), WHITE)
        # a dark colour of the stack's own
        self.assertEqual(words('dark', DARK_THEME_WORDS, (40, 48, 64)), WHITE)
        # what the words are on cannot be told
        self.assertEqual(words('dark', DARK_THEME_WORDS, None), WHITE)
        # the light appearance, whatever the colour
        for back in (WHITE, (40, 48, 64), None):
            self.assertEqual(words('light', BLACK, back), BLACK)
        # a theme whose words are dark already
        self.assertEqual(words('dark', (20, 20, 20), WHITE), (20, 20, 20))

    def test_the_accent_is_light(self):
        # why a button's fill reversed to the hilite colour is left out
        # (getwordsbackcolor): Windows' accent counts as light, and a stack
        # with no colours at all would have had black words on it while a
        # button was pressed
        self.assertTrue(is_light(ACCENT))
        self.assertLess(contrast(BLACK, ACCENT) - contrast(WHITE, ACCENT), 0.2)


class TheEngine(unittest.TestCase):
    def setUp(self):
        self.source = read('engine', 'src', 'object.cpp')
        self.legacy = c_function(self.source, 'MCObject::getlegacywords')
        self.back = c_function(self.source, 'MCObject::getwordsbackcolor')
        self.fore = c_function(self.source, 'MCObject::getforecolor')

    def test_declared_on_the_object(self):
        header = read('engine', 'src', 'object.h')
        self.assertIn('void getlegacywords(uint2 p_di, MCContextType p_type, MCColor &x_words);', header)
        self.assertIn('bool getwordsbackcolor(MCContextType p_type, MCColor &r_back);', header)

    def test_light_by_the_wcag_contrast(self):
        light = c_function(self.source, 'MCObjectColorIsLight')
        self.assertIn('return MCObjectColorLuminance(p_color) > 0.179129;', light)
        self.assertTrue(light.startswith('static bool MCObjectColorIsLight(const MCColor &p_color)'))

    def test_only_the_words_of_a_field_or_a_button(self):
        self.assertIn('if (p_di != DI_FORE && p_di != DI_PSEUDO_TEXT_COLOR && p_di != DI_PSEUDO_BUTTON_TEXT)\n'
                      '\t\treturn;', self.legacy)
        # not the list a menu shows, nor a field in a button (a combo box's)
        self.assertIn('if (getstate(CS_MENUFIELD) || !parent.IsValid() || parent -> gettype() == CT_BUTTON)\n'
                      '\t\t\treturn;', self.legacy)
        # not a menu, a menu's item, or a tab panel
        self.assertIn('if (getstyleint(flags) == F_MENU || static_cast<MCButton *>(this) -> getmenucontrol() '
                      '!= MENUCONTROL_NONE)\n\t\t\treturn;', self.legacy)
        self.assertIn('\telse\n\t\treturn;', self.legacy)

    def test_black_only_for_light_words_on_a_light_colour_in_the_dark_appearance(self):
        body = self.legacy
        light_words = body.index('if (!MCObjectColorIsLight(x_words))\n\t\treturn;')
        back = body.index('if (!getwordsbackcolor(p_type, t_back) || !MCObjectColorIsLight(t_back))\n\t\treturn;')
        dark = body.index('if (t_appearance != kMCSystemAppearanceDark)\n\t\treturn;')
        black = body.index('x_words = MCscreen -> getblack();')
        self.assertLess(max(light_words, back, dark), black)
        self.assertIn('MCscreen -> getsystemappearance(t_appearance);', body)
        # nothing else is written
        self.assertEqual(body.count('x_words ='), 1)

    def test_a_stack_with_no_background_colour_keeps_the_theme_words(self):
        # nothing from the control up to its stack has a background colour
        # or pattern: the words are the theme's before getwordsbackcolor or
        # the appearance is asked, the way a stack with no colours is drawn
        # whatever its theme's backgrounds are
        body = self.legacy
        walk = body.index('for (MCObject *t_object = this; t_object != nil && t_object != MCdispatcher; '
                          't_object = t_object -> getparent())')
        own = body.index('if (t_object -> getcindex(DI_BACK, t_index) || t_object -> getpindex(DI_BACK, t_index))')
        early = body.index('if (!t_own_back)\n\t\treturn;')
        self.assertLess(walk, own)
        self.assertLess(own, early)
        self.assertLess(early, body.index('getwordsbackcolor(p_type, t_back)'))
        self.assertLess(early, body.index('getsystemappearance(t_appearance)'))
        self.assertEqual(body.count('t_own_back = true;'), 1)
        # the walk is the chain getforecolor inherits along, which stops
        # at the dispatcher too (the Mac's stops at the stack: the walk
        # then asks more often, never less)
        self.assertIn('if (parent && parent != MCdispatcher)\n', self.fore)

    def test_getforecolor_asks_after_every_colour_of_the_users_own(self):
        # its own colour or pattern, the disabled grey, and every colour or
        # pattern it inherits are found before the theme's
        inherit = self.fore.index('return parent->getforecolor(p_di, rev, hilite, c, r_pattern, x, y, dc_type, o, selected);')
        theme = self.fore.index('if (which == P_FORE_COLOR && !selected && !rev)\n'
                                '                o -> getlegacywords(p_di, dc_type, c);')
        end = self.fore.index('if (di == DI_FORE && !rev && !selected)\n'
                              '\t\to -> getlegacywords(p_di, dc_type, c);\n\treturn True;\n}')
        self.assertLess(inherit, theme)
        self.assertLess(theme, end)
        self.assertEqual(self.fore.count('getlegacywords('), 2)
        # the theme's colour, as it is returned
        self.assertIn('if (MCPlatformGetControlThemePropColor(t_control_type, t_control_part, t_control_state, '
                      't_theme_prop, c))\n        {\n            // OXT-Beyond', self.fore)

    def test_the_effective_foregroundColor_is_the_colour_drawn(self):
        source = read('engine', 'src', 'exec-interface-object.cpp')
        get = c_function(source, 'MCObject::GetColor')
        self.assertIn('if (MCPlatformGetControlThemePropColor(t_control_type, t_control_part, t_control_state, '
                      't_control_prop, t_color))\n                {', get)
        call = 'if (which == P_FORE_COLOR)\n                        getlegacywords(DI_FORE, CONTEXT_TYPE_SCREEN, t_color);'
        self.assertIn(call, get)
        self.assertLess(get.index(call), get.index('r_color.color = t_color;'))
        # only where nothing up to the stack has a colour of its own
        self.assertLess(get.index('t_found = parent -> GetColor(ctxt, which, effective, r_color, true);'),
                        get.index(call))

    def test_a_fields_fill_as_the_field_draws_it(self):
        fieldf = read('engine', 'src', 'fieldf.cpp')
        draw = c_function(fieldf, 'MCField::drawrect')
        fill = c_expression(re.search(r'setforeground\(dc, DI_BACK, False, ([^;]*)\);', draw).group(1))
        mine = c_expression(the_expression(self.back, 'Boolean t_hilite'))
        for env in every_state():
            self.assertEqual(bool(eval(fill, env)), bool(eval(mine, env)), env)
        self.assertIn('return getforecolor(DI_BACK, False, t_hilite, r_back, t_pattern, t_x, t_y, p_type, this) '
                      '&& t_pattern == nil;', self.back)

    def test_a_buttons_fill_as_the_button_draws_it(self):
        # MCButton::draw's t_fill_rev and t_fill_hilite, and the loff,
        # white and indicator they are made of, against getwordsbackcolor's,
        # for every state of a button that is not a menu (so macoption, a
        # Mac option menu, is false)
        draw = c_function(read('engine', 'src', 'buttondraw.cpp'), 'MCButton::draw')
        at = draw.index('loff = 1;')
        draw_loff = c_expression(draw[draw.rindex('if (', 0, at) + 2:at])
        draw_indicator = c_expression(the_expression(draw, 'Boolean indicator').replace('getstyleint(flags)', 'style'))
        draw_white = c_expression(the_expression(draw, 'Boolean white'))
        draw_rev = c_expression(the_expression(draw, 'bool t_fill_rev'))
        draw_hilite = c_expression(the_expression(draw, 'bool t_fill_hilite'))
        my_indicator = c_expression(the_expression(self.back, 'bool t_indicator'))
        my_loff = c_expression(the_expression(self.back, 'bool t_loff'))
        my_white = c_expression(the_expression(self.back, 'bool t_white'))
        my_rev = c_expression(the_expression(self.back, 'bool t_fill_rev'))
        my_hilite = c_expression(the_expression(self.back, 'bool t_fill_hilite'))
        reversed_states = 0
        for env in every_state():
            env.update(macoption=False, t_isvista=False, menumode=CONSTANTS['WM_PULLDOWN'])
            env['indicator'] = bool(eval(draw_indicator, env))
            env['loff'] = 1 if eval(draw_loff, env) else 0
            env['white'] = bool(eval(draw_white, env))
            env['t_indicator'] = bool(eval(my_indicator, env))
            env['t_loff'] = bool(eval(my_loff, env))
            env['t_white'] = bool(eval(my_white, env))
            self.assertEqual(env['t_indicator'], env['indicator'])
            self.assertEqual(env['t_loff'], env['loff'] == 1, env)
            self.assertEqual(env['t_white'], env['white'], env)
            rev = bool(eval(draw_rev, env))
            self.assertEqual(bool(eval(my_rev, env)), rev, env)
            self.assertEqual(bool(eval(my_hilite, env)), bool(eval(draw_hilite, env)), env)
            reversed_states += rev
        # (both ways happen)
        self.assertGreater(reversed_states, 0)

    def test_a_checked_check_box_is_not_reversed(self):
        # the dark switch check's Tick: checked, filled, no icon, on Windows
        back = self.back
        env = dict(CONSTANTS, state=CONSTANTS['CS_HILITED'],
                   flags=CONSTANTS['F_HILITE_FILL'] | CONSTANTS['F_SHOW_BORDER'] | CONSTANTS['F_3D'],
                   MClook=CONSTANTS['LF_WIN95'], t_style=CONSTANTS['F_CHECK'])
        env['t_indicator'] = bool(eval(c_expression(the_expression(back, 'bool t_indicator')), env))
        env['t_loff'] = bool(eval(c_expression(the_expression(back, 'bool t_loff')), env))
        env['t_white'] = bool(eval(c_expression(the_expression(back, 'bool t_white')), env))
        self.assertFalse(eval(c_expression(the_expression(back, 'bool t_fill_rev')), env))
        # and a pressed rectangle button is
        env.update(t_style=CONSTANTS['F_RECTANGLE'], t_indicator=False)
        self.assertTrue(eval(c_expression(the_expression(back, 'bool t_fill_rev')), env))

    def test_a_buttons_fill_that_cannot_be_told_keeps_the_words(self):
        # the theme's face of a push button with no colour of its own
        self.assertIn('if (standardbtn() && !getcindex(DI_BACK, i) && !getpindex(DI_BACK, i))\n\t\t\t\treturn false;',
                      self.back)
        # a fill reversed to the hilite colour
        self.assertIn('if (t_fill_rev)\n\t\t\t\treturn false;', self.back)
        # the web theme's face, as the draw takes it
        self.assertIn('if (!t_fill_hilite && static_cast<MCButton *>(this) -> getwebthemeface(p_type, r_back))\n'
                      '\t\t\t\treturn true;', self.back)
        self.assertIn('return getforecolor(DI_BACK, False, t_fill_hilite, r_back, t_pattern, t_x, t_y, p_type, this) '
                      '&& t_pattern == nil;', self.back)
        # a pattern cannot be told, wherever it is
        self.assertEqual(self.back.count('&& t_pattern == nil;'), 4)

    def test_a_transparent_control_is_on_its_group_or_card(self):
        loop = self.back[self.back.index('for (MCObject *t_object = parent;'):]
        # a menu bar's group is the theme's
        self.assertIn('t_object -> hasname(t_object -> getstack() -> getmenubar()))\n\t\t\t\treturn false;', loop)
        # a group that fills nothing is passed over, and so is one whose
        # frame the theme draws (MCGroup::draw)
        self.assertIn('if (!(t_flags & F_OPAQUE))\n\t\t\t\tcontinue;', loop)
        self.assertIn('MCcurtheme -> iswidgetsupported(WTHEME_TYPE_GROUP_FRAME))\n\t\t\t\tcontinue;', loop)
        group = c_function(read('engine', 'src', 'group.cpp'), 'MCGroup::draw')
        self.assertIn('MCcurtheme->iswidgetsupported(WTHEME_TYPE_GROUP_FRAME) )', group)
        # the card as it fills its background (MCCard::drawbackground)
        card = c_function(read('engine', 'src', 'card.cpp'), 'MCCard::drawbackground')
        self.assertIn('t_hilite = MClook == LF_WIN95 && (wm == WM_COMBO || wm == WM_OPTION);', card)
        self.assertIn('Boolean t_hilite = MClook == LF_WIN95 && (t_mode == WM_COMBO || t_mode == WM_OPTION);', loop)
        # anything else (not on a card) cannot be told
        self.assertTrue(loop.rstrip().endswith('\t\treturn false;\n\t}\n\treturn false;\n}'))


class TheCheck(unittest.TestCase):
    def test_the_dark_switch_check_measures_it(self):
        # (tools/ci/tests/test_dark_switch_check.py tests the check itself)
        script = read('tools', 'ci', 'dark-switch-check.livecodescript')
        self.assertIn("LEGACY = ('Paper', 'Label', 'Key', 'Tick')", read('tools', 'ci', 'dark_switch_check.py'))
        self.assertIn('set the backgroundColor of field "Paper" to "255,255,255"', script)
        self.assertIn('set the hilite of button "Tick" to true', script)
        # the build's own package is checked in both appearances
        self.assertIn('getlegacywords', read('.github', 'workflows', 'build-windows.yml'))


if __name__ == '__main__':
    unittest.main()
