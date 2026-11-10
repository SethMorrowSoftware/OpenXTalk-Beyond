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

"""tools/ci/window_frame_check.py's reading of the log that
tools/ci/window-frame-check.livecodescript writes (the Windows build runs
both on Windows; this needs no engine), what keeps the check from passing
with nothing on the screen, and the engine source it guards.

  python3 -m unittest discover -s tools/ci/tests
"""

import importlib.util
import os
import re
import shutil
import tempfile
import unittest
from unittest import mock

import yaml

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
SPEC = importlib.util.spec_from_file_location('window_frame_check',
                                              os.path.join(ROOT, 'tools', 'ci', 'window_frame_check.py'))
wfc = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(wfc)

GOOD = ['STEP 1 faded-opened FrameFaded=1', 'STEP 3 faded-decorated FrameFaded=1', 'STEP 4 faded-opaque FrameFaded=2',
        'STEP 6 titled-sized FrameFadedTitled=3', 'STEP 7 titled-opaque FrameFadedTitled=4',
        'HIDDEN FrameHidden false', 'READY']


def run(log):
    out = []
    wfc.check_focus(log, lambda name, what, ok, detail: out.append((name, what, ok, detail)))
    return out


class CheckFocus(unittest.TestCase):
    def test_a_quiet_log_passes(self):
        self.assertTrue(all(ok for _, _, ok, _ in run(GOOD)))
        self.assertEqual(len(run(GOOD)), 3)

    def test_a_resume_while_a_stack_goes_opaque_fails(self):
        log = list(GOOD)
        log.insert(log.index('STEP 4 faded-opaque FrameFaded=2'), 'SUSPEND FrameFaded')
        failed = [x for x in run(log) if not x[2]]
        self.assertEqual([(x[0], x[3]) for x in failed], [('faded-opaque', 'SUSPEND FrameFaded')])

    def test_a_resume_outside_those_steps_is_not_counted(self):
        log = list(GOOD)
        log.insert(1, 'RESUME FramePlain')
        self.assertTrue(all(ok for _, _, ok, _ in run(log)))

    def test_the_hidden_stack_shown_fails(self):
        log = [x if not x.startswith('HIDDEN') else 'HIDDEN FrameHidden true' for x in GOOD]
        self.assertEqual([x[0] for x in run(log) if not x[2]], ['FrameHidden'])

    def test_missing_steps_fail_rather_than_pass(self):
        self.assertEqual(len([x for x in run(['READY']) if not x[2]]), 3)


def collect():
    out = []
    return out, lambda name, what, ok, detail: out.append((name, what, ok, detail))


class OnTheScreen(unittest.TestCase):
    """Until 10 November 2026 the script never showed its stacks, so every
    run skipped the clicks on the minimize buttons and still passed."""

    ALL = {'FramePlain': True, 'FrameFaded': True, 'FrameFadedTitled': True, 'FrameHidden': False}

    def test_the_stacks_shown_and_the_hidden_one_hidden_pass(self):
        out, check = collect()
        wfc.check_shown(self.ALL, check)
        self.assertEqual(len(out), 4)
        self.assertTrue(all(ok for _, _, ok, _ in out))

    def test_a_stack_that_is_not_on_the_screen_fails(self):
        for name in wfc.STACKS:
            for got, detail in ((False, 'IsWindowVisible: False'), (None, 'no window')):
                out, check = collect()
                wfc.check_shown(dict(self.ALL, **{name: got}), check)
                self.assertEqual([(n, w, d) for n, w, ok, d in out if not ok],
                                 [(name, 'its window is on the screen', detail)])

    def test_the_hidden_stack_on_the_screen_fails(self):
        out, check = collect()
        wfc.check_shown(dict(self.ALL, FrameHidden=True), check)
        self.assertEqual([(n, w) for n, w, ok, _ in out if not ok],
                         [('FrameHidden', 'its window is not on the screen')])
        # (a hidden stack with no window at all is not on the screen either)
        out, check = collect()
        wfc.check_shown(dict(self.ALL, FrameHidden=None), check)
        self.assertTrue(all(ok for _, _, ok, _ in out))

    def test_a_click_that_reaches_nothing_is_a_failure_where_clicks_are_needed(self):
        out, check = collect()
        lines = []
        wfc.no_click((330, 208), True, check, lines)
        self.assertEqual(lines, [])
        self.assertEqual([(n, w, ok) for n, w, ok, _ in out], [('FramePlain', 'a click into its card reaches it', False)])
        self.assertIn('(330, 208)', out[0][3])
        self.assertIn('were not checked', out[0][3])

    def test_elsewhere_it_is_reported_as_skipped(self):
        out, check = collect()
        lines = []
        wfc.no_click((330, 208), False, check, lines)
        self.assertEqual(out, [])
        self.assertEqual(len(lines), 1)
        self.assertTrue(lines[0].startswith('SKIP the clicks on the minimize buttons: '))
        self.assertIn('--need-clicks', lines[0])

    def test_the_script_shows_each_stack_that_is_to_be_seen(self):
        with open(os.path.join(ROOT, 'tools', 'ci', 'window-frame-check.livecodescript'), encoding='utf-8') as f:
            script = f.read()
        # every stack is made invisible, and going to one does not show it
        self.assertIn('create invisible stack pName', script)
        for name in wfc.STACKS:
            self.assertRegex(script, r'\n\s*go stack "%s"\n\s*show stack "%s"\n' % (name, name))
        self.assertIn('go invisible stack "%s"' % wfc.HIDDEN_STACK, script)
        self.assertNotIn('show stack "%s"' % wfc.HIDDEN_STACK, script)

    def test_the_ci_runs_need_their_clicks(self):
        def load(name):
            with open(os.path.join(ROOT, '.github', 'workflows', name), encoding='utf-8') as f:
                return yaml.safe_load(f)

        def runs(job):
            return [s['run'] for s in job['steps'] if 'window_frame_check.py' in s.get('run', '')]
        for job in (load('build-windows.yml')['jobs']['window-frame-win11'],
                    load('window-frame-check.yml')['jobs']['check']):
            found = runs(job)
            self.assertEqual(len(found), 1)
            self.assertIn('--need-clicks', found[0])


SCREEN = (0, 0, 1024, 768)   # the CI runners'


class FakeClock:
    """time for check_windows: a sleep moves the clock on at once."""

    def __init__(self):
        self.now = 1000.0

    def time(self):
        return self.now

    def sleep(self, seconds):
        self.now += seconds


class FakeWin32:
    """The Win32 calls check_windows makes, for windows with a title bar of
    28 pixels and Windows 11's caption buttons. A click on a window's
    minimize button minimizes it and logs ICONIFY as the script does, unless
    the window is in `deaf`; a click into FramePlain's card logs CLICK. As
    on Windows, the pointer stops at the screen's edge."""

    SW_RESTORE = 9

    def __init__(self, log_path, rects, screen=SCREEN, deaf=(), over=None):
        self.log_path, self.rects, self.screen_rect = log_path, rects, screen
        self.deaf, self.over = deaf, over or {}
        self.iconic, self.clicks = set(), []
        self.user32 = self

    # user32
    def IsWindow(self, hwnd):
        return hwnd in self.rects

    def IsIconic(self, hwnd):
        return hwnd in self.iconic

    def ShowWindow(self, hwnd, how):
        self.iconic.discard(hwnd)

    # Win32
    def visible(self, hwnd):
        return hwnd != 4

    def screen(self):
        return self.screen_rect

    def themed(self):
        return True

    def window_rect(self, hwnd):
        return self.rects[hwnd]

    def region(self, hwnd):
        return 'none'

    def title_bar(self, hwnd):
        l, t, r, b = self.rects[hwnd]
        return (l + 8, t + 1, r - 8, t + 29)

    def minimize_button(self, hwnd):
        l, t, r, b = self.rects[hwnd]
        return (r - 147, t + 1, r - 100, t + 31)

    def dwm_buttons(self, hwnd):
        l, t, r, b = self.rects[hwnd]
        return (r - 153, t, r - 7, t + 30)

    def bring_forward(self, hwnd):
        pass

    def inside(self, point, rect):
        return rect[0] <= point[0] < rect[2] and rect[1] <= point[1] < rect[3]

    def window_at(self, x, y):
        if (x, y) in self.over:
            return self.over[(x, y)]
        for hwnd, rect in self.rects.items():
            if hwnd != 4 and hwnd not in self.iconic and self.inside((x, y), rect):
                return hwnd
        return None

    def click(self, x, y):
        s = self.screen_rect
        x, y = min(max(x, s[0]), s[2] - 1), min(max(y, s[1]), s[3] - 1)
        self.clicks.append((x, y))
        hwnd = self.window_at(x, y)
        if hwnd is None:
            return
        name = {1: 'FramePlain', 2: 'FrameFaded', 3: 'FrameFadedTitled'}[hwnd]
        with open(self.log_path, 'a') as f:
            if self.inside((x, y), self.minimize_button(hwnd)):
                if hwnd not in self.deaf:
                    self.iconic.add(hwnd)
                    f.write('ICONIFY %s\n' % name)
            elif y >= self.title_bar(hwnd)[3]:
                f.write('CLICK %s\n' % name)


class TheClicks(unittest.TestCase):
    """Once the stacks were shown, FrameFaded's minimize button was beyond
    the right edge of the runners' screen: the pointer stopped at the edge,
    the click landed in the title bar, and 0.2.7 was reported as ignoring a
    click on the button."""

    WINDOWS = {'FramePlain': 1, 'FrameFaded': 2, 'FrameFadedTitled': 3, 'FrameHidden': 4}
    # As the script lays them out, and as it did until 10 November 2026
    NOW = {1: (72, 89, 588, 328), 2: (592, 89, 1008, 238), 3: (72, 389, 648, 568), 4: (692, 389, 1008, 608)}
    THEN = {**NOW, 2: (632, 89, 1248, 238)}
    MINIMIZES = 'a click on the minimize button minimizes it'

    def setUp(self):
        self.work = tempfile.mkdtemp(prefix='oxt-frame-test-')
        self.addCleanup(shutil.rmtree, self.work, True)
        self.log_path = os.path.join(self.work, 'log')
        with open(self.log_path, 'w') as f:
            f.write('\n'.join(GOOD) + '\n')

    def run_check(self, need_clicks=True, **how):
        how.setdefault('rects', self.NOW)
        self.w = FakeWin32(self.log_path, **how)
        lines, problems = [], []
        with mock.patch.object(wfc, 'time', FakeClock()):
            wfc.check_windows(self.w, self.WINDOWS, self.log_path, lines, problems, need_clicks)
        return lines, problems

    def results(self, lines, what):
        return {x.split(':')[0].split()[1]: x.split()[0] for x in lines if ': %s (' % what in x}

    def test_the_point_of_a_click(self):
        self.assertIsNone(wfc.click_fault((885, 104), SCREEN, 2, 2))
        # the click of 10 November 2026
        self.assertEqual(wfc.click_fault((1119, 104), SCREEN, 2, 2),
                         'the point (1119, 104) is off the screen (0, 0, 1024, 768)')
        for point in ((-1, 104), (1024, 104), (500, -1), (500, 768)):
            self.assertIn('is off the screen', wfc.click_fault(point, SCREEN, 2, 2))
        self.assertIsNone(wfc.click_fault((1023, 767), SCREEN, 2, 2))
        self.assertIsNone(wfc.click_fault((-5, 10), (-1280, 0, 1024, 768), 2, 2))
        self.assertEqual(wfc.click_fault((885, 104), SCREEN, 9, 2),
                         'at (885, 104) is another window (9), not this one (2)')
        self.assertEqual(wfc.click_fault((885, 104), SCREEN, None, 2),
                         'at (885, 104) is another window (None), not this one (2)')

    def test_a_button_that_cannot_be_clicked(self):
        out, check = collect()
        lines = []
        wfc.cannot_click('FrameFaded', 'why', True, check, lines)
        self.assertEqual((out, lines), ([('FrameFaded', 'its minimize button can be clicked', False, 'why')], []))
        out, check = collect()
        wfc.cannot_click('FrameFaded', 'why', False, check, lines)
        self.assertEqual(out, [])
        self.assertEqual(len(lines), 1)
        self.assertTrue(lines[0].startswith('SKIP FrameFaded: the click on its minimize button: why'))

    def test_stacks_that_minimize_pass(self):
        lines, problems = self.run_check()
        self.assertEqual(problems, [])
        self.assertEqual(self.results(lines, self.MINIMIZES), dict.fromkeys(wfc.STACKS, 'PASS'))
        self.assertIn('INFO the screen is (0, 0, 1024, 768)', lines)
        # into the card first, then each minimize button, where DWM draws it
        self.assertEqual(self.w.clicks, [(330, 208), (459, 104), (879, 104), (519, 404)])

    def test_a_stack_that_ignores_its_minimize_button_fails(self):
        for hwnd, name in ((1, 'FramePlain'), (2, 'FrameFaded'), (3, 'FrameFadedTitled')):
            lines, problems = self.run_check(deaf=(hwnd,))
            self.assertEqual(len(problems), 1)
            self.assertTrue(problems[0].startswith('%s: %s (clicked at ' % (name, self.MINIMIZES)), problems[0])
            self.assertIn('IsIconic False, iconifyStack not received', problems[0])

    def test_a_button_beyond_the_screens_edge_is_not_clicked(self):
        lines, problems = self.run_check(rects=self.THEN)
        self.assertEqual(problems, ['FrameFaded: its minimize button can be clicked '
                                    '(the point (1119, 104) is off the screen (0, 0, 1024, 768))'])
        self.assertEqual(self.results(lines, self.MINIMIZES), {'FramePlain': 'PASS', 'FrameFadedTitled': 'PASS'})
        self.assertNotIn((1023, 104), self.w.clicks)
        # where the clicks are not needed it is a line, never a result
        lines, problems = self.run_check(need_clicks=False, rects=self.THEN)
        self.assertEqual(problems, [])
        self.assertEqual(len([x for x in lines if x.startswith('SKIP FrameFaded: ')]), 1)
        self.assertNotIn('FrameFaded', self.results(lines, self.MINIMIZES))

    def test_a_button_under_another_window_is_not_clicked(self):
        lines, problems = self.run_check(over={(879, 104): 77})
        self.assertEqual(problems, ['FrameFaded: its minimize button can be clicked '
                                    '(at (879, 104) is another window (77), not this one (2))'])
        self.assertNotIn((879, 104), self.w.clicks)

    def test_the_scripts_stacks_fit_the_runners_screen(self):
        """Every rect the script gives a stack, with room for its frame (8
        pixels a side, 31 above) and for the taskbar (48 pixels)."""
        with open(os.path.join(ROOT, 'tools', 'ci', 'window-frame-check.livecodescript'), encoding='utf-8') as f:
            script = f.read()
        rects, seen = {}, 0
        for line in script.splitlines():
            m = re.match(r'\s*makeStack "(\w+)", "(\d+),(\d+),(\d+),(\d+)"$', line)
            if m:
                rects[m.group(1)] = [int(x) for x in m.groups()[1:]]
            m = m or re.match(r'\s*set the rect of stack "(\w+)" to (\d+),(\d+),(\d+),(\d+)$', line)
            if m:
                rects[m.group(1)] = [int(x) for x in m.groups()[1:]]
            n = re.match(r'\s*set the topLeft of stack "(\w+)" to (\d+),(\d+)$', line)
            if n:
                l, t, r, b = rects[n.group(1)]
                x, y = int(n.group(2)), int(n.group(3))
                rects[n.group(1)] = [x, y, x + r - l, y + b - t]
            o = re.match(r'\s*set the (top|left) of stack "(\w+)" to (\d+)$', line)
            if o:
                l, t, r, b = rects[o.group(2)]
                v = int(o.group(3))
                rects[o.group(2)] = [l, v, r, v + b - t] if o.group(1) == 'top' else [v, t, v + r - l, b]
            # (the rect a stack is given before it is moved into place is
            # never on the screen: lines 'set the rect ... to 0,0,...')
            if not (m or n or o) or (m and m.group(2) == '0' and m.group(3) == '0'):
                continue
            seen += 1
            name = (m or n or o).group(2 if o else 1)
            l, t, r, b = rects[name]
            self.assertTrue(8 <= l and 31 <= t and r + 8 <= SCREEN[2] and b + 8 <= SCREEN[3] - 48,
                            '%s at %s: %s' % (name, rects[name], line.strip()))
        self.assertEqual(sorted(rects), sorted(wfc.STACKS + (wfc.HIDDEN_STACK,)))
        self.assertGreaterEqual(seen, 8)
        # and as the engine then frames them, the layout the checks above use
        self.assertEqual(rects['FrameFaded'], [600, 120, 1000, 230])


class EngineSource(unittest.TestCase):
    def test_a_window_that_stops_being_layered_hands_on_its_activation(self):
        with open(os.path.join(ROOT, 'engine', 'src', 'w32stack.cpp'), encoding='utf-8') as f:
            src = f.read()
        body = src[src.index('void MCStack::setopacity'):src.index('void MCStack::destroywindowshape')]
        self.assertRegex(body, re.compile(
            r'GetActiveWindow\(\) == t_old_window\)\s*SetActiveWindow\(\(HWND\)window -> handle \. window\);'
            r'\s*(//[^\n]*\n\s*)*DestroyWindow\(t_old_window\);'))


if __name__ == '__main__':
    unittest.main()
