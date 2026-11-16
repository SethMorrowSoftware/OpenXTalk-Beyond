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

"""The keyboard and the backdrop on Linux (forum report for 0.2.8-dp.1 on
Ubuntu 26.04, Wayland): read from the files without an engine. The engine
gives the keyboard on from the backdrop to a stack, and a key the backdrop
gets goes to that stack; the IDE opens the Message Box and the Tools
palette once, modeless, on the desktops where it keeps them modeless,
instead of opening them as palettes and making their windows again; and
tools/ci/backdrop_focus_check.py's verdicts, with made-up lines. The check
itself runs the engine under three window managers in build-linux.yml.

  python3 -m unittest discover -s tools/ci/tests
"""

import os
import re
import sys
import unittest

CI = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REPO = os.path.dirname(os.path.dirname(CI))
sys.path.insert(0, CI)

import backdrop_focus_check as bfc  # noqa: E402

ENGINE = os.path.join(REPO, 'engine', 'src', 'lnxdclnx.cpp')
IDE_LIBRARY = os.path.join(REPO, 'ide', 'Toolset', 'libraries', 'revidelibrary.8.livecodescript')
LINUX_WORKFLOW = os.path.join(REPO, '.github', 'workflows', 'build-linux.yml')


def read(path):
    with open(path, encoding='utf-8') as f:
        return f.read()


def handler(text, kind, name):
    """The text of a handler of a script, from its first line to its end."""
    m = re.search(r'^%s %s\b.*?^end %s\b' % (kind, re.escape(name), re.escape(name)), text, re.M | re.S)
    if m is None:
        raise AssertionError('no %s %s' % (kind, name))
    return m.group(0)


def case_body(text, label):
    """The lines of a switch's case up to its break."""
    m = re.search(r'case "%s"\n(.*?)\n\s*break' % re.escape(label), text, re.S)
    if m is None:
        raise AssertionError('no case "%s"' % label)
    return m.group(1)


def statements(text):
    """A script's lines without comments and blank lines."""
    out = []
    for line in text.splitlines():
        line = line.split('--', 1)[0].strip()
        if line:
            out.append(line)
    return out


class EngineGivesTheKeyboardOn(unittest.TestCase):
    def setUp(self):
        self.text = read(ENGINE)
        m = re.search(r'case GDK_FOCUS_CHANGE:(.*?)case GDK_KEY_PRESS:', self.text, re.S)
        self.focus = m.group(1)
        m = re.search(r'case GDK_KEY_PRESS:(.*?)case GDK_ENTER_NOTIFY:', self.text, re.S)
        self.keys = m.group(1)

    def test_focus_in_backdrop_goes_on_to_a_stack(self):
        gained = self.focus.split('// Focus was lost.')[0]
        self.assertRegex(gained, r't_event->focus_change\.window == backdrop')
        self.assertIn('backdrop_focus_target()', gained)
        self.assertIn('setinputfocus(t_target)', gained)
        # still told to the dispatcher first, as before
        self.assertLess(gained.index('MCdispatcher->wkfocus'), gained.index('backdrop_focus_target()'))

    def test_keys_of_backdrop_go_to_a_stack(self):
        self.assertIn('backdrop_focus_target()', self.keys)
        self.assertIn('MCdispatcher->wkdown(t_key_window', self.keys)
        self.assertIn('MCdispatcher->wkup(t_key_window', self.keys)
        self.assertNotIn('MCdispatcher->wkdown(t_event->key.window', self.keys)

    def test_target_only_when_a_stack_is_on_the_screen(self):
        target = re.search(r'static Window backdrop_focus_target\(void\)\n\{(.*?)\n\}', self.text, re.S).group(1)
        # nothing on the screen: nil, and the keys stay where they were
        self.assertIn('return nil;', target)
        self.assertIn('return t_palette;', target)
        candidate = re.search(r'static bool backdrop_focus_candidate\(.*?\n\}', self.text, re.S).group(0)
        for need in ('getopened()', 'isiconic()', 'isvisible(false)', 'gdk_window_is_viewable'):
            self.assertIn(need, candidate)
        # a menu, a popup or a tooltip never takes the keyboard
        self.assertIn('t_mode > WM_SHEET', candidate)


class IdeOpensPaletteOnce(unittest.TestCase):
    def setUp(self):
        self.text = read(IDE_LIBRARY)
        self.toggle = handler(self.text, 'on', 'revIDETogglePalette')
        self.open = handler(self.text, 'command', 'revIDEOpenPalette')

    def test_open_palette_takes_modeless_as_an_option(self):
        self.assertTrue(self.open.startswith('command revIDEOpenPalette pPaletteName, pAsModeless'))
        for label in ('message box', 'snippet viewer'):
            body = statements(case_body(self.open, label))
            self.assertIn('if pAsModeless is true then', body)
            self.assertIn('modeless stack tStackName', body)
            # without the option it is a palette, as before
            self.assertIn('palette stack tStackName', body)

    def test_toggle_opens_modeless_once(self):
        lines = statements(self.toggle)
        opening = lines.index('revIDEOpenPalette pPaletteName, true')
        # the style is set before the window is opened, and only when it is
        # not modeless already (setting it makes an open stack's window again)
        before = lines[:opening]
        self.assertIn('if the style of stack tStackName is not "modeless" then', before)
        self.assertIn('set the style of stack tStackName to modeless', before)
        # after: only for a stack that did not open modeless (mode 3)
        after = lines[opening + 1:opening + 4]
        self.assertEqual(after[0], 'if the mode of stack tStackName is not 3 then')
        self.assertEqual(after[1], 'set the style of stack tStackName to modeless')

    def test_toggle_elsewhere_as_before(self):
        lines = statements(self.toggle)
        self.assertIn('revIDEOpenPalette pPaletteName', lines)
        # the desktops it keeps the palettes modeless on are those of before
        self.assertIn('put "icewm,xubuntu,ubuntu,xfce" into tFixDistros', lines)
        self.assertIn('close stack tStackName', lines)


class CheckVerdicts(unittest.TestCase):
    def test_keyboard_in_stack(self):
        self.assertTrue(bfc.keyboard_in_stack('BFMain *'))
        self.assertTrue(bfc.keyboard_in_stack('BFMain'))
        self.assertTrue(bfc.keyboard_in_stack('BFPalette'))
        # the backdrop has the program's name
        self.assertFalse(bfc.keyboard_in_stack('Standalone'))
        self.assertFalse(bfc.keyboard_in_stack(''))

    def test_parse(self):
        fields, events, errors = bfc.parse([
            'INFO platform=Linux', 'READY 1', 'READY 2', 'FIELD 2 abc', 'READY 3',
            'EVENT mouseDownInBackdrop 1', 'FIELD 3 ', 'DONE'])
        self.assertEqual(fields, {'2': 'abc', '3': ''})
        self.assertEqual(events, ['mouseDownInBackdrop 1'])
        self.assertEqual(errors, [])
        self.assertEqual(bfc.parse(['FIELD 2', 'ERROR 89,72,1'])[0:3:2], ({'2': ''}, ['89,72,1']))

    def test_runs_in_the_linux_build(self):
        workflow = read(LINUX_WORKFLOW)
        self.assertIn('python3 tools/ci/backdrop_focus_check.py --engine', workflow)
        # mutter is the window manager of the report
        self.assertIn('mutter', bfc.FOCUS_MUST_MOVE)


if __name__ == '__main__':
    unittest.main()
