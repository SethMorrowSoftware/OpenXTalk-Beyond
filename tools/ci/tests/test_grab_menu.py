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

"""A group grabbed from the mouseDown of a menu button in it (openxtalk.org
p=9443, p=9448; LiveCode Community 9.6.3 crashed on the release): read from
the files without an engine. MCGroup::mup ends the grab without a control
under the mouse instead of calling through a nil one, and
tools/ci/grab_menu_check.py's verdicts, with made-up lines. The check itself
presses and releases the system's mouse on a built engine in
build-linux.yml.

  python3 -m unittest discover -s tools/ci/tests
"""

import os
import re
import sys
import unittest

CI = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REPO = os.path.dirname(os.path.dirname(CI))
sys.path.insert(0, CI)

import grab_menu_check as gmc  # noqa: E402

GROUP = os.path.join(REPO, 'engine', 'src', 'group.cpp')
LINUX_WORKFLOW = os.path.join(REPO, '.github', 'workflows', 'build-linux.yml')
SCRIPT = os.path.join(CI, 'grab-menu-check.livecodescript')


def read(path):
    with open(path, encoding='utf-8') as f:
        return f.read()


class Engine(unittest.TestCase):
    def test_release_of_a_grab_asks_for_the_control_first(self):
        mup = re.search(r'Boolean MCGroup::mup\(uint2 which, bool p_release\)\n\{(.*?)\n\}', read(GROUP), re.S).group(1)
        grab = mup[mup.index('if (state & CS_GRAB)'):]
        grab = grab[:grab.index('return mfocused->mup(which, p_release);')]
        self.assertIn('if (!mfocused.IsValid())', grab)
        # the grab is over before the early return, or the group stays grabbed
        self.assertLess(grab.index('state &= ~(CS_GRAB | CS_MFOCUSED);'), grab.index('if (!mfocused.IsValid())'))
        self.assertLess(grab.index('mgrabbed = False;'), grab.index('if (!mfocused.IsValid())'))
        self.assertLess(grab.index('if (!mfocused.IsValid())'), grab.index('mfocused->mfocus(mx, my);'))


class CheckVerdicts(unittest.TestCase):
    def test_the_engine_runs_on(self):
        before = ['READY', 'GROUP mouseDown', 'ALIVE 200,150']
        after = before + ['ALIVE 200,150', 'ALIVE 200,150', 'ALIVE 200,150']
        self.assertTrue(all(ok for ok, _, _ in gmc.verdict(before, after, None, 'popup')))

    def test_a_crash_fails(self):
        before = ['READY', 'GROUP mouseDown', 'ALIVE 200,150']
        results = gmc.verdict(before, before, 255, 'option')
        self.assertEqual([ok for ok, _, _ in results], [True, False])
        self.assertIn('exit code 255', results[1][2])
        self.assertIn('option', results[1][1])

    def test_a_hang_fails(self):
        before = ['READY', 'GROUP mouseDown', 'ALIVE 200,150']
        self.assertEqual([ok for ok, _, _ in gmc.verdict(before, before + ['ALIVE 200,150'], None, 'pulldown')],
                         [True, False])

    def test_a_press_that_missed_fails(self):
        lines = ['READY', 'ALIVE 200,150', 'ALIVE 200,150', 'ALIVE 200,150']
        self.assertFalse(gmc.verdict(lines[:2], lines, None, 'popup')[0][0])

    def test_drag(self):
        self.assertTrue(all(ok for ok, _, _ in gmc.drag_verdict(['PLAIN mouseDown', 'ALIVE 300,300', 'ALIVE 340,320'])))
        self.assertEqual([ok for ok, _, _ in gmc.drag_verdict(['PLAIN mouseDown', 'ALIVE 300,300', 'ALIVE 300,300'])],
                         [True, False])
        self.assertEqual([ok for ok, _, _ in gmc.drag_verdict([])], [False, False])

    def test_runs_in_the_linux_build(self):
        self.assertIn('python3 tools/ci/grab_menu_check.py --engine', read(LINUX_WORKFLOW))
        # the three menu kinds of the reports, each in the group that grabs
        script = read(SCRIPT)
        self.assertIn('grab me', script)
        self.assertIn('OXT_GRAB_MENU_MODE', script)


if __name__ == '__main__':
    unittest.main()
