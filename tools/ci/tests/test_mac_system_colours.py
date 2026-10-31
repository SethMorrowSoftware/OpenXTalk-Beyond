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

"""macOS: a stack or card with no colours of its own follows the Mac's own
colours, live (seth's choice 1A of 2026-10-31; bwmilby, openxtalk.org
p=25665, p=25668). The effective colours never changed after a switch
between light and dark, and the dark appearance drew a fixed 61,61,61 that
no script could read.

The IDE tour checks it on a Mac (tools/ci/ui-tour.livecodescript, the step
system-switch: after each switch a card's effective colours are the
appearance's and the screen shows its backgroundColor), and the engine
tests read them in the appearance they run in
(tests/lcs/core/interface/effective-system-colors.livecodescript). These
tests hold the pieces to each other where no Mac runs them.

  python3 -m unittest discover -s tools/ci/tests
"""

import os
import re
import unittest

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))


def read(*path):
    with open(os.path.join(REPO, *path), encoding='utf-8-sig') as f:
        return f.read()


def between(text, start, end):
    i = text.index(start)
    return text[i:text.index(end, i + len(start))]


def handler(script, kind, name):
    start = script.index('\n%s %s' % (kind, name))
    return script[start:script.index('\nend %s\n' % name, start)]


class TheTheme(unittest.TestCase):
    """mac-theme.mm: every colour is read in the app's appearance as it is
    now, and in the dark one a window is the Mac's window colour."""

    def setUp(self):
        self.theme = read('engine', 'src', 'mac-theme.mm')
        self.colour = between(self.theme, 'bool MCPlatformGetControlThemePropColor(',
                              '\nbool MCPlatformGetControlThemePropFont(')

    def test_every_colour_is_resolved_in_the_apps_appearance(self):
        resolve = between(self.theme, 'static NSColor *MCMacThemeResolveColor(', '\n}\n')
        self.assertIn('[NSApp effectiveAppearance]', resolve)
        self.assertIn('performAsCurrentDrawingAppearance', resolve)
        self.assertIn('[NSAppearance appearanceNamed: NSAppearanceNameAqua]', resolve)
        # no conversion outside it, which took the appearance last drawn in
        self.assertNotIn('colorUsingColorSpaceName', self.colour)
        self.assertIn('MCMacThemeResolveColor([NSColor controlHighlightColor], t_light)', self.colour)
        self.assertIn('MCMacThemeResolveColor(t_color, t_light)', self.colour)

    def test_a_window_in_the_dark_is_the_macs_window_colour(self):
        window = between(self.colour, 'case kMCPlatformControlTypeMessageBox:', 'default:')
        self.assertIn('if (MCusesystemwindowcolor ||\n'
                      '                            ((p_state & kMCPlatformControlStateLightAppearance) == 0'
                      ' && MCPlatformGetSystemAppearanceIsDark()))', window)
        self.assertIn('t_color = MCMacResolveWindowBackgroundColor();', window)
        # otherwise (the light appearance) the white stacks always were
        self.assertIn('t_is_pattern = true;\n                        t_color = [NSColor windowBackgroundColor];', window)

    def test_the_light_state_is_a_bit_of_its_own(self):
        platform = read('engine', 'src', 'platform.h')
        states = dict((m.group(1), int(m.group(2))) for m in
                      re.finditer(r'(kMCPlatformControlState\w+)\s*=\s*\(1<<(\d+)\)', platform))
        self.assertIn('kMCPlatformControlStateLightAppearance', states)
        bits = list(states.values())
        self.assertEqual(len(bits), len(set(bits)), states)


class TheDrawing(unittest.TestCase):
    """object.cpp: in the dark a stack or card is drawn in the theme's
    colours, the ones its effective colours read; printed, in the light
    appearance's."""

    def setUp(self):
        self.obj = read('engine', 'src', 'object.cpp')

    def test_stacks_and_cards_take_the_theme_in_the_dark(self):
        self.assertIn('if (t_skip_theme && (o->gettype() == CT_STACK || o->gettype() == CT_CARD))\n'
                      '        t_skip_theme = false;', self.obj)
        # after the menu buttons' exception, before the theme is asked
        i = self.obj.index('if (t_skip_theme && (o->gettype() == CT_STACK')
        self.assertLess(self.obj.index('bool t_skip_theme = t_use_dark_mode'), i)
        self.assertLess(i, self.obj.index('if (!t_skip_theme &&'))

    def test_printed_in_the_light(self):
        self.assertIn('if (dc_type == CONTEXT_TYPE_PRINTER && (o->gettype() == CT_STACK || o->gettype() == CT_CARD))\n'
                      '            t_control_state |= kMCPlatformControlStateLightAppearance;', self.obj)

    def test_the_effective_colours_ask_the_same_theme(self):
        getter = between(read('engine', 'src', 'exec-interface-object.cpp'),
                         'bool MCObject::GetColor(', '\nvoid MCObject::GetForeColor(')
        self.assertIn('MCPlatformGetControlThemePropColor(t_control_type, t_control_part, t_control_state, '
                      't_control_prop, t_color)', getter)


class TheIde(unittest.TestCase):
    def test_the_classic_toolbar_follows_the_engine(self):
        menubar = read('ide', 'Toolset', 'palettes', 'menubar', 'revmenubar.livecodescript')
        self.assertNotIn('"61,61,61"', menubar)
        follow = handler(menubar, 'on', 'menubarFollowAppearance')
        self.assertIn('if the platform contains "mac" then', follow)
        self.assertIn('set the backgroundColor of me to ""', follow)


class TheChecks(unittest.TestCase):
    """The tour checks the colours after every live switch, and fails
    without them; the engine tests read them in the appearance they run
    in."""

    def setUp(self):
        self.tour = read('tools', 'ci', 'ui-tour.livecodescript')

    def test_after_every_switch(self):
        step = handler(self.tour, 'on', 'tour_system_switch')
        loop = between(step, 'repeat for each item tTarget in tOther & comma & tStart', 'end repeat\n      if')
        self.assertIn('put tourSystemColors(tColorsStack, tTarget) after tFails', loop)
        self.assertIn('if tBacks[tOther] is tBacks[tStart] then', step)
        self.assertIn('if tFails is not empty then throw', step)
        steps = re.search(r'^constant kSteps = "([^"]+)"', self.tour, re.M).group(1).split(',')
        self.assertIn('system-switch', steps)

    def test_what_it_checks(self):
        colours = handler(self.tour, 'function', 'tourSystemColors')
        for read_ in ('the effective backgroundColor of tCard', 'the effective foregroundColor of tCard',
                      'the effective backgroundColor of stack pStack', 'the effective foregroundColor of stack pStack',
                      'tourCbPixel(pStack,'):
            self.assertIn(read_, colours)
        self.assertIn('if tourSystemLight(tBack) is (pAppearance is "dark") then', colours)
        self.assertIn('if tourSystemLight(tFore) is not (pAppearance is "dark") then', colours)
        self.assertIn('if abs(item i of tShown - item i of tBack) > 8 then', colours)
        # a stack with colours of its own would check nothing
        self.assertIn('has colours of its own', colours)

    def test_the_engine_tests(self):
        test = read('tests', 'lcs', 'core', 'interface', 'effective-system-colors.livecodescript')
        self.assertIn('TestSkipIfNot "platform", "MacOS"', test)
        self.assertIn('__IsLight(tBack) is not tDark', test)
        self.assertIn('__IsLight(tFore) is tDark', test)


if __name__ == '__main__':
    unittest.main()
