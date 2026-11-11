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

"""Home on a low-powered computer (seth, 2026-11-09): what
tools/ci/home_speed_check.py passes and fails, from the lines the engine
logs; that the check script, the Python and the workflow agree; and, in
the source, that Home (palettes/web home/revwebhome.livecodescript)
builds its first page as it opens and each other page when first shown,
and that it and revLearnKit (the Academy and Learn in Home) wait after a
frame as long as their frames take, and never less than before.

  python3 -m unittest discover -s tools/ci/tests
"""

import os
import re
import sys
import unittest

CI = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, CI)

import home_speed_check  # noqa: E402

REPO = os.path.dirname(os.path.dirname(CI))
HOME = os.path.join(REPO, 'ide', 'Toolset', 'palettes', 'web home', 'revwebhome.livecodescript')
KIT = os.path.join(REPO, 'ide', 'Toolset', 'palettes', 'learn', 'revlearnkit.livecodescript')
SCRIPT = os.path.join(CI, 'home-speed-check.livecodescript')
WORKFLOW = os.path.join(REPO, '.github', 'workflows', 'build-linux.yml')

# The lines the rc.6.19 standalone engine logged on Xvfb (2026-11-09) with
# this tree's Toolset
GOOD = [
    'OPEN\t80\t165\thome',
    'FRONT\t53.3\t14.7',
    'PAGE\tspeak\ttrue\ttrue\t442',
    'PAGE\tmove\ttrue\ttrue\t446',
    'PAGE\tdraw\ttrue\ttrue\t449',
    'PAGE\tweb\ttrue\ttrue\t465',
    'PAGE\tapp\ttrue\ttrue\t450',
    'BUILT\thome,speak,move,draw,web,app\t558',
    'SLOW\t2.3\t49.8',
    'DONE',
]

# ... and with main's before this change: every page built as Home opened,
# and nine tenths of a core kept busy on the slowed computer
OLD = [
    'OPEN\t127\t558\thome,speak,move,draw,web,app',
    'FRONT\t53.2\t15',
    'PAGE\tspeak\ttrue\ttrue\t438',
    'PAGE\tmove\ttrue\ttrue\t431',
    'PAGE\tdraw\ttrue\ttrue\t434',
    'PAGE\tweb\ttrue\ttrue\t440',
    'PAGE\tapp\ttrue\ttrue\t439',
    'BUILT\thome,speak,move,draw,web,app\t558',
    'SLOW\t4.5\t92.2',
    'DONE',
]


def read(path):
    with open(path, encoding='utf-8') as f:
        return f.read()


def handler(text, name):
    """The body of handler name (on, command, function, private or not)."""
    m = re.search(r'(?m)^(?:private\s+)?(?:on|command|function)\s+%s\b.*?^end\s+%s\b' % (name, name),
                  text, re.S)
    if not m:
        raise AssertionError('no handler %s' % name)
    return m.group(0)


def failed(result):
    return [name for name, ok, _ in home_speed_check.evaluate(result) if not ok]


class Evaluate(unittest.TestCase):
    def test_good_run_passes(self):
        self.assertEqual(failed(GOOD), [])

    def test_main_before_the_change_fails(self):
        self.assertEqual(failed(OLD), ['Home builds only its first page as it opens',
                                       'Home on a slow computer leaves time to the rest'])

    def test_nothing_logged_fails(self):
        self.assertIn('the script finished', failed([]))
        self.assertIn('Home opens', failed([]))
        self.assertIn('every page is built once each has been shown', failed([]))

    def test_script_error_fails(self):
        self.assertIn('no script error', failed(GOOD + ['ERROR\t219,206,29']))

    def test_page_not_built_or_not_shown_fails(self):
        lines = [x.replace('PAGE\tdraw\ttrue\ttrue', 'PAGE\tdraw\tfalse\tfalse') for x in GOOD]
        self.assertEqual(failed(lines), ['the draw page is built when it is first shown', 'the draw page is shown'])

    def test_missing_page_fails(self):
        lines = [x for x in GOOD if not x.startswith('PAGE\tweb')]
        self.assertEqual(failed(lines), ['the web page is shown'])

    def test_slow_front_fails(self):
        lines = [x if not x.startswith('FRONT') else 'FRONT\t9\t30' for x in GOOD]
        self.assertEqual(failed(lines), ['Home in front draws its frames as before'])

    def test_blind_slow_computer_fails(self):
        # (glows that cost nothing: 50 frames a second at 10% is 2 ms each)
        lines = [x if not x.startswith('SLOW') else 'SLOW\t50\t10' for x in GOOD]
        self.assertEqual(failed(lines), ['the glows make a frame slow enough to check'])


class Agreement(unittest.TestCase):
    def test_script_logs_what_the_python_reads(self):
        text = read(SCRIPT)
        for word in ('OPEN', 'FRONT', 'PAGE', 'BUILT', 'SLOW', 'DONE', 'ERROR'):
            self.assertIn('"%s"' % word, text)
        self.assertIn('constant kPages = "%s"' % ','.join(home_speed_check.PAGES), text)
        for name in ('OXT_HOME_LOG', 'OXT_HOME_TOOLSET', 'OXT_HOME_DRAWING'):
            self.assertIn('$' + name, text)
            self.assertIn("'%s'" % name, read(os.path.join(CI, 'home_speed_check.py')))

    def test_pages_are_homes(self):
        m = re.search(r'(?m)^constant kPages = "([^"]*)"', read(HOME))
        self.assertEqual(tuple(m.group(1).split(',')), home_speed_check.PAGES)

    def test_default_files_are_there(self):
        self.assertTrue(os.path.isfile(home_speed_check.DRAWING))
        self.assertTrue(os.path.isfile(os.path.join(home_speed_check.TOOLSET, 'palettes', 'home',
                                                    'revhub.livecodescript')))

    def test_workflow_runs_the_check(self):
        text = read(WORKFLOW)
        self.assertIn('- name: Home speed check', text)
        self.assertIn('tools/ci/home_speed_check.py --engine', text)


class Source(unittest.TestCase):
    def setUp(self):
        self.home = read(HOME)
        self.kit = read(KIT)

    def test_build_makes_every_page_group_and_builds_only_home(self):
        body = handler(self.home, 'hmBuild')
        self.assertIn('get hmGroup("pg_" & tPage', body)
        self.assertIn('hmBuildPage "home"', body)
        for page in ('Speak', 'Move', 'Draw', 'Web', 'App'):
            self.assertNotRegex(body, r'(?m)^\s*hmBuild%s\s*$' % page)
        # the header is built after the page groups, so it stays above them
        self.assertLess(body.index('hmBuildPage "home"'), body.index('hmBuildHeader'))

    def test_build_page_has_a_builder_for_every_page(self):
        body = handler(self.home, 'hmBuildPage')
        for page in home_speed_check.PAGES:
            self.assertRegex(body, r'case "%s"\s+hmBuild%s\b' % (page, page.capitalize()))
        # (built once: a page whose group holds controls is left as it is)
        self.assertIn('the number of controls of group tGroup of me > 0', body)
        # (built where a 1024 by 640 window has it, then moved)
        self.assertIn('put 0 into sOX', body)
        self.assertIn('hmLayoutPage pPage, tOX, tOY', body)

    def test_a_page_is_built_before_it_is_shown(self):
        body = handler(self.home, 'hmGoPage')
        self.assertLess(body.index('hmBuildPage tPage'), body.index('lock screen'))
        self.assertLess(body.index('hmBuildPage tPage'), body.index('show group ("pg_" & tPage)'))

    def test_layout_moves_every_page_built_or_not(self):
        body = handler(self.home, 'hmLayout')
        self.assertIn('hmLayoutPage tPage, tDX, tDY', body)
        page = handler(self.home, 'hmLayoutPage')
        # (the Speak page's line names a place on the stage, and a field of
        # a page not built yet is not there)
        self.assertIn('there is a field "spkInput"', page)
        self.assertIn('add pDY to sCfg[tName]["top"]', page)

    def check_pacing(self, text, prefix):
        tick = handler(text, prefix + 'Tick')
        self.assertIn('%sFrameCost the milliseconds - sNow' % prefix, tick)
        self.assertIn('in %sFrameDelay() milliseconds' % prefix, tick)
        self.assertNotIn('in kFrame milliseconds', tick)
        # (held still behind another window, as before)
        self.assertIn('in kAwayCheck milliseconds', tick)
        delay = handler(text, prefix + 'FrameDelay')
        # never sooner than before, and kFrame until a frame has been timed
        self.assertIn('return max(kFrame, round(sFrameCost))', delay)
        self.assertIn('return kFrame', delay)
        cost = handler(text, prefix + 'FrameCost')
        self.assertIn('min(kFrameCostCap, pMilliseconds)', cost)
        self.assertRegex(text, r'(?m)^constant kFrame = 16$')
        self.assertRegex(text, r'(?m)^constant kFrameCostCap = 250$')
        # (a paced frame moves the animations on by the time it took, up to
        # three times a frame's cost; a tenth of a second, as before, while
        # frames are quick)
        self.assertIn('put min(%sDtCap(), max(0, (sNow - sLastFrame) / 1000)) into sDt' % prefix, tick)
        cap = handler(text, prefix + 'DtCap')
        self.assertIn('return 0.1', cap)
        self.assertIn('return max(0.1, 3 * sFrameCost / 1000)', cap)
        start = handler(text, prefix + 'StartTicking')
        self.assertIn('put empty into sFrameCost', start)

    def test_a_long_frame_cannot_turn_an_animation_round(self):
        # A drag written as "speed * (1 - sDt * k)" turns the speed round
        # once sDt * k passes 1. Since frames are paced, one frame moves
        # the animations on by up to three times kFrameCostCap, so every
        # such factor is held at nothing or more: a later change to the
        # cap, or to a drag, cannot make something fly backwards
        learn = read(os.path.join(os.path.dirname(KIT), 'revlearn.livecodescript'))
        found = 0
        for text in (self.home, self.kit, learn):
            cap = re.search(r'(?m)^constant kFrameCostCap = (\d+)$', text)
            for line in text.splitlines():
                code = line.strip()
                if code.startswith('--'):
                    continue
                for factor in re.finditer(r'1 - (?:sDt|lkDt\(\)) \* ([0-9.]+)', code):
                    found += 1
                    self.assertIn('max(0, %s)' % factor.group(0), code, code)
                    # (and with the cap as it is, the hold changes nothing:
                    # the longest frame still leaves some of the speed)
                    self.assertIsNotNone(cap, code)
                    self.assertLess(3 * int(cap.group(1)) / 1000.0 * float(factor.group(1)), 1, code)
        # (Home's sparks, on the Move page)
        self.assertGreaterEqual(found, 1)

    def test_home_paces_its_frames(self):
        self.check_pacing(self.home, 'hm')

    def test_kit_paces_its_frames(self):
        self.check_pacing(self.kit, 'lk')


if __name__ == '__main__':
    unittest.main()
