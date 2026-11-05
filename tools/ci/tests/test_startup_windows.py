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

"""tools/ci/startup_windows.py, the watch for windows that come and go
while the IDE starts ("ghost windows", openxtalk.org p=25967), and the
start check that runs it (tools/ci/linux_ide_start.sh). The watch itself
needs an X screen; what it makes of what it saw does not.

  python3 -m unittest discover -s tools/ci/tests
"""

import os
import sys
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
CI = os.path.dirname(HERE)
sys.path.insert(0, CI)

import startup_windows  # noqa: E402


class GhostsTest(unittest.TestCase):

    def test_a_start_with_no_ghost(self):
        # rc.6.16 with the fix, under openbox
        events = [(0.492, '+', 0x80011f, 'revSplash'),
                  (5.498, '+', 0x800167, 'OXT-Beyond 0.2.7-rc.6.16'),
                  (6.894, '-', 0x80011f, ''),
                  (6.901, '+', 0x8001c1, 'Tools')]
        self.assertEqual(startup_windows.ghosts(events), [])

    def test_the_ghosts_of_rc615(self):
        # rc.6.15 under openbox: the Tools palette and the Message Box came
        # up for a moment, and the Tools palette came back once the splash
        # had gone
        events = [(0.504, '+', 0x80011f, 'revSplash'),
                  (6.372, '+', 0x800167, 'OXT-Beyond 0.2.7-rc.6.15'),
                  (6.977, '+', 0x8001c1, 'Tools'),
                  (7.003, '-', 0x8001c1, ''),
                  (7.102, '+', 0x8001cb, 'Message Box (Single Line)'),
                  (7.148, '-', 0x8001cb, ''),
                  (8.012, '-', 0x80011f, ''),
                  (8.018, '+', 0x8001c1, 'Tools')]
        found = startup_windows.ghosts(events)
        self.assertEqual([title for _, title, _, _ in found],
                         ['Tools', 'Message Box (Single Line)'])
        wid, title, came, went = found[0]
        self.assertEqual(wid, 0x8001c1)
        self.assertAlmostEqual(went - came, 0.026, places=3)
        lines = startup_windows.report(events, found)
        self.assertTrue(any(line.startswith('GHOST 0x8001c1 "Tools"') for line in lines))

    def test_the_splash_is_meant_to_go(self):
        events = [(0.5, '+', 1, 'revSplash'), (7.0, '-', 1, '')]
        self.assertEqual(startup_windows.ghosts(events), [])
        self.assertIn('No window came and went (the splash aside)',
                      startup_windows.report(events, []))

    def test_a_window_seen_before_the_watch_began(self):
        # a window already on the screen has no time it came
        events = [(0.0, '+', 7, 'Other'), (3.0, '-', 7, '')]
        found = startup_windows.ghosts(events)
        self.assertEqual(found, [(7, 'Other', 0.0, 3.0)])


class StartCheckTest(unittest.TestCase):

    def test_the_start_check_runs_the_watch(self):
        with open(os.path.join(CI, 'linux_ide_start.sh')) as f:
            text = f.read()
        self.assertIn('startup_windows.py', text)
        self.assertIn('--ready', text)
        # the IDE starts only once the watch has begun
        self.assertLess(text.index('startup-windows-ready'), text.index('"$root/oxt-beyond"'))
        self.assertIn('Windows came and went while the IDE started', text)


if __name__ == '__main__':
    unittest.main()
