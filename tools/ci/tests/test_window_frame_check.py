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
import unittest

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
