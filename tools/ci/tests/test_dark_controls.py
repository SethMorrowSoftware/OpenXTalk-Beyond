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

"""The engine's drawing problems that the review of the IDE tour's
screenshots before 0.2.7-rc.6.12 found, and the checks of the tour's step
controls that hold them (tools/ci/ui-tour.livecodescript):

- A disabled label is drawn etched in the Windows look: a point down and
  right in the top colour, then in the bottom colour. On Windows' dark mode
  those are the theme's white and grey, so it read as an enabled label (the
  menu bar's Group and Edit Group, Preferences' check boxes); on a dark GTK
  theme it all but vanished. On a background the theme makes dark it is
  drawn once, halfway from the background to white
  (engine/src/buttondraw.cpp, MCButtonDisabledInkOnDarkTheme). A background
  of a user's own colour keeps the etched label.
- Windows' dark mode drew an option menu and a combo box as plain boxes,
  with no arrow (engine/src/w32theme.cpp, drawwidget).
- From macOS 11 a hilited standard button is a light grey in the light
  appearance, and its label was forced white on it (the Dictionary's
  "xTalk Script"); before macOS 11 it glowed blue, and a default button
  still has the accent colour, so those keep their white label.
- Windows' theme draws a scrollbar light whatever the appearance, so in
  dark mode every scrollbar, a field's own among them, was a light grey
  track with white arrows on the dark window. In dark mode its parts are
  drawn as Windows' own dark scrollbars are (engine/src/w32theme.cpp,
  MCWin32DrawDarkScrollPart): the track a little darker than the window,
  a grey thumb, grey arrows.

The step measures each on the screen: a disabled label against an enabled
one, a hilited button's label, and the arrow of an option menu and a combo
box, and on a dark card a scrollbar's track. On the released rc.6.11 IDE it
fails on Linux with a dark theme (the disabled label: 17), and the
screenshots of main show Windows' dark (the disabled label 223 like the
enabled one, no arrow, a track of 240) and the Mac's light (the hilited
label 15).

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
    """The C++ function `name` of `text`, from its line to its closing brace
    at the start of a line."""
    m = re.search(r'^[^\n]*\b%s\([^\n]*\n\{.*?^\}' % re.escape(name), text, re.M | re.S)
    if m is None:
        raise AssertionError('no function %s' % name)
    return m.group(0)


def handler(text, kind, name):
    m = re.search(r'^(?:private )?%s %s\b.*?^end %s\b' % (kind, re.escape(name), re.escape(name)),
                  text, re.M | re.S)
    if m is None:
        raise AssertionError('no %s %s' % (kind, name))
    return m.group(0)


class TheDisabledLabel(unittest.TestCase):
    """On a background the theme makes dark a disabled label is one grey."""

    def setUp(self):
        self.source = read('engine', 'src', 'buttondraw.cpp')

    def test_the_ink(self):
        ink = c_function(self.source, 'MCButtonDisabledInkOnDarkTheme')
        # a colour or pattern of the button's own, or of an object it
        # inherits from, keeps the etched label
        self.assertIn('t_object -> getcindex(DI_BACK, t_index) || t_object -> getpindex(DI_BACK, t_index)', ink)
        self.assertIn('t_object != MCdispatcher; t_object = t_object -> getparent()', ink)
        self.assertIn('p_button -> getforecolor(DI_BACK, False, False, t_back', ink)
        self.assertIn('if (t_luma >= 32768)', ink)
        for part in ('red', 'green', 'blue'):
            self.assertIn('r_ink . %s = t_back . %s + (0xFFFF - t_back . %s) / 2;' % (part, part, part), ink)
        # the web's dark theme has edge colours of its own
        self.assertLess(ink.index('#if defined(__EMSCRIPTEN__)\n\treturn false;\n#else'),
                        ink.index('getcindex'))

    def test_the_label_uses_it(self):
        draw = c_function(self.source, 'MCButton::draw')
        decided = ('t_flat_disabled = (flags & F_DISABLED) != 0 && !t_themed_menu && MClook == LF_WIN95\n'
                   '\t\t\t                  && MCButtonDisabledInkOnDarkTheme(this, dc, t_disabled_ink);')
        self.assertIn(decided, draw)
        flat = ('if (t_flat_disabled)\n'
                '\t\t\t\t\tdc -> setforeground(t_disabled_ink);\n'
                '\t\t\t\telse if ((flags & F_DISABLED) != 0 && !t_themed_menu && MClook == LF_WIN95)\n'
                '\t\t\t\t{\n'
                '\t\t\t\t\tdrawlabel(dc, sx + 1 + loff, sy + 1 + loff,')
        self.assertIn(flat, draw)
        # decided once, before the lines are drawn
        self.assertLess(draw.index(decided), draw.index('for (t_line = 0 ; t_line < nlines ; t_line++)'))

    def test_the_ink_is_between(self):
        # Windows' dark button (32), Linux's plain dark theme (#353535) and
        # Adwaita-dark's (about 45): the grey differs from the face by about
        # half of what white does, within the tour's bounds (24 or more, and
        # no more than 0.7 of an enabled white label)
        for back in (0x20, 0x35, 0x2D):
            ink = back + (0xFF - back) // 2
            enabled = 0xFF - back
            self.assertGreaterEqual(ink - back, 24)
            self.assertLessEqual(ink - back, enabled * 0.7)


class TheArrow(unittest.TestCase):
    """Windows' dark mode draws an option menu's and a combo box's arrow."""

    def test_drawwidget(self):
        theme = read('engine', 'src', 'w32theme.cpp')
        draw = c_function(theme, 'MCNativeTheme::drawwidget')
        dark = draw[:draw.index('return True; // Skip Windows native theme drawing')]
        self.assertIn('if (t_appearance == kMCSystemAppearanceDark)', dark)
        arrow = dark[dark.index('if (winfo.type == WTHEME_TYPE_OPTIONBUTTON || winfo.type == WTHEME_TYPE_COMBO)'):]
        self.assertIn('t_part = MCMax(drect.height - 2, 0);', arrow)
        self.assertIn('t_part = getmetric(WTHEME_METRIC_OPTIONBUTTONARROWSIZE);', arrow)
        self.assertIn('dc->fillpolygon(t_arrow, 3);', arrow)
        self.assertIn('if (winfo.state & WTHEME_STATE_DISABLED)', arrow)


class TheHilitedLabel(unittest.TestCase):
    """From macOS 11 a hilited standard button keeps its label's colour."""

    def test_the_mac_branch(self):
        source = read('engine', 'src', 'buttondraw.cpp')
        start = source.index('bool t_should_use_white_text = false;')
        branch = source[start:source.index('if (t_should_use_white_text)', start)]
        self.assertIn('(((state & CS_HILITED) && MCmajorosversion < MCOSVersionMake(10,16,0))\n'
                      '                        || (state & CS_SHOW_DEFAULT))', branch)
        self.assertNotIn('((state & CS_HILITED) || (state & CS_SHOW_DEFAULT))', branch)
        # a default button with no colour of its own keeps its white label
        self.assertIn('if ((state & CS_SHOW_DEFAULT) && !(flags & F_DISABLED) && isstdbtn', branch)
        # and it is the branch macOS builds
        self.assertGreater(start, source.rindex('#if defined(_MACOSX) /* OXT-TOM: macOS */', 0, start))
        self.assertLess(source.rindex('#if defined(_MACOSX) /* OXT-TOM: macOS */', 0, start),
                        source.rindex('#ifdef _MACOSX', 0, start))
        self.assertNotIn('#else', source[source.rindex('#if defined(_MACOSX) /* OXT-TOM: macOS */', 0, start):start])


class TheScrollbars(unittest.TestCase):
    """Windows' dark mode draws a scrollbar's parts dark."""

    PARTS = ('WTHEME_TYPE_SCROLLBAR_TRACK_VERTICAL', 'WTHEME_TYPE_SCROLLBAR_TRACK_HORIZONTAL',
             'WTHEME_TYPE_SCROLLBAR_BUTTON_UP', 'WTHEME_TYPE_SCROLLBAR_BUTTON_DOWN',
             'WTHEME_TYPE_SCROLLBAR_BUTTON_LEFT', 'WTHEME_TYPE_SCROLLBAR_BUTTON_RIGHT',
             'WTHEME_TYPE_SCROLLBAR_THUMB_VERTICAL', 'WTHEME_TYPE_SCROLLBAR_THUMB_HORIZONTAL',
             'WTHEME_TYPE_SCROLLBAR_GRIPPER_VERTICAL', 'WTHEME_TYPE_SCROLLBAR_GRIPPER_HORIZONTAL',
             'WTHEME_TYPE_SPIN')

    def setUp(self):
        self.theme = read('engine', 'src', 'w32theme.cpp')

    def test_every_part_is_drawn(self):
        part = c_function(self.theme, 'MCWin32DrawDarkScrollPart')
        for name in self.PARTS:
            self.assertIn('case %s:' % name, part)
        self.assertIn('default:\n\t\treturn false;', part)

    def test_drawwidget_draws_them_in_dark_mode(self):
        draw = c_function(self.theme, 'MCNativeTheme::drawwidget')
        # before the theme's own drawing, and before the dark push buttons
        head = draw[:draw.index('HANDLE htheme = GetTheme(winfo.type);')]
        hook = head[:head.index('//-- tperry 18th November 2025: Custom draw widgets in dark mode')]
        for name in self.PARTS:
            self.assertIn('case %s:' % name, hook)
        self.assertIn('if (t_appearance == kMCSystemAppearanceDark && MCWin32DrawDarkScrollPart(dc, winfo, drect))\n'
                      '\t\t\t\treturn True;', hook)

    def test_the_greys(self):
        part = c_function(self.theme, 'MCWin32DrawDarkScrollPart')
        track = int(re.search(r'const uint2 kTrack = (0x[0-9A-F]+);', part).group(1), 16)
        # the dark window is 32 (engine/src/w32dcs.cpp, MCWin32UpdateSystemColors)
        window = read('engine', 'src', 'w32dcs.cpp')
        self.assertIn('t_screen->background_pixel.red = t_screen->background_pixel.green = '
                      't_screen->background_pixel.blue = 0x2020;', window)
        self.assertLess(track, 0x20)
        thumb = part[part.index('case WTHEME_TYPE_SCROLLBAR_THUMB_VERTICAL:'):part.index('case WTHEME_TYPE_SCROLLBAR_GRIPPER_VERTICAL:')]
        levels = [int(v, 16) for v in re.findall(r't_level = (0x[0-9A-F]+);', thumb)]
        self.assertEqual(levels, [0x30, 0x9E, 0x7A, 0x4D])  # disabled, dragged, under the mouse, at rest
        self.assertGreaterEqual(min(levels[1:]) - track, 0x30)  # a thumb is seen on the track
        arrows = part[part.index('case WTHEME_TYPE_SCROLLBAR_BUTTON_UP:'):part.index('case WTHEME_TYPE_SPIN:')]
        self.assertIn('MCWin32DarkArrow(dc, drect, winfo.type - WTHEME_TYPE_SCROLLBAR_BUTTON_UP, t_level);', arrows)
        self.assertGreaterEqual(0xA0 - track, 0x80)  # an arrow at rest is seen

    def test_the_arrows_point_their_way(self):
        # The direction is the part's place after BUTTON_UP: up, down, left, right
        header = read('engine', 'src', 'mctheme.h')
        order = re.findall(r'WTHEME_TYPE_SCROLLBAR_BUTTON_(UP|DOWN|LEFT|RIGHT),', header)
        self.assertEqual(order, ['UP', 'DOWN', 'LEFT', 'RIGHT'])
        arrow = c_function(self.theme, 'MCWin32DarkArrow')
        self.assertIn('// p_direction: 0 up, 1 down, 2 left, 3 right.', arrow)
        up = arrow[arrow.index('case 0:'):arrow.index('case 1:')]
        self.assertIn('t_arrow[2].x = t_cx; t_arrow[2].y = t_cy - t_depth;', up)
        left = arrow[arrow.index('case 2:'):arrow.index('default:')]
        self.assertIn('t_arrow[2].x = t_cx - t_depth; t_arrow[2].y = t_cy;', left)


class TheTour(unittest.TestCase):
    """The step controls measures each of them."""

    def setUp(self):
        self.tour = read('tools', 'ci', 'ui-tour.livecodescript')

    def test_the_controls(self):
        stack = handler(self.tour, 'function', 'tourControlsStack')
        for name in ('LabelOn', 'LabelOff', 'Hilited', 'Option', 'Combo'):
            self.assertIn('create button "%s"' % name, stack)
        self.assertIn('set the rect of it to "364,156,440,182"\n   set the enabled of it to false', stack)
        # the Mac's white label was for a button 24 points high or less
        self.assertIn('set the rect of it to "280,268,400,290"\n   set the hilite of it to true', stack)
        self.assertIn('set the menuMode of it to "option"', stack)
        self.assertIn('set the menuMode of it to "comboBox"', stack)

    def test_the_checks(self):
        step = handler(self.tour, 'on', 'tour_controls')
        self.assertIn('put tourLabelInk("LabelOn", 12) into tOn', step)
        self.assertIn('put tourLabelInk("LabelOff", 12) into tOff', step)
        self.assertIn('tourCtlCheck tOff <= tOn * 0.7, "a disabled label is fainter than an enabled one', step)
        self.assertIn('tourCtlCheck tOff >= 24, "a disabled label is seen on its button', step)
        self.assertIn('put tourLabelInk("Hilited", 12) into tMax', step)
        self.assertIn('tourCtlCheck tMax >= 72, "a hilited standard button\'s label is seen on it', step)
        self.assertIn('repeat for each item tWhere in "Option,Combo"', step)
        self.assertIn('put tourMaxDiff(sPixWidth - 20, 3, sPixWidth - 3, sPixHeight - 3, tInside) into tMax', step)
        self.assertIn('tourCtlCheck tMax >= 48, "the" && tWhere && "button shows its arrow', step)
        # a scrollbar's track on a dark card, clear of its thumb and arrows
        self.assertIn('put tourLum(sPixWidth * 3 div 4, sPixHeight div 2) into tInside', step)
        self.assertIn('tourCtlCheck tInside < 100, "a scrollbar\'s track is dark on the dark card', step)
        self.assertLess(step.index('tourGrab "Scroll"'), step.index('a scrollbar\'s track is dark'))
        self.assertLess(step.index('a scrollbar\'s track is dark'), step.index('repeat for each item tWhere in "Slider,SliderOff"'))
        stack = handler(self.tour, 'function', 'tourControlsStack')
        self.assertIn('create scrollbar "Scroll"\n   set the rect of it to "280,130,440,146"\n'
                      '   set the endValue of it to 100\n   set the thumbSize of it to 20\n'
                      '   set the thumbPosition of it to 30', stack)
        ink = handler(self.tour, 'function', 'tourLabelInk')
        self.assertIn('return tourMaxDiff(pFace + 4, 5, sPixWidth - pFace - 4, sPixHeight - 5, tFace)', ink)


if __name__ == '__main__':
    unittest.main()
