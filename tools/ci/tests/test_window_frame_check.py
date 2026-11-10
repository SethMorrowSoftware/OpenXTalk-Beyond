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
both on Windows; this needs no engine), and the engine source it guards.

  python3 -m unittest discover -s tools/ci/tests
"""

import importlib.util
import os
import re
import unittest

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
