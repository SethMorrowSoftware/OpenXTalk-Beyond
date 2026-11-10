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

import importlib.util
import os
import re
import shutil
import sys
import tempfile
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


def measure(label, control, pair):
    return 'MEASURE %s %s face=%d,%d,%d ink=%d,%d,%d size=160x32' % ((label, control) + pair[0] + pair[1])


def log_of(label, pair, appearance, changed=1, noticed=0):
    return (['NOTICED %s %d' % (label, noticed)] + [measure(label, c, pair) for c in dsc.CONTROLS]
            + ['APPEARANCE %s %s' % (label, appearance), 'CHANGED %s %d' % (label, changed), 'MEASURED ' + label])


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


class Steps(unittest.TestCase):
    def test_a_good_step_passes_every_check(self):
        got = steps(log_of('quiet-dark', DARK, 'dark'), 'quiet-dark', 'dark')
        self.assertEqual(failed(got), [])
        self.assertEqual(len(got), len(dsc.CONTROLS) + 2)

    def test_the_start_asks_for_no_message(self):
        got = steps(log_of('start', LIGHT, 'light', changed=0), 'start', 'light', switched=False)
        self.assertEqual(failed(got), [])
        self.assertEqual(len(got), len(dsc.CONTROLS) + 1)

    def test_the_fault_fails_each_control(self):
        got = steps(log_of('quiet-dark', FAULT, 'dark'), 'quiet-dark', 'dark')
        self.assertEqual(failed(got), ['%s is drawn for the dark appearance' % c for c in dsc.CONTROLS])

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
        self.assertEqual(len(failed(steps(log, 'quiet-dark', 'dark'))), len(dsc.CONTROLS) + 2)

    def test_no_message_after_a_switch_fails(self):
        got = steps(log_of('quiet-dark', DARK, 'dark', changed=0), 'quiet-dark', 'dark')
        self.assertEqual(failed(got), ['the stack was sent systemAppearanceChanged'])

    def test_the_wrong_appearance_in_script_fails(self):
        got = steps(log_of('quiet-dark', DARK, 'light'), 'quiet-dark', 'dark')
        self.assertEqual(failed(got), ['the systemAppearance is dark'])

    def test_a_told_switch_asks_for_the_message_before_anything_was_measured(self):
        notice = 'Windows\' notice alone sent systemAppearanceChanged'
        got = steps(log_of('told-dark', DARK, 'dark', changed=1, noticed=1), 'told-dark', 'dark', told=True)
        self.assertEqual(failed(got), [])
        self.assertEqual(len(got), len(dsc.CONTROLS) + 3)
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

    def test_the_screen_is_reported_beside_the_snapshots_and_not_mixed_with_them(self):
        log = log_of('quiet-dark', DARK, 'dark') + [measure('quiet-dark', 'Push', FAULT).replace('MEASURE', 'SCREEN')]
        # the snapshot's checks do not read the screen's line
        self.assertEqual(failed(steps(log, 'quiet-dark', 'dark')), [])
        self.assertEqual(dsc.measurements(log, 'quiet-dark', 'SCREEN'), {'Push': FAULT})
        lines = dsc.screen_lines(log, 'a run', 'quiet-dark', 'dark')
        self.assertEqual(len(lines), len(dsc.CONTROLS))
        self.assertIn('on the screen Push is NOT drawn for the dark appearance', lines[0])
        self.assertIn('240,240,240', lines[0])
        self.assertIn('on the screen Option was not read', lines[1])
        self.assertTrue(all(x.startswith('INFO ') for x in lines))
        # with another window over the stack's, what was read is that window: not reported as the controls
        self.assertEqual(dsc.screen_lines(log, 'a run', 'quiet-dark', 'dark', 'ConsoleWindowClass'),
                         ['INFO a run, quiet-dark: the screen was not read: a window of the class '
                          'ConsoleWindowClass is over the stack\'s there'])

    def test_a_line_that_is_not_a_measurement_is_not_read_as_one(self):
        self.assertEqual(dsc.measurements(['MEASURE x Push face=1,2 ink=3,4,5 size=1x1', 'MEASURED x'], 'x'), {})
        self.assertEqual(dsc.measurements([measure('x', 'Push', DARK)], 'x'), {'Push': DARK})


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
        # counted from the window itself, wherever it is
        self.assertIn('import snapshot from rect (the rect of button pName of stack kStack) '
                      'of window (the windowID of stack kStack)', script)
        self.assertNotIn('globalLoc', script)

    def test_the_script_measures_the_controls_the_check_reads(self):
        with open(os.path.join(ROOT, 'tools', 'ci', 'dark-switch-check.livecodescript'), encoding='utf-8') as f:
            script = f.read()
        self.assertIn('constant kControls = "%s"' % ','.join(dsc.CONTROLS), script)
        # No colour of its own on the stack or on a control: it would hide
        # what the appearance draws
        self.assertIsNone(re.search(r'(?im)^\s*set the \w*color\w* of', script))


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
FAKE_ENGINE = r"""
import os, sys, time
log, go, state, mode = (os.environ[x] for x in ('OXT_DARK_LOG', 'OXT_DARK_GO', 'FAKE_STATE', 'FAKE_MODE'))
FACE = {'dark': '32,32,32', 'light': '225,225,225'}
INK = {'dark': '255,255,255', 'light': '0,0,0'}
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
def follow(live):
    global kept
    kept = live
    with open(state + '.title.new', 'w') as f:
        f.write(live + '\n')
    os.replace(state + '.title.new', state + '.title')
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
    for word in ('MEASURE', 'SCREEN'):
        for control in ('Push', 'Option', 'Combo'):
            face = FACE[live] if live == 'light' or control == 'Combo' else FACE[kept]
            out('%s %s %s face=%s ink=%s size=160x32' % (word, label, control, face, INK[live]))
    out('APPEARANCE %s %s' % (label, live))
    out('CHANGED %s %d' % (label, changed))
    out('MEASURED %s' % label)
out('DONE')
"""


class FakeWindows:
    def __init__(self, state):
        self.state, self.appearance, self.told, self.forwarded = state, None, 0, []

    def write(self):
        with open(self.state + '.new', 'w') as f:
            f.write('%s %d\n' % (self.appearance, self.told))
        os.replace(self.state + '.new', self.state)

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
        return None

    def dark_title_bar(self, hwnd):
        try:
            with open(self.state + '.title') as f:
                return f.read().strip() == 'dark'
        except OSError:
            return None


class TheSteps(unittest.TestCase):
    """dark_switch_check.run_engine with the stand-in engine."""

    BUTTONS = ['%s is drawn for the dark appearance' % c for c in ('Push', 'Option')]
    MESSAGE = 'the stack was sent systemAppearanceChanged'
    NOTICE = 'Windows\' notice alone sent systemAppearanceChanged'
    NOTHING = 'a notice that changed nothing sent no systemAppearanceChanged'

    def setUp(self):
        self.work = tempfile.mkdtemp(prefix='oxt-dark-test-')
        self.addCleanup(shutil.rmtree, self.work, True)
        self.fake = os.path.join(self.work, 'fake_engine.py')
        with open(self.fake, 'w') as f:
            f.write(FAKE_ENGINE)

    def run_all(self, mode):
        lines, problems, results = [], [], []
        self.windows = w = FakeWindows(os.path.join(self.work, 'state'))
        with mock.patch.object(dsc, 'SCRIPT', self.fake), mock.patch.object(dsc, 'NOTICE_WAIT', 0.3), \
                mock.patch.dict(os.environ, {'FAKE_STATE': w.state, 'FAKE_MODE': mode}):
            for run, start, run_steps in dsc.RUNS:
                dsc.run_engine(w, sys.executable, self.work, run, start, run_steps, 20, lines, problems,
                               lambda name, what, ok, detail: results.append((name, what, ok)))
        return lines, problems, results

    def failures(self, mode):
        _, problems, results = self.run_all(mode)
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
        screen = [x for x in lines if 'on the screen' in x]
        self.assertEqual(len(screen), len(dsc.CONTROLS) * sum(1 + len(run_steps) for _, _, run_steps in dsc.RUNS))
        self.assertFalse(any('NOT drawn' in x or 'not read' in x for x in screen))
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
            'starts light, quiet-dark': self.BUTTONS + [self.MESSAGE, 'the title bar is dark'],
            'starts light, told-light': [self.NOTICE, self.MESSAGE],
            'starts light, told-dark': ['after Windows\' notice alone the title bar is dark'] + self.BUTTONS
                                       + [self.NOTICE, self.MESSAGE, 'the title bar is dark'],
            'starts light, told-again': self.BUTTONS + ['the title bar is dark'],
        })

    def test_an_engine_that_follows_only_by_reading_fails_what_the_notice_alone_must_do(self):
        self.assertEqual(self.failures('reads-only'), {
            'starts light, told-light': ['after Windows\' notice alone the title bar is light', self.NOTICE],
            'starts light, told-dark': ['after Windows\' notice alone the title bar is dark', self.NOTICE],
        })

    def test_an_engine_that_only_believes_the_notice_fails_the_quiet_switches(self):
        # (and sends its message for a notice that changed nothing)
        self.assertEqual(self.failures('notice-only'), {
            'starts dark, quiet-light': [self.MESSAGE, 'the title bar is light'],
            'starts light, quiet-dark': self.BUTTONS + [self.MESSAGE, 'the title bar is dark'],
            'starts light, told-again': [self.NOTHING],
        })

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

    def test_the_build_checks_its_package(self):
        job = self.load('build-windows.yml')['jobs']['dark-switch']
        self.check_job(job)
        self.assertEqual(job['needs'], ['build'])
        self.assertIn('github.event.pull_request.draft != true', job['if'])

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
