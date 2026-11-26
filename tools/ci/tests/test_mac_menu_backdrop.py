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
of them, missing, or with nothing of its layer to be behind; the lines of
the window list as the driver reads them; and its look at the IDE's beat
after a step, with a made-up clock and a real beat.txt; and the slide
along the menu bar's reading of a menu's items and its verdict on them
(File must not show Exit, nor Help About, on a Mac).

  python3 -m unittest discover -s tools/ci/tests
"""

import os
import shutil
import sys
import tempfile
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


# File's items as System Events read them on 0.2.8-dp.2.1, cut short:
# opened, and after the pointer went to Edit and back (the report)
FILE_OPEN = 'New Stack\n-\nOpen Stack...\n-\nPage Setup...\nPrint Card...\nPrint Field...\n'
FILE_AFTER_SLIDE = FILE_OPEN + '-\nExit\n'


class MenuItems(unittest.TestCase):
    def test_items(self):
        with mock.patch.object(mb, 'osascript', return_value=(0, FILE_OPEN)) as run, \
                mock.patch.object(mb, 'log'):
            items = mb.menu_items(123, 'File')
        self.assertEqual(items, ['New Stack', '-', 'Open Stack...', '-', 'Page Setup...', 'Print Card...',
                                 'Print Field...'])
        script = run.call_args[0][0]
        self.assertIn('unix id is 123', script)
        self.assertIn('menu bar item "File"', script)

    def test_no_answer(self):
        with mock.patch.object(mb, 'osascript', return_value=(1, 'execution error')), mock.patch.object(mb, 'log'):
            self.assertIsNone(mb.menu_items(123, 'File'))


class ShownHidden(unittest.TestCase):
    def test_file_as_it_opens(self):
        self.assertEqual(mb.shown_hidden('File', FILE_OPEN.splitlines()), [])

    def test_file_after_the_slide_on_the_release(self):
        self.assertEqual(mb.shown_hidden('File', FILE_AFTER_SLIDE.splitlines()), ['Exit'])

    def test_help_about(self):
        self.assertEqual(mb.shown_hidden('Help', ['Home', '-', 'Check for Updates', '-', 'About']), ['About'])

    def test_edit_items_are_not_judged(self):
        # About in a menu other than Help is the menu's own item
        self.assertEqual(mb.shown_hidden('Edit', ['Undo', 'About']), [])

    def test_no_items(self):
        self.assertEqual(mb.shown_hidden('File', None), [])


class Clock:
    """A made-up clock for Run.look: sleep moves it on and calls tick with
    the time, which writes beat.txt as the engine would."""

    def __init__(self, start, tick):
        self.now, self.tick = start, tick

    def time(self):
        return self.now

    def sleep(self, seconds):
        self.now += seconds
        self.tick(self.now)


class Look(unittest.TestCase):
    START = 1795167020.0

    def setUp(self):
        self.out = tempfile.mkdtemp()
        self.addCleanup(shutil.rmtree, self.out)
        self.run_ = mb.Run(self.out, None, 1, None)

    def write(self, text):
        with open(os.path.join(self.out, 'beat.txt'), 'w', encoding='utf-8') as f:
            f.write(text)

    def beat(self, when):
        self.write('%d\tmenubar-visible=true\tpending=\n' % round(when * 1000))

    def look(self, tick):
        clock = Clock(self.START, tick)
        with mock.patch.object(mb, 'time', clock), mock.patch.object(mb, 'log') as log:
            answers = self.run_.look('backdrop')
        return answers, log.call_args.args[0]

    def test_a_beat_that_goes_on_answers(self):
        self.beat(self.START)
        answers, said = self.look(self.beat)
        self.assertIs(answers, True)
        self.assertIn('backdrop: the last beat 0.0 s ago: ', said)

    def test_a_beat_read_while_the_engine_writes_it_is_not_a_stop(self):
        # put into URL "binfile:" empties beat.txt before it writes the new
        # beat: a read between the two finds nothing, though the beat goes
        # on (the Intel Mac's menu and backdrop check of #585's run on 20
        # Nov 2026, whose engine was sampled in that very put)
        def tick(now):
            if now >= self.START + mb.LOOK:
                self.write('')
            else:
                self.beat(now)
        answers, said = self.look(tick)
        self.assertIs(answers, True, said)
        self.assertIn('backdrop: the last beat 0.5 s ago: ', said)

    def test_a_beat_half_written_is_not_a_stop(self):
        # the first digits of the new beat only: an older time, or none
        def tick(now):
            if now >= self.START + mb.LOOK:
                self.write('17951')
            else:
                self.beat(now)
        answers, said = self.look(tick)
        self.assertIs(answers, True, said)

    def test_a_beat_that_stopped_is_a_stop(self):
        self.beat(self.START - 1)
        answers, said = self.look(lambda now: None)
        self.assertIs(answers, False)
        self.assertIn('backdrop: the last beat 11.0 s ago: ', said)

    def test_a_beat_that_stopped_mid_write_is_a_stop(self):
        # the engine stopped in the put itself: the file stays empty
        self.beat(self.START - 1)
        answers, said = self.look(lambda now: self.write(''))
        self.assertIs(answers, False)

    def test_no_beat_at_all_is_a_stop(self):
        answers, said = self.look(lambda now: None)
        self.assertIs(answers, False)
        self.assertIn('backdrop: the last beat none', said)

    def test_a_beat_that_stops_within_the_look_is_a_stop(self):
        # beats for the first second, then none: 9 s old at the end
        def tick(now):
            if now <= self.START + 1:
                self.beat(now)
            else:
                self.write('')
        answers, said = self.look(tick)
        self.assertIs(answers, False, said)


if __name__ == '__main__':
    unittest.main()
