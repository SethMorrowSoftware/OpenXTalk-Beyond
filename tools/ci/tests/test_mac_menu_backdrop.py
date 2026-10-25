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

"""tools/ci/mac_menu_backdrop.py's verdict on the window server's order of
the IDE's windows, with made-up lists: the backdrop behind them, in front
of them, missing, or with nothing of its layer to be behind; and the
lines of the window list as the driver reads them.

  python3 -m unittest discover -s tools/ci/tests
"""

import os
import sys
import unittest
from unittest import mock

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))

import mac_menu_backdrop as mb  # noqa: E402

SCREEN = (0, 0, 1024, 768)

# (number, layer, x, y, width, height, title), front to back
TOOLS = (41, 3, 0, 60, 120, 400, 'Tools')
MENUBAR = (40, 0, 0, 25, 1024, 60, 'OXT-Beyond')
STACK = (42, 0, 200, 200, 400, 300, 'Untitled 1')
BACKDROP = (38, 0, 0, 0, 1024, 768, '')
DUMMY = (37, 0, 0, 0, 0, 0, '')


class BackdropBehind(unittest.TestCase):
    def test_behind(self):
        behind, text = mb.backdrop_behind([TOOLS, MENUBAR, STACK, BACKDROP, DUMMY], SCREEN)
        self.assertIs(behind, True)
        self.assertEqual(text, 'the backdrop is behind: Tools (layer 3) > OXT-Beyond > Untitled 1 > [backdrop]')

    def test_in_front(self):
        # as rc.6.4 left it after a click on the backdrop: in front of
        # every window of the normal layer, behind the palettes
        behind, text = mb.backdrop_behind([TOOLS, BACKDROP, MENUBAR, STACK], SCREEN)
        self.assertIs(behind, False)
        self.assertEqual(text, 'the backdrop is IN FRONT of OXT-Beyond, Untitled 1: '
                               'Tools (layer 3) > [backdrop] > OXT-Beyond > Untitled 1')

    def test_in_front_of_one(self):
        behind, text = mb.backdrop_behind([MENUBAR, BACKDROP, STACK], SCREEN)
        self.assertIs(behind, False)
        self.assertTrue(text.startswith('the backdrop is IN FRONT of Untitled 1: '), text)

    def test_palettes_behind_do_not_count(self):
        # a window of another layer is ordered by its layer, not by the
        # backdrop, wherever the list has it
        behind, text = mb.backdrop_behind([MENUBAR, BACKDROP, (43, -20, 0, 0, 50, 50, 'Low')], SCREEN)
        self.assertIs(behind, True)

    def test_zero_size_windows_do_not_count(self):
        behind, text = mb.backdrop_behind([MENUBAR, BACKDROP, DUMMY], SCREEN)
        self.assertIs(behind, True)
        self.assertNotIn('0x0', text)

    def test_untitled_window_named_by_its_place(self):
        behind, text = mb.backdrop_behind([(44, 0, 10, 20, 300, 200, ''), BACKDROP], SCREEN)
        self.assertIs(behind, True)
        self.assertEqual(text, 'the backdrop is behind: #44 300x200 at 10,20 > [backdrop]')

    def test_no_backdrop(self):
        # a window of the screen's size elsewhere, or of another layer, is
        # not the backdrop
        behind, text = mb.backdrop_behind([MENUBAR, (45, 3, 0, 0, 1024, 768, 'Big palette')], SCREEN)
        self.assertIsNone(behind)
        self.assertTrue(text.startswith('no backdrop: '), text)

    def test_nothing_to_be_behind(self):
        # no answer, not a pass: only palettes and the backdrop
        behind, text = mb.backdrop_behind([TOOLS, BACKDROP], SCREEN)
        self.assertIsNone(behind)
        self.assertTrue(text.startswith('no window of the normal layer but the backdrop: '), text)

    def test_no_list(self):
        self.assertEqual(mb.backdrop_behind(None, SCREEN), (None, 'no window list'))


class WindowOrder(unittest.TestCase):
    def test_lines(self):
        said = '41 3 0 60 120 400 Tools\n40 0 0 25 1024 60 OXT-Beyond 0.2.7\n38 0 0 0 1024 768 '
        with mock.patch.object(mb, 'osascript', return_value=(0, said)) as run:
            windows = mb.window_order(1234)
        self.assertEqual(windows, [(41, 3, 0, 60, 120, 400, 'Tools'), (40, 0, 0, 25, 1024, 60, 'OXT-Beyond 0.2.7'),
                                   (38, 0, 0, 0, 1024, 768, '')])
        self.assertEqual(run.call_args.kwargs.get('args'), [1234])

    def test_odd_line_left_out(self):
        with mock.patch.object(mb, 'osascript', return_value=(0, 'oops\n38 0 0 0 1024 768')), \
                mock.patch.object(mb, 'log'):
            self.assertEqual(mb.window_order(1), [(38, 0, 0, 0, 1024, 768, '')])

    def test_no_answer(self):
        with mock.patch.object(mb, 'osascript', return_value=(-1, 'no answer in 30 s')), \
                mock.patch.object(mb, 'log'):
            self.assertIsNone(mb.window_order(1))


if __name__ == '__main__':
    unittest.main()
