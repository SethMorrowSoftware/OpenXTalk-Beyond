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
steps against a stand-in for the engine (one that follows the appearance
and one that only believes Windows' notice, the fault the check was
written for), the engine source it guards and the workflows that run it.

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
# What 0.2.7 drew after a switch to dark that Windows did not announce: the
# kept light background under the dark appearance's white words
FAULT = ((240, 240, 240), (255, 255, 255))


def measure(label, control, pair):
    return 'MEASURE %s %s face=%d,%d,%d ink=%d,%d,%d size=160x32' % ((label, control) + pair[0] + pair[1])


def log_of(label, pair, appearance, changed=1):
    return ([measure(label, c, pair) for c in dsc.CONTROLS]
            + ['APPEARANCE %s %s' % (label, appearance), 'CHANGED %s %d' % (label, changed), 'MEASURED ' + label])


def steps(log, label, appearance, switched=True):
    out = []
    dsc.check_step(log, 'a run', label, appearance, switched,
                   lambda name, what, ok, detail: out.append((what, ok, detail)))
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
        log[1] = measure('quiet-dark', 'Option', FAULT)
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

    def test_a_line_that_is_not_a_measurement_is_not_read_as_one(self):
        self.assertEqual(dsc.measurements(['MEASURE x Push face=1,2 ink=3,4,5 size=1x1', 'MEASURED x'], 'x'), {})
        self.assertEqual(dsc.measurements([measure('x', 'Push', DARK)], 'x'), {'Push': DARK})


class ThePlan(unittest.TestCase):
    def test_the_engine_starts_in_each_appearance(self):
        self.assertEqual(sorted(start for _, start, _ in dsc.RUNS), ['dark', 'light'])

    def test_each_appearance_is_switched_to_with_and_without_the_notice(self):
        seen = set()
        for _, start, run_steps in dsc.RUNS:
            now = start
            for label, appearance, told in run_steps:
                # (a step that set the appearance it already had would check nothing)
                self.assertNotEqual(appearance, now, label)
                seen.add((appearance, told))
                now = appearance
        self.assertEqual(seen, {('dark', False), ('light', False), ('dark', True), ('light', True)})

    def test_the_labels_of_a_run_are_its_own(self):
        for _, _, run_steps in dsc.RUNS:
            labels = ['start'] + [label for label, _, _ in run_steps]
            self.assertEqual(len(labels), len(set(labels)))
            self.assertNotIn('quit', labels)

    def test_the_script_measures_the_controls_the_check_reads(self):
        with open(os.path.join(ROOT, 'tools', 'ci', 'dark-switch-check.livecodescript'), encoding='utf-8') as f:
            script = f.read()
        self.assertIn('constant kControls = "%s"' % ','.join(dsc.CONTROLS), script)
        # No colour of its own on the stack or on a control: it would hide
        # what the appearance draws
        self.assertIsNone(re.search(r'(?im)^\s*set the \w*color\w* of', script))


# A stand-in for the engine running the script: it speaks the script's lines.
# FAKE_MODE good: it draws for the appearance it reads. stale: its faces are
# for the appearance it was last told of (its start, or Windows' notice), its
# inks for the one it reads, and it sends its message on a notice only: 0.2.7.
FAKE_ENGINE = r'''
import os, sys, time
log, go, state, mode = (os.environ[x] for x in ('OXT_DARK_LOG', 'OXT_DARK_GO', 'FAKE_STATE', 'FAKE_MODE'))
FACE = {'dark': '32,32,32', 'light': '225,225,225'}
INK = {'dark': '255,255,255', 'light': '0,0,0'}
def now():
    appearance, told = open(state).read().split()
    return appearance, int(told)
def out(line):
    with open(log, 'a') as f:
        f.write(line + '\n')
kept, notices = now()
out('WINDOW DarkSwitch 1234')
n = 0
while True:
    n += 1
    out('STEP %d' % n)
    path = '%s.%d' % (go, n)
    end = time.time() + 20
    while not os.path.exists(path) and time.time() < end:
        time.sleep(0.01)
    time.sleep(0.05)
    label = open(path).read().split()[0] if os.path.exists(path) else 'quit'
    if label == 'quit':
        break
    live, told = now()
    changed = 0
    if told != notices:
        changed, kept, notices = 1, live, told
    elif mode == 'good' and kept != live:
        changed, kept = 1, live
    for control in ('Push', 'Option', 'Combo'):
        out('MEASURE %s %s face=%s ink=%s size=160x32' % (label, control, FACE[kept], INK[live]))
    for control in ('Push', 'Option', 'Combo'):
        out('SCREEN %s %s face=%s ink=%s size=160x32' % (label, control, FACE[kept], INK[live]))
    out('APPEARANCE %s %s' % (label, live))
    out('CHANGED %s %d' % (label, changed))
    out('MEASURED %s' % label)
out('DONE')
'''


class FakeWindows:
    def __init__(self, state):
        self.state, self.appearance, self.told = state, None, 0

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
        return 2

    def dark_title_bar(self, hwnd):
        return None


class TheSteps(unittest.TestCase):
    """dark_switch_check.run_engine with the stand-in engine."""

    def setUp(self):
        self.work = tempfile.mkdtemp(prefix='oxt-dark-test-')
        self.addCleanup(shutil.rmtree, self.work, True)
        self.fake = os.path.join(self.work, 'fake_engine.py')
        with open(self.fake, 'w') as f:
            f.write(FAKE_ENGINE)

    def run_all(self, mode):
        lines, problems, results = [], [], []
        w = FakeWindows(os.path.join(self.work, 'state'))
        with mock.patch.object(dsc, 'SCRIPT', self.fake), \
                mock.patch.dict(os.environ, {'FAKE_STATE': w.state, 'FAKE_MODE': mode}):
            for run, start, run_steps in dsc.RUNS:
                dsc.run_engine(w, sys.executable, self.work, run, start, run_steps, 20, lines, problems,
                               lambda name, what, ok, detail: results.append((name, what, ok)))
        return lines, problems, results

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
        self.assertTrue(any('with Windows\' notice to 2 windows' in x for x in lines))

    def test_an_engine_that_only_believes_the_notice_fails_the_quiet_switches(self):
        _, problems, results = self.run_all('stale')
        self.assertEqual(problems, [])
        bad = sorted(set(name for name, _, ok in results if not ok))
        self.assertEqual(bad, ['starts dark, quiet-light', 'starts light, quiet-dark'])
        whats = set(what for name, what, ok in results if not ok and name == 'starts light, quiet-dark')
        self.assertEqual(whats, {'%s is drawn for the dark appearance' % c for c in dsc.CONTROLS}
                         | {'the stack was sent systemAppearanceChanged'})

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
    itself needs a Windows desktop): the colours the engine keeps for the
    appearance follow every reading of it."""

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
            r'L"ImmersiveColorSet"\) == 0\)\s*MCWin32SystemAppearanceChanged\(\);'))
        changed = body(proc, 'static void MCWin32SystemAppearanceChanged(void)')
        for what in ('MCWin32UpdateSystemColors();', 'MCWin32SetWindowDarkMode(t_hwnd, t_dark_mode);',
                     'MCPlatformCallbackSendSystemAppearanceChanged();'):
            self.assertIn(what, changed)

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
        # a release's known fault is reported without failing the pull request
        self.assertEqual(flow['jobs']['check']['continue-on-error'], "${{ github.event_name == 'pull_request' }}")


if __name__ == '__main__':
    unittest.main()
