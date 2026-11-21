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

"""tools/ci/dark_switch_check.py without Windows or an engine: its reading
of the log that tools/ci/dark-switch-check.livecodescript writes, its
steps against a stand-in for the engine (one that follows the appearance,
0.2.7 as the check measured it, and one for each half of the fix alone),
the engine source it guards and the workflows that run it.

  python3 -m unittest discover -s tools/ci/tests
"""

import ctypes
import importlib.util
import os
import re
import shutil
import sys
import tempfile
import time
import unittest
from unittest import mock

import yaml

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
SPEC = importlib.util.spec_from_file_location('dark_switch_check',
                                              os.path.join(ROOT, 'tools', 'ci', 'dark_switch_check.py'))
dsc = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(dsc)

DARK = ((32, 32, 32), (255, 255, 255))
LIGHT = ((225, 225, 225), (0, 0, 0))
# What 0.2.7 drew after a switch to dark while it ran: the kept light
# background under the dark appearance's white words
FAULT = ((240, 240, 240), (255, 255, 255))
# A field with a white background of its own and no text colour: black
# words, as LiveCode Community drew them; and what 0.2.8-dp.1 drew in the
# dark appearance (seth's Windows 11 PC, 2026-11-21): white on white
PAPER = ((255, 255, 255), (0, 0, 0))
WHITE_ON_WHITE = ((255, 255, 255), (255, 255, 255))
# A field with a dark background of its own and no text colour, in each
# appearance
NIGHT = {'dark': ((40, 48, 64), (255, 255, 255)), 'light': ((40, 48, 64), (0, 0, 0))}
# The fields and buttons whose effective foregroundColor the script logs
# (kWords: not the menus)
WORDS = ('Plain',) + dsc.LEGACY + dsc.DARK_OWN


def measure(label, control, pair):
    return 'MEASURE %s %s face=%d,%d,%d ink=%d,%d,%d size=160x32' % ((label, control) + pair[0] + pair[1])


def pairs(pair, appearance, legacy=PAPER):
    """{control: (face, ink)}: pair for the controls that follow the
    appearance, legacy for LEGACY, and DARK_OWN's for the appearance."""
    out = {c: pair for c in dsc.FOLLOWING}
    out.update({c: legacy for c in dsc.LEGACY})
    out.update({c: NIGHT[appearance] for c in dsc.DARK_OWN})
    return out


def counted(appearance):
    """How many checks of a step's drawing and effective colours there are
    in an appearance."""
    return len(dsc.judged(appearance)) + len([c for c in dsc.judged(appearance) if c not in dsc.FOLLOWING])


def log_of(label, pair, appearance, changed=1, noticed=0, legacy=PAPER, drawn_in=None):
    """A step's log; appearance is the one the script reports, drawn_in
    (the same when not given) the one the controls are drawn in."""
    drawn = pairs(pair, drawn_in or appearance, legacy)
    return (['NOTICED %s %d' % (label, noticed)] + [measure(label, c, drawn[c]) for c in dsc.CONTROLS]
            + ['EFFECTIVE %s %s %d,%d,%d' % ((label, c) + drawn[c][1]) for c in WORDS]
            + ['APPEARANCE %s %s' % (label, appearance), 'CHANGED %s %d' % (label, changed), 'MEASURED ' + label])


def on_screen(label, control, pair):
    return measure(label, control, pair).replace('MEASURE', 'SCREEN', 1)


def screen(log, label, appearance, covered=None, need_screen=True):
    """dsc.check_screen's checks, as steps() gives them, and its lines."""
    out, lines = [], []
    dsc.check_screen(log, 'a run', label, appearance, covered, need_screen,
                     lambda name, what, ok, detail: out.append((what, ok, detail)), lines)
    return out, lines


def steps(log, label, appearance, switched=True, told=False):
    out = []
    dsc.check_step(log, 'a run', label, appearance, switched,
                   lambda name, what, ok, detail: out.append((what, ok, detail)), told)
    return out


def failed(results):
    return [what for what, ok, _ in results if not ok]


class Judge(unittest.TestCase):
    def test_each_appearance_drawn_as_itself_passes(self):
        self.assertTrue(dsc.judge('dark', *DARK)[0])
        self.assertTrue(dsc.judge('light', *LIGHT)[0])
        # (a combo box: black on white)
        self.assertTrue(dsc.judge('light', (255, 255, 255), (0, 0, 0))[0])

    def test_the_fault_fails(self):
        ok, detail = dsc.judge('dark', *FAULT)
        self.assertFalse(ok)
        self.assertIn('a light face in the dark appearance', detail)
        self.assertIn('240,240,240', detail)

    def test_the_other_way_round_fails(self):
        ok, detail = dsc.judge('light', (32, 32, 32), (0, 0, 0))
        self.assertFalse(ok)
        self.assertIn('a dark face in the light appearance', detail)

    def test_an_ink_that_does_not_stand_out_fails(self):
        self.assertFalse(dsc.judge('light', (240, 240, 240), (255, 255, 255))[0])
        self.assertFalse(dsc.judge('dark', (32, 32, 32), (70, 70, 70))[0])

    def test_luma(self):
        self.assertEqual(dsc.luma((255, 255, 255)), 255)
        self.assertEqual(dsc.luma((0, 0, 0)), 0)
        self.assertGreater(dsc.luma((0, 255, 0)), dsc.luma((255, 0, 0)))


class Legacy(unittest.TestCase):
    """The colours of an older stack: its words stay readable."""

    def test_dark_words_on_a_light_colour_of_its_own_pass(self):
        ok, detail = dsc.judge_legacy(*PAPER)
        self.assertTrue(ok, detail)
        self.assertTrue(dsc.judge_legacy((240, 242, 246), (0, 0, 0))[0])
        self.assertTrue(dsc.judge_legacy((225, 229, 236), (28, 34, 46))[0])

    def test_white_on_white_fails(self):
        ok, detail = dsc.judge_legacy(*WHITE_ON_WHITE)
        self.assertFalse(ok)
        self.assertIn('light words on its light colour', detail)
        self.assertFalse(dsc.judge_legacy((240, 242, 246), (255, 255, 255))[0])

    def test_its_colour_must_be_its_face(self):
        ok, detail = dsc.judge_legacy((32, 32, 32), (255, 255, 255))
        self.assertFalse(ok)
        self.assertIn('its light colour is not its face', detail)

    def test_the_effective_colour_is_the_colour_of_the_words(self):
        self.assertTrue(dsc.judge_effective('Paper', (0, 0, 0))[0])
        self.assertFalse(dsc.judge_effective('Paper', (255, 255, 255))[0])
        self.assertTrue(dsc.judge_effective('Night', (255, 255, 255))[0])
        self.assertFalse(dsc.judge_effective('Night', (0, 0, 0))[0])

    def test_a_dark_colour_of_its_own_is_judged_in_the_dark_appearance_only(self):
        self.assertEqual(dsc.judged('dark'), dsc.CONTROLS)
        self.assertEqual(dsc.judged('light'), dsc.FOLLOWING + dsc.LEGACY)
        self.assertTrue(dsc.judge_control('Night', 'dark', *NIGHT['dark'])[0])
        # the dark appearance's words left as they were: on its own dark
        # colour, white
        self.assertFalse(dsc.judge_control('Night', 'dark', (40, 48, 64), (0, 0, 0))[0])

    def test_the_sets_are_apart(self):
        self.assertEqual(len(set(dsc.CONTROLS)), len(dsc.CONTROLS))
        self.assertEqual(dsc.CONTROLS, dsc.FOLLOWING + dsc.LEGACY + dsc.DARK_OWN)

    def test_a_step_of_the_release_fails_each_older_control_in_the_dark(self):
        got = steps(log_of('quiet-dark', DARK, 'dark', legacy=WHITE_ON_WHITE), 'quiet-dark', 'dark')
        self.assertEqual(failed(got), ['%s is drawn for the dark appearance' % c for c in dsc.LEGACY]
                         + ['the effective foregroundColor of %s is the colour of its words' % c
                            for c in dsc.LEGACY])
        # and in the light appearance, where it drew them black, nothing
        got = steps(log_of('quiet-light', LIGHT, 'light'), 'quiet-light', 'light')
        self.assertEqual(failed(got), [])

    def test_an_effective_colour_that_was_not_logged_fails_rather_than_passes(self):
        log = [x for x in log_of('quiet-dark', DARK, 'dark') if not x.startswith('EFFECTIVE quiet-dark Paper ')]
        got = steps(log, 'quiet-dark', 'dark')
        self.assertEqual([(w, d) for w, ok, d in got if not ok],
                         [('the effective foregroundColor of Paper is the colour of its words', 'not logged')])

    def test_an_effective_line_is_read_for_its_own_step(self):
        log = ['EFFECTIVE a Paper 0,0,0', 'EFFECTIVE b Paper 255,255,255', 'EFFECTIVE a Night 1,2']
        self.assertEqual(dsc.effective(log, 'a'), {'Paper': (0, 0, 0)})
        self.assertEqual(dsc.effective(log, 'b'), {'Paper': (255, 255, 255)})


class Steps(unittest.TestCase):
    def test_a_good_step_passes_every_check(self):
        got = steps(log_of('quiet-dark', DARK, 'dark'), 'quiet-dark', 'dark')
        self.assertEqual(failed(got), [])
        self.assertEqual(len(got), counted('dark') + 2)

    def test_the_start_asks_for_no_message(self):
        got = steps(log_of('start', LIGHT, 'light', changed=0), 'start', 'light', switched=False)
        self.assertEqual(failed(got), [])
        self.assertEqual(len(got), counted('light') + 1)

    def test_the_fault_fails_each_control(self):
        got = steps(log_of('quiet-dark', FAULT, 'dark'), 'quiet-dark', 'dark')
        self.assertEqual(failed(got), ['%s is drawn for the dark appearance' % c for c in dsc.FOLLOWING])

    def test_one_control_is_enough_to_fail(self):
        log = log_of('quiet-dark', DARK, 'dark')
        log[2] = measure('quiet-dark', 'Option', FAULT)
        self.assertEqual(failed(steps(log, 'quiet-dark', 'dark')), ['Option is drawn for the dark appearance'])

    def test_a_control_that_was_not_measured_fails_rather_than_passes(self):
        log = [x for x in log_of('quiet-dark', DARK, 'dark') if ' Combo ' not in x]
        got = steps(log, 'quiet-dark', 'dark')
        self.assertEqual([(w, d) for w, ok, d in got if not ok],
                         [('Combo is drawn for the dark appearance', 'not measured')])

    def test_another_steps_measurements_are_not_taken_for_this_one(self):
        log = log_of('start', DARK, 'dark')
        self.assertEqual(len(failed(steps(log, 'quiet-dark', 'dark'))), counted('dark') + 2)

    def test_no_message_after_a_switch_fails(self):
        got = steps(log_of('quiet-dark', DARK, 'dark', changed=0), 'quiet-dark', 'dark')
        self.assertEqual(failed(got), ['the stack was sent systemAppearanceChanged'])

    def test_the_wrong_appearance_in_script_fails(self):
        got = steps(log_of('quiet-dark', DARK, 'light', drawn_in='dark'), 'quiet-dark', 'dark')
        self.assertEqual(failed(got), ['the systemAppearance is dark'])

    def test_a_told_switch_asks_for_the_message_before_anything_was_measured(self):
        notice = 'Windows\' notice alone sent systemAppearanceChanged'
        got = steps(log_of('told-dark', DARK, 'dark', changed=1, noticed=1), 'told-dark', 'dark', told=True)
        self.assertEqual(failed(got), [])
        self.assertEqual(len(got), counted('dark') + 3)
        # the message came, but only once the script had measured: not the notice's doing
        got = steps(log_of('told-dark', DARK, 'dark', changed=1, noticed=0), 'told-dark', 'dark', told=True)
        self.assertEqual(failed(got), [notice])
        # a quiet switch is not asked for it
        got = steps(log_of('quiet-dark', DARK, 'dark', changed=1, noticed=0), 'quiet-dark', 'dark')
        self.assertNotIn(notice, [what for what, _, _ in got])
        # a log without the line fails rather than passes
        log = [x for x in log_of('told-dark', DARK, 'dark', noticed=1) if not x.startswith('NOTICED')]
        self.assertEqual([(w, d) for w, ok, d in steps(log, 'told-dark', 'dark', told=True) if not ok],
                         [(notice, 'not logged')])

    def test_a_notice_that_changed_nothing_must_send_no_message(self):
        nothing = 'a notice that changed nothing sent no systemAppearanceChanged'
        got = steps(log_of('told-again', DARK, 'dark', changed=0), 'told-again', 'dark', switched=False, told=True)
        self.assertEqual(failed(got), [])
        self.assertIn(nothing, [what for what, _, _ in got])
        got = steps(log_of('told-again', DARK, 'dark', changed=1), 'told-again', 'dark', switched=False, told=True)
        self.assertEqual(failed(got), [nothing])
        log = [x for x in log_of('told-again', DARK, 'dark', changed=0) if not x.startswith('CHANGED')]
        self.assertEqual(failed(steps(log, 'told-again', 'dark', switched=False, told=True)), [nothing])

    def test_the_title_bar_is_checked_where_dwm_says_and_reported_where_it_does_not(self):
        for appearance, dark, ok in (('dark', True, True), ('light', False, True),
                                     ('dark', False, False), ('light', True, False)):
            out, lines = [], []
            dsc.check_title_bar('a run, x', 'the title bar is %s' % appearance, appearance, dark,
                                lambda name, what, good, detail: out.append((name, what, good, detail)), lines)
            self.assertEqual(lines, [])
            self.assertEqual(out, [('a run, x', 'the title bar is %s' % appearance, ok,
                                    'DWM says it is %s' % ('dark' if dark else 'light'))])
        out, lines = [], []
        dsc.check_title_bar('a run, x', 'the title bar is dark', 'dark', None, out.append, lines)
        self.assertEqual(out, [])
        self.assertEqual(lines, ['INFO a run, x: the title bar is dark: DWM does not say'])

    def test_the_snapshots_checks_do_not_read_the_screens_lines(self):
        log = log_of('quiet-dark', DARK, 'dark') + [on_screen('quiet-dark', 'Push', FAULT)]
        self.assertEqual(failed(steps(log, 'quiet-dark', 'dark')), [])
        self.assertEqual(dsc.measurements(log, 'quiet-dark', 'SCREEN'), {'Push': FAULT})
        self.assertEqual(dsc.measurements(log, 'quiet-dark'), pairs(DARK, 'dark'))

    def test_a_line_that_is_not_a_measurement_is_not_read_as_one(self):
        self.assertEqual(dsc.measurements(['MEASURE x Push face=1,2 ink=3,4,5 size=1x1', 'MEASURED x'], 'x'), {})
        self.assertEqual(dsc.measurements([measure('x', 'Push', DARK)], 'x'), {'Push': DARK})


class TheScreen(unittest.TestCase):
    """What the screen showed is checked as the snapshots are, and a screen
    that could not be read does not pass for one that was."""

    def seen(self, label, pair, appearance='dark', legacy=PAPER):
        drawn = pairs(pair, appearance, legacy)
        return [on_screen(label, c, drawn[c]) for c in dsc.CONTROLS]

    def test_each_control_on_the_screen_is_a_check(self):
        got, lines = screen(self.seen('quiet-dark', DARK), 'quiet-dark', 'dark')
        self.assertEqual([(what, ok) for what, ok, _ in got],
                         [('on the screen %s is drawn for the dark appearance' % c, True) for c in dsc.CONTROLS])
        self.assertEqual(lines, [])

    def test_the_fault_on_the_screen_fails(self):
        # the snapshots are right and the window shows the fault: the check fails
        log = log_of('quiet-dark', DARK, 'dark') + self.seen('quiet-dark', FAULT)
        self.assertEqual(failed(steps(log, 'quiet-dark', 'dark')), [])
        got, _ = screen(log, 'quiet-dark', 'dark')
        self.assertEqual(failed(got), ['on the screen %s is drawn for the dark appearance' % c for c in dsc.FOLLOWING])
        self.assertIn('240,240,240', got[0][2])
        # with or without --need-screen: a reading that was taken always counts
        self.assertEqual(failed(screen(log, 'quiet-dark', 'dark', need_screen=False)[0]), failed(got))

    def test_one_control_is_enough_to_fail(self):
        log = self.seen('quiet-dark', DARK)
        log[1] = on_screen('quiet-dark', 'Option', FAULT)
        self.assertEqual(failed(screen(log, 'quiet-dark', 'dark')[0]),
                         ['on the screen Option is drawn for the dark appearance'])

    def test_the_snapshots_do_not_stand_in_for_the_screen(self):
        got, _ = screen(log_of('quiet-dark', DARK, 'dark'), 'quiet-dark', 'dark')
        self.assertEqual([(ok, detail) for _, ok, detail in got], [(False, 'not read')] * len(dsc.CONTROLS))

    def test_another_steps_readings_are_not_taken_for_this_one(self):
        got, _ = screen(self.seen('start', DARK), 'quiet-dark', 'dark')
        self.assertEqual(len(failed(got)), len(dsc.CONTROLS))

    def test_a_control_that_was_not_read_fails_when_the_screen_is_needed_and_is_reported_when_not(self):
        log = [x for x in self.seen('quiet-dark', DARK) if ' Combo ' not in x]
        got, lines = screen(log, 'quiet-dark', 'dark')
        self.assertEqual([(what, detail) for what, ok, detail in got if not ok],
                         [('on the screen Combo is drawn for the dark appearance', 'not read')])
        self.assertEqual(lines, [])
        got, lines = screen(log, 'quiet-dark', 'dark', need_screen=False)
        self.assertEqual(failed(got), [])
        self.assertEqual(len(got), len(dsc.CONTROLS) - 1)
        self.assertEqual(lines, ['INFO a run, quiet-dark: on the screen Combo is drawn for the dark appearance: '
                                 'not read'])

    def test_with_another_window_over_the_stacks_nothing_read_is_judged(self):
        # what was read then is that window: neither a pass nor the controls' fault
        for seen in (self.seen('quiet-dark', DARK), self.seen('quiet-dark', FAULT)):
            got, lines = screen(seen, 'quiet-dark', 'dark', covered='ConsoleWindowClass')
            self.assertEqual(got, [('the screen shows the stack\'s window', False,
                                    'a window of the class ConsoleWindowClass is over it there: '
                                    'the screen was not read')])
            self.assertEqual(lines, [])
            got, lines = screen(seen, 'quiet-dark', 'dark', covered='ConsoleWindowClass', need_screen=False)
            self.assertEqual(got, [])
            self.assertEqual(lines, ['INFO a run, quiet-dark: the screen shows the stack\'s window: a window of '
                                     'the class ConsoleWindowClass is over it there: the screen was not read'])

    def test_the_points_asked_are_the_middle_and_near_each_corner(self):
        self.assertEqual(dsc.inside_points(0, 0, 360, 200),
                         [(180, 100), (8, 8), (351, 8), (8, 191), (351, 191)])
        # every point is inside, in a rectangle too small for the inset too
        for rect in ((0, 0, 360, 200), (0, 0, 10, 6), (0, 0, 1, 1), (5, 7, 25, 9)):
            for x, y in dsc.inside_points(*rect):
                self.assertTrue(rect[0] <= x < rect[2] and rect[1] <= y < rect[3], (rect, x, y))


class FakeUser32:
    """user32 as Windows.covering uses it: a window whose inside is at
    (120, 190) on the screen and 360 by 200, and `others`, each a (rect on
    the screen, root window, class) that is above it."""

    def __init__(self, others=(), size=(360, 200)):
        self.others, self.size, self.asked = list(others), size, []

    def GetClientRect(self, hwnd, ref):
        if not self.size:
            return False
        ref._obj.left, ref._obj.top, ref._obj.right, ref._obj.bottom = (0, 0) + self.size
        return True

    def ClientToScreen(self, hwnd, ref):
        ref._obj.x += 120
        ref._obj.y += 190
        return True

    def WindowFromPoint(self, point):
        self.asked.append((point.x, point.y))
        for (left, top, right, bottom), child, _, _ in self.others:
            if left <= point.x < right and top <= point.y < bottom:
                return child
        return 1234

    def GetAncestor(self, hwnd, flag):
        assert flag == 2
        for _, child, root, _ in self.others:
            if child == hwnd:
                return root
        return hwnd

    def GetClassNameW(self, hwnd, buffer, size):
        for _, _, root, name in self.others:
            if root == hwnd:
                buffer.value = name
        return len(buffer.value)


class Covering(unittest.TestCase):
    """Windows.covering, with user32 stood in for (the class itself needs
    Windows; its method only needs these five calls)."""

    def covering(self, user32):
        from ctypes import wintypes
        w = mock.Mock(ct=ctypes, wt=wintypes, user32=user32)
        return dsc.Windows.covering(w, 1234)

    def test_the_window_itself_everywhere_is_not_covered(self):
        user32 = FakeUser32()
        self.assertIsNone(self.covering(user32))
        self.assertEqual(user32.asked, [(x + 120, y + 190) for x, y in dsc.inside_points(0, 0, 360, 200)])

    def test_a_control_of_the_window_itself_is_the_window(self):
        # (a child window's root is the window)
        self.assertIsNone(self.covering(FakeUser32([((0, 0, 2000, 2000), 77, 1234, 'MCWinClassW')])))

    def test_a_window_over_the_middle_is_named(self):
        user32 = FakeUser32([((250, 250, 350, 330), 55, 50, 'ConsoleWindowClass')])
        self.assertEqual(self.covering(user32), 'ConsoleWindowClass')

    def test_a_window_over_one_corner_only_is_named(self):
        # (it would be over the Push button, and was not seen while only the middle was asked)
        user32 = FakeUser32([((0, 0, 200, 230), 55, 50, 'Shell_TrayWnd')])
        self.assertEqual(self.covering(user32), 'Shell_TrayWnd')
        user32 = FakeUser32([((400, 350, 1024, 768), 60, 60, '')])
        self.assertEqual(self.covering(user32), 'with no name')

    def test_a_window_whose_place_cannot_be_told_is_not_called_covered(self):
        self.assertIsNone(self.covering(FakeUser32(size=())))


class ThePlan(unittest.TestCase):
    def test_the_engine_starts_in_each_appearance(self):
        self.assertEqual(sorted(start for _, start, _ in dsc.RUNS), ['dark', 'light'])

    def test_each_appearance_is_switched_to_with_and_without_the_notice(self):
        seen, same = set(), []
        for _, start, run_steps in dsc.RUNS:
            now = start
            for label, appearance, told in run_steps:
                if appearance == now:
                    # (without the notice, a step that set the appearance
                    # Windows already had would check nothing)
                    self.assertTrue(told, label)
                    same.append(label)
                else:
                    seen.add((appearance, told))
                now = appearance
        self.assertEqual(seen, {('dark', False), ('light', False), ('dark', True), ('light', True)})
        # and one notice that changes nothing
        self.assertEqual(same, ['told-again'])

    def test_the_labels_of_a_run_are_its_own(self):
        for _, _, run_steps in dsc.RUNS:
            labels = ['start'] + [label for label, _, _ in run_steps]
            self.assertEqual(len(labels), len(set(labels)))
            self.assertNotIn('quit', labels)

    def test_the_window_is_shown_and_the_screen_is_read_where_it_is(self):
        # (the first runs read the runner's console at every step: the stack
        # is made invisible, and going to it does not show it)
        with open(os.path.join(ROOT, 'tools', 'ci', 'dark-switch-check.livecodescript'), encoding='utf-8') as f:
            script = f.read()
        make = script[script.index('private command makeStack'):script.index('end makeStack')]
        self.assertIn('create invisible stack kStack', make)
        self.assertLess(make.index('go stack kStack'), make.index('show stack kStack'))
        # counted from the window itself, wherever it is: the control's
        # rect (measureRect) is the card's, which is the window's
        self.assertIn('import snapshot from rect (measureRect(pName)) '
                      'of window (the windowID of stack kStack)', script)
        self.assertIn('put the rect of control pName of stack kStack into tRect', script)
        self.assertNotIn('globalLoc', script)

    def test_the_script_measures_the_controls_the_check_reads(self):
        with open(os.path.join(ROOT, 'tools', 'ci', 'dark-switch-check.livecodescript'), encoding='utf-8') as f:
            script = f.read()
        self.assertIn('constant kControls = "%s"' % ','.join(dsc.CONTROLS), script)
        self.assertIn('constant kWords = "%s"' % ','.join(WORDS), script)
        # the buttons and menus as the check always measured them, the
        # others from the card, where what their words are on is
        self.assertIn('constant kOwnSnapshot = "Push,Option,Combo"', script)
        self.assertIn('import snapshot from rect (measureRect(pName)) of card 1 of stack kStack', script)

    def test_the_checked_check_box_is_measured_past_its_box(self):
        # Tick is checked, and its box is drawn by the theme in colours of
        # its own: measured with it, the box could be the ink while white
        # words vanished on the white (seth's PC, 2026-11-21: measured past
        # it, face and ink were both 255,255,255 on 0.2.8-dp.1)
        with open(os.path.join(ROOT, 'tools', 'ci', 'dark-switch-check.livecodescript'), encoding='utf-8') as f:
            script = f.read()
        self.assertIn('Tick', dsc.LEGACY)
        self.assertIn('set the style of button "Tick" to "checkbox"', script)
        self.assertIn('set the hilite of button "Tick" to true', script)
        self.assertIn('set the opaque of button "Tick" to true', script)
        # its label in the middle, the box and the space after it left out
        self.assertIn('set the textAlign of button "Tick" to "center"', script)
        self.assertIn('constant kBox = 24', script)
        self.assertIn('if the style of control pName of stack kStack is "checkbox" then\n'
                      '      add kBox to item 1 of tRect', script)
        # the card's snapshot and the screen's both use it
        self.assertEqual(script.count('import snapshot from rect (measureRect(pName))'), 2)
        # and it fits in the window
        rect = re.search(r'set the rect of button "Tick" to (\d+),(\d+),(\d+),(\d+)', script).groups()
        stack = re.search(r'set the rect of stack kStack to (\d+),(\d+),(\d+),(\d+)', script).groups()
        self.assertLessEqual(int(rect[3]), int(stack[3]) - int(stack[1]))
        self.assertLessEqual(int(rect[2]), int(stack[2]) - int(stack[0]))

    def test_only_the_older_stacks_controls_have_colours_and_none_a_text_colour(self):
        # No colour of its own on the stack or on a control that follows
        # the appearance: it would hide what the appearance draws. The
        # older stack's controls (and the group of one) have a background
        # colour of their own and no text colour, which the engine gives
        with open(os.path.join(ROOT, 'tools', 'ci', 'dark-switch-check.livecodescript'), encoding='utf-8') as f:
            script = f.read()
        sets = re.findall(r'(?im)^\s*set the (\w*colou?r\w*|\w*pattern\w*) of (\w+) "?(\w+)"?', script)
        self.assertEqual(sorted((prop, kind, name) for prop, kind, name in sets),
                         sorted([('backgroundColor', 'field', 'Paper'), ('backgroundColor', 'group', 'Panel'),
                                 ('backgroundColor', 'button', 'Key'), ('backgroundColor', 'button', 'Tick'),
                                 ('backgroundColor', 'field', 'Night'), ('backgroundColor', 'field', 'Shade'),
                                 ('backgroundColor', 'line', '1')]))
        self.assertIn('create field "Label" in group "Panel"', script)
        self.assertIn('set the backgroundColor of line 1 of field "Shade" to "40,48,64"', script)
        code = re.sub(r'/\*.*?\*/', '', script, flags=re.S)
        code = '\n'.join(x for x in code.split('\n') if not x.lstrip().startswith('--'))
        self.assertIn('the effective foregroundColor of control pName of stack kStack', code)
        self.assertIn('the effective foregroundColor of line 1 of field pName of stack kStack', code)
        self.assertIsNone(re.search(r'(?i)(foreground|text)colou?r', code.replace(
            'the effective foregroundColor of control', '').replace(
            'the effective foregroundColor of line 1 of field', '')))

    def test_the_dark_line_fills_what_is_measured(self):
        # Shade's words are on its line's dark colour, and it is measured
        # like Night: the line must be most of what is read, inside the
        # inset (no margins, one line as tall as the field's inside, which
        # its border of 2 leaves)
        with open(os.path.join(ROOT, 'tools', 'ci', 'dark-switch-check.livecodescript'), encoding='utf-8') as f:
            script = f.read()
        self.assertIn('Shade', dsc.DARK_OWN)
        self.assertIn('set the margins of field "Shade" to "0,0,0,0"', script)
        self.assertIn('set the fixedLineHeight of field "Shade" to true', script)
        rect = [int(v) for v in re.search(r'set the rect of field "Shade" to (\d+),(\d+),(\d+),(\d+)', script).groups()]
        height = int(re.search(r'set the textHeight of field "Shade" to (\d+)', script).group(1))
        self.assertEqual(height, rect[3] - rect[1] - 2 * 2)
        stack = [int(v) for v in re.search(r'set the rect of stack kStack to (\d+),(\d+),(\d+),(\d+)', script).groups()]
        self.assertLessEqual(rect[3], stack[3] - stack[1])
        # its effective foregroundColor is its line's, the colour its words
        # are drawn in
        self.assertIn('constant kLineWords = "Shade"', script)
        self.assertIn('logLine "EFFECTIVE" && tLabel && tName && effectiveWords(tName)', script)


# A stand-in for the engine running the script: it speaks the script's lines.
# What every one does as the Windows theme does: the light appearance's faces
# and a combo box's are drawn for the appearance read; a button's and an
# option menu's in the dark are filled with the colour kept. FAKE_MODE says
# when the kept colour, the title bar and the message follow a change:
#   good         when the appearance is read and found changed, and when a
#                notice finds it changed: once for each change
#   deaf         never after the start: 0.2.7, as the check measured it
#   reads-only   when the appearance is read, and never on a notice: the fix's
#                first half alone
#   notice-only  on every notice, changed or not, and never by reading: what
#                0.2.7's code was written to do
# A field (Plain) is drawn for the appearance read, as the combo box is.
# FAKE_WORDS says what the words of the older stack's controls (LEGACY) are:
#   black        LiveCode Community's, in both appearances: the fix
#   white        the appearance's: white in the dark one, 0.2.8-dp.1 as it
#                was measured on seth's PC
# and a field with a dark colour of its own has the appearance's words.
FAKE_ENGINE = r"""
import os, sys, time
log, go, state, mode = (os.environ[x] for x in ('OXT_DARK_LOG', 'OXT_DARK_GO', 'FAKE_STATE', 'FAKE_MODE'))
words = os.environ.get('FAKE_WORDS', 'black')
FACE = {'dark': '32,32,32', 'light': '225,225,225'}
INK = {'dark': '255,255,255', 'light': '0,0,0'}
WORDS = {'dark': '0,0,0' if words == 'black' else '255,255,255', 'light': '0,0,0'}
def now():
    while True:
        try:
            appearance, told = open(state).read().split()
            return appearance, int(told)
        except (OSError, ValueError):
            time.sleep(0.005)
def out(line):
    with open(log, 'a') as f:
        f.write(line + '\n')
def replace(new, path):
    # Windows refuses to replace a file that the other side has open just then
    end = time.time() + 5
    while True:
        try:
            return os.replace(new, path)
        except PermissionError:
            if time.time() > end:
                raise
            time.sleep(0.005)
def follow(live):
    global kept
    kept = live
    with open(state + '.title.new', 'w') as f:
        f.write(live + '\n')
    replace(state + '.title.new', state + '.title')
def notices_taken():
    # a notice that has come since the last look: 1 when a message is sent
    global notices
    live, told = now()
    if told == notices:
        return 0
    notices = told
    if mode == 'notice-only' or (mode == 'good' and kept != live):
        follow(live)
        return 1
    return 0
kept, notices = now()
follow(kept)
out('WINDOW DarkSwitch 1234')
n = 0
while True:
    n += 1
    out('STEP %d' % n)
    changed = 0
    path = '%s.%d' % (go, n)
    end = time.time() + 20
    while not os.path.exists(path) and time.time() < end:
        changed += notices_taken()
        time.sleep(0.01)
    time.sleep(0.05)
    label = open(path).read().split()[0] if os.path.exists(path) else 'quit'
    if label == 'quit':
        break
    changed += notices_taken()
    out('NOTICED %s %d' % (label, changed))
    live = now()[0]
    if mode in ('good', 'reads-only') and kept != live:
        follow(live)
        changed += 1
    others = (('Plain', FACE[live], INK[live]), ('Paper', '255,255,255', WORDS[live]),
              ('Label', '240,242,246', WORDS[live]), ('Key', '225,229,236', WORDS[live]),
              ('Tick', '255,255,255', WORDS[live]), ('Night', '40,48,64', INK[live]),
              ('Shade', '40,48,64', INK[live]))
    for word in ('MEASURE', 'SCREEN'):
        for control in ('Push', 'Option', 'Combo'):
            face = FACE[live] if live == 'light' or control == 'Combo' else FACE[kept]
            out('%s %s %s face=%s ink=%s size=160x32' % (word, label, control, face, INK[live]))
        for control, face, ink in others:
            out('%s %s %s face=%s ink=%s size=160x32' % (word, label, control, face, ink))
    for control, face, ink in others:
        out('EFFECTIVE %s %s %s' % (label, control, ink))
    out('APPEARANCE %s %s' % (label, live))
    out('CHANGED %s %d' % (label, changed))
    out('MEASURED %s' % label)
out('DONE')
"""


def patiently(action, wait=5):
    """What `action` returns. Windows refuses to replace a file, or to open
    one, while the other side has it open or is replacing it: the stand-in
    engine and the test share two small files, so each tries again for a
    while (PermissionError, as on the Windows runner on 10 November 2026)."""
    end = time.time() + wait
    while True:
        try:
            return action()
        except PermissionError:
            if time.time() > end:
                raise
            time.sleep(0.005)


class FakeWindows:
    def __init__(self, state):
        self.state, self.appearance, self.told, self.forwarded = state, None, 0, []
        # (the class of a window over the stack's, and the appearance during which it is)
        self.over, self.over_while = None, None

    def write(self):
        with open(self.state + '.new', 'w') as f:
            f.write('%s %d\n' % (self.appearance, self.told))
        patiently(lambda: os.replace(self.state + '.new', self.state))

    def set_appearance(self, appearance):
        self.appearance = appearance
        self.write()

    def tell(self, pid):
        self.told += 1
        self.write()
        return [('MCWinClass', False, True), ('MCWinClassW', True, True)]

    def forward(self, hwnd):
        self.forwarded.append(hwnd)
        return True

    def covering(self, hwnd):
        return self.over if self.appearance == self.over_while else None

    def dark_title_bar(self, hwnd):
        def read():
            with open(self.state + '.title') as f:
                return f.read().strip() == 'dark'
        try:
            return patiently(read)
        except OSError:
            return None


class Patiently(unittest.TestCase):
    """The stand-in's file sharing on Windows."""

    def test_a_refusal_is_tried_again(self):
        calls = []

        def action():
            calls.append(1)
            if len(calls) < 3:
                raise PermissionError(13, 'Access is denied')
            return 'done'
        self.assertEqual(patiently(action), 'done')
        self.assertEqual(len(calls), 3)

    def test_a_refusal_that_stays_is_raised(self):
        def action():
            raise PermissionError(13, 'Access is denied')
        with self.assertRaises(PermissionError):
            patiently(action, wait=0.05)

    def test_another_error_is_raised_at_once(self):
        calls = []

        def action():
            calls.append(1)
            raise FileNotFoundError(2, 'No such file')
        with self.assertRaises(FileNotFoundError):
            patiently(action)
        self.assertEqual(len(calls), 1)

    def test_the_stand_in_engine_tries_again_too(self):
        self.assertIn('except PermissionError:', FAKE_ENGINE)
        self.assertNotIn('os.replace(state', FAKE_ENGINE)


class TheSteps(unittest.TestCase):
    """dark_switch_check.run_engine with the stand-in engine."""

    BUTTONS = ['%s is drawn for the dark appearance' % c for c in ('Push', 'Option')]
    SEEN = ['on the screen ' + x for x in BUTTONS]
    STEPS = sum(1 + len(run_steps) for _, _, run_steps in dsc.RUNS)
    # the controls judged on the screen over every step of every run
    SCREENED = sum(len(dsc.judged(start)) + sum(len(dsc.judged(x[1])) for x in run_steps)
                   for _, start, run_steps in dsc.RUNS)
    MESSAGE = 'the stack was sent systemAppearanceChanged'
    NOTICE = 'Windows\' notice alone sent systemAppearanceChanged'
    NOTHING = 'a notice that changed nothing sent no systemAppearanceChanged'

    def setUp(self):
        self.work = tempfile.mkdtemp(prefix='oxt-dark-test-')
        self.addCleanup(shutil.rmtree, self.work, True)
        self.fake = os.path.join(self.work, 'fake_engine.py')
        with open(self.fake, 'w') as f:
            f.write(FAKE_ENGINE)

    def run_all(self, mode, need_screen=True, over=None, engine=None, words='black'):
        lines, problems, results = [], [], []
        # (a folder of its own for each call: the engine's log and the
        # answers to its steps are files there, and a second run in one
        # test must not find the first one's)
        work = tempfile.mkdtemp(dir=self.work)
        self.windows = w = FakeWindows(os.path.join(work, 'state'))
        w.over, w.over_while = over, 'light'
        if engine is not None:
            with open(self.fake, 'w') as f:
                f.write(engine)
        with mock.patch.object(dsc, 'SCRIPT', self.fake), mock.patch.object(dsc, 'NOTICE_WAIT', 0.3), \
                mock.patch.dict(os.environ, {'FAKE_STATE': w.state, 'FAKE_MODE': mode, 'FAKE_WORDS': words}):
            for run, start, run_steps in dsc.RUNS:
                dsc.run_engine(w, sys.executable, work, run, start, run_steps, 20, lines, problems,
                               lambda name, what, ok, detail: results.append((name, what, ok)), need_screen)
        return lines, problems, results

    def failures(self, mode, **how):
        _, problems, results = self.run_all(mode, **how)
        self.assertEqual(problems, [])
        out = {}
        for name, what, ok in results:
            if not ok:
                out.setdefault(name, []).append(what)
        return out

    def test_an_engine_that_follows_the_appearance_passes(self):
        lines, problems, results = self.run_all('good')
        self.assertEqual(problems, [])
        self.assertEqual([x for x in results if not x[2]], [])
        # every step of every run was checked: the start and each switch
        names = sorted(set(name for name, _, _ in results))
        self.assertEqual(names, sorted('%s, %s' % (run, label) for run, _, run_steps in dsc.RUNS
                                       for label in ['start'] + [x[0] for x in run_steps]))
        self.assertTrue(any('with no notice' in x for x in lines))
        # the screen was checked at every step, each control, and nothing about it was only reported
        self.assertEqual(len([x for x in results if x[1].startswith('on the screen ')]), self.SCREENED)
        self.assertFalse(any('screen' in x for x in lines), lines)
        # the windows the notice went to are named, with how each takes its strings
        self.assertTrue(any('switched to light with Windows\' notice to 2 windows '
                            '(MCWinClass, ANSI, MCWinClassW, wide)' in x for x in lines), lines)
        self.assertTrue(any('told-again: still dark, with Windows\' notice' in x for x in lines), lines)
        # the title bar was checked after every step, and after each told switch before it
        whats = [what for _, what, _ in results]
        self.assertEqual(len([x for x in whats if x.startswith('the title bar is ')]),
                         sum(1 + len(run_steps) for _, _, run_steps in dsc.RUNS))
        self.assertEqual(sorted(x for x in whats if x.startswith('after Windows\' notice alone')),
                         ['after Windows\' notice alone the title bar is dark',
                          'after Windows\' notice alone the title bar is light'])
        self.assertEqual(whats.count(self.NOTICE), 2)
        self.assertEqual(whats.count(self.NOTHING), 1)
        # the window was put above the others once for each start of the engine
        self.assertEqual(self.windows.forwarded, [1234] * len(dsc.RUNS))

    def test_0_2_7_fails_as_it_was_measured(self):
        # (Windows Server 2025 with visual styles, 10 November 2026: light
        # grey buttons under white words after either switch to dark, no
        # message ever, a title bar that stayed as it started)
        self.assertEqual(self.failures('deaf'), {
            'starts dark, quiet-light': [self.MESSAGE, 'the title bar is light'],
            'starts light, quiet-dark': self.BUTTONS + [self.MESSAGE] + self.SEEN + ['the title bar is dark'],
            'starts light, told-light': [self.NOTICE, self.MESSAGE],
            'starts light, told-dark': ['after Windows\' notice alone the title bar is dark'] + self.BUTTONS
                                       + [self.NOTICE, self.MESSAGE] + self.SEEN + ['the title bar is dark'],
            'starts light, told-again': self.BUTTONS + self.SEEN + ['the title bar is dark'],
        })

    def test_0_2_8_dp_1_fails_an_older_stacks_words_in_the_dark_as_it_was_measured(self):
        # (seth's Windows 11 PC in dark mode, 21 November 2026: white words
        # on the white field, on the group's light grey and on the button's
        # own, and 255,255,255 their effective foregroundColor; the dark
        # field's words white, as they should be. A switch it followed)
        words = ['%s is drawn for the dark appearance' % c for c in dsc.LEGACY]
        effective = ['the effective foregroundColor of %s is the colour of its words' % c for c in dsc.LEGACY]
        seen = ['on the screen ' + x for x in words]
        dark_steps = ['starts dark, start', 'starts light, quiet-dark', 'starts light, told-dark',
                      'starts light, told-again']
        self.assertEqual(self.failures('good', words='white'),
                         {name: words + effective + seen for name in dark_steps})

    def test_an_engine_that_follows_only_by_reading_fails_what_the_notice_alone_must_do(self):
        self.assertEqual(self.failures('reads-only'), {
            'starts light, told-light': ['after Windows\' notice alone the title bar is light', self.NOTICE],
            'starts light, told-dark': ['after Windows\' notice alone the title bar is dark', self.NOTICE],
        })

    def test_an_engine_that_only_believes_the_notice_fails_the_quiet_switches(self):
        # (and sends its message for a notice that changed nothing)
        self.assertEqual(self.failures('notice-only'), {
            'starts dark, quiet-light': [self.MESSAGE, 'the title bar is light'],
            'starts light, quiet-dark': self.BUTTONS + [self.MESSAGE] + self.SEEN + ['the title bar is dark'],
            'starts light, told-again': [self.NOTHING],
        })

    def test_a_screen_that_shows_the_fault_fails_though_the_snapshots_are_right(self):
        # an engine whose snapshots follow the appearance and whose window does not
        engine = FAKE_ENGINE.replace("FACE[live] if live == 'light' or control == 'Combo' else FACE[kept]",
                                     "FACE[live] if word == 'MEASURE' or control == 'Combo' else FACE['light']")
        self.assertNotEqual(engine, FAKE_ENGINE)
        dark_steps = ['starts dark, start', 'starts light, quiet-dark', 'starts light, told-dark',
                      'starts light, told-again']
        self.assertEqual(self.failures('good', engine=engine), {name: self.SEEN for name in dark_steps})

    def test_an_engine_that_gives_no_reading_of_the_screen_fails_when_the_screen_is_needed(self):
        engine = FAKE_ENGINE.replace("for word in ('MEASURE', 'SCREEN'):", "for word in ('MEASURE',):")
        self.assertNotEqual(engine, FAKE_ENGINE)
        def seen(appearance):
            return ['on the screen %s is drawn for the %s appearance' % (c, appearance) for c in dsc.judged(appearance)]
        got = self.failures('good', engine=engine)
        self.assertEqual(len(got), self.STEPS)
        self.assertEqual(got['starts dark, start'], seen('dark'))
        self.assertEqual(got['starts light, told-light'], seen('light'))
        # without --need-screen it is reported at every step, and fails nothing
        lines, problems, results = self.run_all('good', need_screen=False, engine=engine)
        self.assertEqual((problems, [x for x in results if not x[2]]), ([], []))
        self.assertEqual(len([x for x in lines if x.endswith(': not read')]), self.SCREENED)

    def test_a_window_over_the_stacks_fails_the_steps_it_is_there_for(self):
        covered = 'the screen shows the stack\'s window'
        light_steps = ['starts dark, quiet-light', 'starts light, start', 'starts light, told-light']
        self.assertEqual(self.failures('good', over='ConsoleWindowClass'), {name: [covered] for name in light_steps})
        # and nothing read through it was judged: the other steps' readings were
        _, _, results = self.run_all('good', over='ConsoleWindowClass')
        self.assertEqual(len([x for x in results if x[1].startswith('on the screen ')]),
                         len(dsc.CONTROLS) * (self.STEPS - len(light_steps)))
        # without --need-screen: a line for each, no failure
        lines, problems, results = self.run_all('good', need_screen=False, over='ConsoleWindowClass')
        self.assertEqual((problems, [x for x in results if not x[2]]), ([], []))
        self.assertEqual(len([x for x in lines if 'ConsoleWindowClass is over it there' in x]), len(light_steps))

    def test_an_engine_that_goes_away_is_a_problem_not_a_pass(self):
        with open(self.fake, 'w') as f:
            f.write('import os\nopen(os.environ["OXT_DARK_LOG"], "a").write("ERROR it broke\\nDONE\\n")\n')
        _, problems, results = self.run_all('good')
        self.assertEqual(results, [])
        self.assertEqual(len([x for x in problems if 'did not reach step 1' in x]), len(dsc.RUNS))
        self.assertTrue(any('it broke' in x for x in problems))


def source(name):
    with open(os.path.join(ROOT, 'engine', 'src', name), encoding='utf-8', errors='replace') as f:
        return f.read()


def body(src, start):
    """A function's text, from its first line to the } that closes it."""
    i = src.index(start)
    return src[i:src.index('\n}\n', i)]


class EngineSource(unittest.TestCase):
    """What the check guards on Windows, read from the source (the check
    itself needs a Windows desktop): the engine acts on Windows' notice,
    and the colours it keeps for the appearance follow every reading of it
    besides."""

    def test_whoever_reads_the_appearance_tells_the_kept_colours(self):
        self.assertIn('MCWin32FollowSystemAppearance(t_is_dark);',
                      body(source('w32dc.cpp'), 'void MCScreenDC::getsystemappearance('))
        prop = source('w32dcs.cpp')
        prop = prop[prop.index('case kMCPlatformSystemPropertySystemAppearance:'):]
        self.assertIn('MCWin32FollowSystemAppearance(t_is_dark);', prop[:prop.index('break;')])

    def test_the_colours_are_set_at_once_and_the_windows_follow_from_the_message_loop(self):
        follow = body(source('w32dcs.cpp'), 'void MCWin32FollowSystemAppearance(bool p_is_dark)')
        self.assertLess(follow.index('MCWin32SetSystemColors(p_is_dark);'),
                        follow.index('PostMessageW(t_window, CWM_APPEARANCE_CHANGED'))
        # (not while the colours themselves are being set, and not before
        # they have been set once)
        self.assertRegex(follow, r's_system_colors_updating \|\| !s_system_colors_set \|\| '
                                 r's_system_colors_dark == p_is_dark\)\s*return;')

    def test_the_posted_message_and_windows_notice_do_the_same(self):
        proc = source('w32dcw32.cpp')
        self.assertRegex(proc, re.compile(
            r'case CWM_APPEARANCE_CHANGED:.{0,400}?MCWin32SystemAppearanceIsPending\(\)\)\s*'
            r'MCWin32SystemAppearanceChanged\(\);', re.S))
        self.assertRegex(proc, re.compile(
            r'if \(t_color_set && MCWin32SystemAppearanceIsStale\(\)\)\s*MCWin32SystemAppearanceChanged\(\);'))
        changed = body(proc, 'static void MCWin32SystemAppearanceChanged(void)')
        for what in ('MCWin32UpdateSystemColors();', 'MCWin32SetWindowDarkMode(t_hwnd, t_dark_mode);',
                     'MCPlatformCallbackSendSystemAppearanceChanged();'):
            self.assertIn(what, changed)

    def test_the_notices_name_is_read_as_the_window_takes_its_strings(self):
        # The engine's own window, the one that acts on the notice, is an
        # ANSI window: Windows hands it "ImmersiveColorSet" as an ANSI string.
        # Up to 0.2.7 the name was compared as a wide string only, which never
        # matched, so the notice was never acted on.
        screen = source('w32dcs.cpp')
        self.assertRegex(screen, r'invisiblehwnd = CreateWindowA\(MC_WIN_CLASS_NAME, "MCdummy"')
        self.assertIn('RegisterClassA(&wc)', screen)
        proc = source('w32dcw32.cpp')
        case = proc[proc.index('case WM_SETTINGCHANGE:'):]
        case = case[:case.index('processdesktopchanged(true);')]
        self.assertIn('if (hwnd != ((MCScreenDC *)MCscreen) -> getinvisiblewindow())', case)
        self.assertRegex(case, re.compile(
            r'if \(IsWindowUnicode\(hwnd\)\)\s*'
            r't_color_set = wcscmp\(\(LPCWSTR\)lParam, L"ImmersiveColorSet"\) == 0;\s*else\s*'
            r't_color_set = strcmp\(\(LPCSTR\)lParam, "ImmersiveColorSet"\) == 0;'))

    def test_a_notice_does_its_work_once_for_each_change(self):
        stale = body(source('w32dcs.cpp'), 'bool MCWin32SystemAppearanceIsStale(void)')
        # (its own reading of the appearance does not set the colours)
        self.assertLess(stale.index('s_system_colors_updating = true;'),
                        stale.index('MCscreen->getsystemappearance(t_appearance);'))
        self.assertLess(stale.index('MCscreen->getsystemappearance(t_appearance);'),
                        stale.index('s_system_colors_updating = false;'))
        self.assertIn('return !s_system_colors_set || '
                      's_system_colors_dark != (t_appearance == kMCSystemAppearanceDark);', stale)

    def test_the_message_has_a_number_of_its_own(self):
        numbers = re.findall(r'(?m)^#define (CWM_\w+) \(WM_USER \+ (\d+)\)', source('w32dc.h'))
        self.assertIn('CWM_APPEARANCE_CHANGED', dict(numbers))
        self.assertEqual(len(set(n for _, n in numbers)), len(numbers))


class Workflows(unittest.TestCase):
    """The check runs where the Windows theme draws the buttons: with visual
    styles turned on, on Windows 10's code base and on Windows 11's."""

    def load(self, name):
        with open(os.path.join(ROOT, '.github', 'workflows', name), encoding='utf-8') as f:
            return yaml.safe_load(f)

    def check_job(self, job):
        self.assertEqual(job['strategy']['matrix']['runner'], ['windows-2022', 'windows-2025'])
        self.assertEqual(job['runs-on'], '${{ matrix.runner }}')
        runs = [s.get('run', '') for s in job['steps']]
        themes = [i for i, r in enumerate(runs) if 'Start-Service -Name Themes' in r]
        checks = [i for i, r in enumerate(runs) if 'dark_switch_check.py' in r]
        self.assertEqual((len(themes), len(checks)), (1, 1))
        self.assertLess(themes[0], checks[0])
        self.assertIn('--need-visual-styles', runs[checks[0]])
        # a screen that cannot be read fails, wherever the check runs
        self.assertIn('--need-screen', runs[checks[0]])

    def test_the_build_checks_its_package(self):
        job = self.load('build-windows.yml')['jobs']['dark-switch']
        self.check_job(job)
        # the build, and the draft gate (test_draft_builds.py)
        self.assertEqual(job['needs'], ['gate', 'build'])
        self.assertIn("needs.gate.outputs.build != 'false'", job['if'])

    def test_a_release_can_be_checked_and_is_on_a_change_to_the_check(self):
        flow = self.load('dark-switch-check.yml')
        self.check_job(flow['jobs']['check'])
        # (PyYAML reads the key "on" as True)
        on = flow.get('on') or flow[True]
        self.assertIn('workflow_dispatch', on)
        self.assertEqual(sorted(on['pull_request']['paths']),
                         ['.github/workflows/dark-switch-check.yml',
                          'tools/ci/dark-switch-check.livecodescript', 'tools/ci/dark_switch_check.py'])
        # a release's known fault is reported without failing the pull request:
        # the step may fail there, the job (the pull request's check) may not
        job = flow['jobs']['check']
        self.assertNotIn('continue-on-error', job)
        step = [x for x in job['steps'] if 'dark_switch_check.py' in x.get('run', '')][0]
        self.assertEqual(step['continue-on-error'], "${{ github.event_name == 'pull_request' }}")
        # (the build's own check of its package always counts)
        build = self.load('build-windows.yml')['jobs']['dark-switch']
        self.assertNotIn('continue-on-error', build)
        step = [x for x in build['steps'] if 'dark_switch_check.py' in x.get('run', '')][0]
        self.assertNotIn('continue-on-error', step)


if __name__ == '__main__':
    unittest.main()
