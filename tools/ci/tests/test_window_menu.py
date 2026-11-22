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

"""The IDE's Window menu (revMenubarWindowMenu, in
ide/Toolset/palettes/menubar/revmenubar.livecodescript), read as text.

Until 0.2.8-dp.2.1 the menu listed the user's stacks, the script editors,
the Dictionary and the Resource Center, then the Message Box, the Tools
palette and the Project Browser, and no other window of the IDE: an
Extension Manager or a Property Inspector behind another window could not
be brought back from it (OpenXTalkPaul, openxtalk.org p=26643). Its lines
are now followed by the IDE's other open windows
(revMenubarWindowMenuIDEWindows). The lines it had stay as they were;
the palettes it lists are the IDE's own, by the names the IDE knows them
by; and the About window, whose palette name opens it, is not looked up
by that name. The menu itself is exercised in the real IDE by the
everyday task window-menu (tools/ci/everyday-tasks.livecodescript).

  python3 -m unittest discover -s tools/ci/tests
"""

import glob
import os
import re
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, '..', '..', '..')
TOOLSET = os.path.join(ROOT, 'ide', 'Toolset')
MENUBAR = os.path.join(TOOLSET, 'palettes', 'menubar', 'revmenubar.livecodescript')
IDELIB = os.path.join(TOOLSET, 'libraries', 'revidelibrary.8.livecodescript')
COMMONLIB = os.path.join(TOOLSET, 'libraries', 'revcommonlibrary.livecodescript')
EVERYDAY = os.path.join(ROOT, 'tools', 'ci', 'everyday-tasks.livecodescript')


def read(path):
    with open(path, encoding='utf-8-sig') as f:
        return f.read()


def handler(text, name):
    m = re.search(r'^(?:private )?(?:function|on|command) %s\b.*?^end %s\s*$' % (name, name), text, re.M | re.S)
    if not m:
        raise AssertionError('no handler %s' % name)
    return m.group(0)


def constant(text, name):
    m = re.search(r'^constant %s = "([^"]*)"' % name, text, re.M)
    if not m:
        raise AssertionError('no constant %s' % name)
    return m.group(1).split(',')


class WindowMenu(unittest.TestCase):

    @classmethod
    def setUpClass(cls):
        cls.menubar = read(MENUBAR)
        cls.idelib = read(IDELIB)
        cls.menu = handler(cls.menubar, 'revMenubarWindowMenu')
        cls.windows = handler(cls.menubar, 'revMenubarWindowMenuIDEWindows')
        m = re.search(r'^function revIDEAvailablePalettes\s*\n\s*return (.*?)\nend revIDEAvailablePalettes', cls.idelib, re.M | re.S)
        cls.palettes = ''.join(re.findall(r'"([^"]*)"', m.group(1))).split(',')

    def test_the_lines_it_had_stay_as_they_were(self):
        # the window list, then the three palettes, each as it was, and in
        # that order; the IDE's other windows after them, then Send Window
        # to Back
        had = [
            'put sWindowMenuWindows into tWdListToShow',
            'if revIDEPaletteIsVisible("Message Box") is true then put tWdListToShow & return & "!nMessage Box/|stack " & QUOTE & "Message Box" & QUOTE into tWdListToShow',
            'if revIDEPaletteIsVisible("Tools") is true then put tWdListToShow & return & "!nTools/|stack " & QUOTE & "revTools" & QUOTE into tWdListToShow',
            'if revIDEPaletteIsVisible("Project Browser") is true then put tWdListToShow & return & "!nProject Browser/|stack " & QUOTE & "revIDEProjectBrowser" & QUOTE into tWdListToShow',
            'revMenubarWindowMenuIDEWindows()',
            'filter lines of tWdListToShow without empty',
            'else put tWdListToShow & return & "-" & return & "Send Window to Back/`" into tWindow',
        ]
        at = [self.menu.find(line) for line in had]
        self.assertNotIn(-1, at, 'a line of the Window menu is gone: %s' % had[at.index(-1)] if -1 in at else '')
        self.assertEqual(at, sorted(at), 'the lines of the Window menu are out of order')

    def test_its_lines_are_as_the_others_are(self):
        # "!n<label>/|stack "<name>"", so a pick goes to the window
        # (revMenubarWindowMenuPick -> revIDESendWindowToFront)
        self.assertIn('put "!n" & revMenubarEscapeStackNameForMenu(tLabel) & "/|stack " & quote & tStack & quote & return after tLines', self.windows)
        pick = handler(self.menubar, 'revMenubarWindowMenuPick')
        self.assertIn('else revIDESendWindowToFront pWhich', pick)

    def test_the_palettes_left_out_are_the_ides(self):
        left_out = constant(self.menubar, 'kWindowMenuNotPalettes')
        for name in left_out:
            self.assertIn(name, self.palettes, '%s is not a palette of revIDEAvailablePalettes' % name)
        # the three the menu lists above, the menu bar itself, the
        # Inspector (a hidden stack that keeps the Property Inspectors), the
        # About window (revIDEPaletteToStackName("about") opens it) and the
        # three windows revIDEStackIsIDEWindow admits
        self.assertEqual(set(left_out), {'Menubar', 'Tools', 'Message Box', 'Project Browser', 'Inspector', 'About',
                                         'Dictionary', 'Guide', 'Resource Center'})

    def test_about_is_not_looked_up_by_its_name(self):
        # a lookup of "about" opens the About window
        about = re.search(r'case "about"\s*\n(.*?)\n\s*break', handler(self.idelib, 'revIDEPaletteToStackName'), re.S)
        self.assertIn('tOpenAbout', about.group(1))
        skip = self.windows.find('if tPalette is among the items of kWindowMenuNotPalettes then next repeat')
        lookup = self.windows.find('revIDEPaletteToStackName(tPalette)')
        self.assertGreater(skip, -1)
        self.assertGreater(lookup, skip)

    def test_every_palette_listed_has_its_stack(self):
        to_stack = handler(self.idelib, 'revIDEPaletteToStackName')
        cases = {c.lower() for c in re.findall(r'case "([^"]*)"', to_stack)}
        for name in self.palettes:
            if name in constant(self.menubar, 'kWindowMenuNotPalettes'):
                continue
            self.assertIn(name.lower(), cases, 'revIDEPaletteToStackName has no stack for %s' % name)

    def test_the_other_windows_are_the_ides(self):
        # each a stack of the IDE's Toolset: a script-only stack of that
        # name, or one revStackNameIsIDEStack knows by its file
        named = set()
        for path in glob.glob(os.path.join(TOOLSET, 'palettes', '**', '*.livecodescript'), recursive=True):
            first = read(path).split('\n', 1)[0]
            m = re.match(r'script "([^"]+)"', first)
            if m:
                named.add(m.group(1))
        toolset_files = handler(read(COMMONLIB), 'revInternal__IDEToolsetStackFile')
        academy = read(os.path.join(TOOLSET, 'palettes', 'academy', 'revacademy.livecodescript'))
        for name in constant(self.menubar, 'kWindowMenuIDEWindows'):
            known = name in named or ('case "%s"' % name) in toolset_files \
                or ('constant kStage = "%s"' % name) in academy
            self.assertTrue(known, '%s is not a window of the IDE' % name)

    def test_only_shown_windows_that_are_not_dialogs_or_menus(self):
        self.assertIn('if revIDEStackIsWindow(tStack) then next repeat', self.windows)
        self.assertIn('if tMode < 1 or tMode > 4 or not the visible of stack tStack then next repeat', self.windows)

    def test_the_everyday_task_runs_it(self):
        tasks = re.search(r'^constant kTasks = "([^"]*)"', read(EVERYDAY), re.M).group(1).split(',')
        self.assertIn('window-menu', tasks)
        # (early, so that --only window-menu runs three tasks)
        self.assertEqual(tasks.index('window-menu'), tasks.index('new-stack') + 1)


if __name__ == '__main__':
    unittest.main()
