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

"""The web IDE at rest (seth, 2026-11-04: about half a core while idle on
0.2.7-rc.6.14). The IDE alone took 0.1% of a core; the rest was Home's
animated welcome (palettes/web home), which on the web now draws its four
lights from pictures made once (hmOrbPicture) instead of their gradients
every frame, and holds still behind another window, the user's stack
included when Home never had the keyboard. What the source can show
without an engine:

  - Home's lights: a picture on the web only, made once, moved by the
    frame, with the graphic kept where the picture cannot be made;
  - Home behind another window draws no frame, looks whether it is back
    in use, and moves again at once on resumeStack; it asks the page
    which window has the keyboard, by the engine's own classes;
  - web_ide_tour.py's ACT cpu: the percentage, the budget, and a browser
    without Chromium's protocol;
  - the idle tour's steps and budgets, and web-ide.yml running it.

tools/ci/web-ide-idle.livecodescript (web-ide.yml, Web IDE at rest) runs
them in the web IDE: the pictures' pixels against the gradients', Home
moving and holding still, and the main thread's work in each state.

  python3 -m unittest discover -s tools/ci/tests
"""

import os
import re
import sys
import unittest

CI = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REPO = os.path.dirname(os.path.dirname(CI))
sys.path.insert(0, CI)

import web_ide_tour  # noqa: E402

PALETTES = os.path.join(REPO, 'ide', 'Toolset', 'palettes')
HOME = os.path.join(PALETTES, 'web home', 'revwebhome.livecodescript')
KIT = os.path.join(PALETTES, 'learn', 'revlearnkit.livecodescript')
LEARN = os.path.join(PALETTES, 'learn', 'revlearn.livecodescript')
ACADEMY = os.path.join(PALETTES, 'academy', 'revacademy.livecodescript')
IDLE = os.path.join(CI, 'web-ide-idle.livecodescript')
WORKFLOW = os.path.join(REPO, '.github', 'workflows', 'web-ide.yml')
EM_DC = os.path.join(REPO, 'engine', 'src', 'em-dc.js')


def read(path):
    with open(path, encoding='utf-8') as f:
        return f.read()


def handler(text, name):
    """The text of the handler name (on, command, function, private or
    not), from its first line to its end line."""
    m = re.search(r'^(?:private )?(?:on|command|function) %s\b.*?^end %s\b' % (name, name),
                  text, re.M | re.S)
    if not m:
        raise AssertionError('no handler %s' % name)
    return m.group(0)


class HomeLights(unittest.TestCase):
    def setUp(self):
        self.home = read(HOME)

    def test_a_picture_on_the_web_only(self):
        made = handler(self.home, 'hmOrbPicture')
        self.assertIn('if not hmOnWeb() then', made)
        self.assertLess(made.index('hmOnWeb()'), made.index('export snapshot'))
        self.assertIn('relayer tPic after pObj', made)
        self.assertIn('hide pObj', made)
        # (the graphic stays when the picture cannot be made)
        self.assertRegex(made, r'catch tError[\s\S]*show pObj')

    def test_made_once_when_home_is_built(self):
        build = handler(self.home, 'hmBuildHome')
        self.assertIn('hmOrbPicture tObj, hmOrbRadius(tIndex)', build)
        self.assertNotIn('hmOrbPicture', handler(self.home, 'hmHomeFrame').replace(
            '(the light\'s picture, on the web: hmOrbPicture)', ''))

    def test_the_frame_moves_the_picture(self):
        frame = handler(self.home, 'hmHomeFrame')
        self.assertIn('put hmOrbRadius(tIndex) into tR', frame)
        self.assertRegex(frame, r'if there is an image \("heroOrb" & tIndex & "Pic"\) then\s+'
                                r'set the rect of image \("heroOrb" & tIndex & "Pic"\)')
        # the gradient is drawn again only for a light with no picture
        self.assertEqual(frame.count('hmGlowCentre'), 1)
        self.assertLess(frame.index(' else\n'), frame.index('hmGlowCentre'))


class HomeAtRest(unittest.TestCase):
    def setUp(self):
        self.home = read(HOME)

    prefix = 'hm'
    frame = 'hmFrame'

    def test_no_frames_behind(self):
        p = self.prefix
        self.assertNotIn('kAwayFrame', self.home)
        self.assertIn('constant kAwayCheck = 500', self.home)
        self.assertIn('constant kWake = 2000', self.home)
        tick = handler(self.home, p + 'Tick')
        held = tick.index('if %sHeld() then' % p)
        self.assertLess(held, tick.index(self.frame))
        before = tick[held:tick.index(self.frame)]
        self.assertIn('send "%sTick" to me in kAwayCheck milliseconds' % p, before)
        self.assertIn('exit %sTick' % p, before)
        # (each animation goes on from the clock, not from where it stopped)
        self.assertIn('put sNow into sLastFrame', before)
        self.assertIn('(sAway is true or sPageAway is true) and sNow >= sWokeUntil',
                      handler(self.home, p + 'Held'))

    def test_moves_again_at_once(self):
        p = self.prefix
        resume = handler(self.home, 'resumeStack')
        self.assertIn('put false into sAway', resume)
        self.assertIn('%sWake 0' % p, resume)
        self.assertIn('pass resumeStack', resume)
        wake = handler(self.home, p + 'Wake')
        self.assertIn('if sHeld is true and sTick is not empty then', wake)
        self.assertIn('send "%sTick" to me in 0 milliseconds' % p, wake)

    def test_the_pointer_wakes_it(self):
        self.assertIn('%sWake kWake' % self.prefix, handler(self.home, 'mouseMove'))

    def test_asks_which_window_has_the_keyboard(self):
        check = handler(self.home, self.prefix + 'CheckPage')
        for name in ('.oxt-window-active', 'oxt-window-utility', '.oxt-window-label'):
            self.assertIn(name, check)
        self.assertIn('document.hidden||!document.hasFocus()', check)
        # (the window's title, made safe for a JavaScript string)
        self.assertIn('replace "\\" with "\\\\" in tTitle', check)
        self.assertIn('replace "\'" with "\\\'" in tTitle', check)
        # the classes are the engine's
        em = read(EM_DC)
        for name in ('oxt-window-active', 'oxt-window-utility', 'oxt-window-label'):
            self.assertIn(name, em)


class KitAtRest(HomeAtRest):
    """The kit of Home's Academy and Learn's places holds still as Home
    does, and its wheel wakes it (a page still glides when scrolled)."""
    prefix = 'lk'
    frame = 'lkScrollFrame'

    def setUp(self):
        self.home = read(KIT)

    def test_the_wheel_wakes_it(self):
        self.assertIn('lkWake kWake', handler(self.home, 'rawKeyDown'))


class KitLights(unittest.TestCase):
    def setUp(self):
        self.kit = read(KIT)

    def test_a_picture_on_the_web_only(self):
        made = handler(self.kit, 'lkGlowPicture')
        self.assertIn('if the platform is not "HTML5" then', made)
        self.assertLess(made.index('HTML5'), made.index('export snapshot'))
        # (drawn with no blend, and the picture given the graphic's)
        self.assertLess(made.index('set the blendLevel of pObj to 0'), made.index('export snapshot'))
        self.assertIn('set the blendLevel of tPic to tBlend', made)
        self.assertIn('relayer tPic after pObj', made)
        self.assertRegex(made, r'catch tError[\s\S]*show pObj')

    def test_the_banners_use_it(self):
        for path in (LEARN, ACADEMY):
            text = read(path)
            self.assertIn('lkGlowPicture tObj', text, path)
            self.assertIn('lkGlowMove "p_heroGlow" & tIndex, round(tX) & comma & round(tY)', text, path)
            self.assertNotIn('set the loc of graphic ("p_heroGlow"', text, path)
        move = handler(self.kit, 'lkGlowMove')
        self.assertIn('if there is an image (pName & "Pic") then', move)


class FakeSession(object):
    def __init__(self, readings):
        self.readings = list(readings)
        self.sent = []

    def send(self, method, params=None):
        self.sent.append(method)
        if method == 'Performance.getMetrics':
            return {'metrics': [{'name': 'Timestamp', 'value': 1.0},
                                {'name': 'TaskDuration', 'value': self.readings.pop(0)}]}
        return {}

    def detach(self):
        self.sent.append('detach')


class FakeContext(object):
    def __init__(self, session):
        self.session = session

    def new_cdp_session(self, page):
        if self.session is None:
            raise RuntimeError('CDP session is only available in Chromium')
        return self.session


class FakePage(object):
    def __init__(self, session):
        self.context = FakeContext(session)
        self.waited = []

    def wait_for_timeout(self, ms):
        self.waited.append(ms)


class Cpu(unittest.TestCase):
    def test_busy_percent(self):
        self.assertAlmostEqual(web_ide_tour.busy_percent(1.0, 4.0, 10.0), 30.0)
        self.assertEqual(web_ide_tour.busy_percent(2.0, 2.0, 5.0), 0.0)
        with self.assertRaises(ValueError):
            web_ide_tour.busy_percent(0, 1, 0)

    def test_under_and_over_budget(self):
        problems = []
        session = FakeSession([10.0, 10.0])
        busy = web_ide_tour.cpu(FakePage(session), 'home-behind', 0.01, 5, problems)
        self.assertEqual(busy, 0.0)
        self.assertEqual(problems, [])
        self.assertIn('Performance.enable', session.sent)
        self.assertEqual(session.sent[-1], 'detach')
        page = FakePage(FakeSession([0.0, 1000.0]))
        web_ide_tour.cpu(page, 'home-behind', 0.01, 5, problems)
        self.assertEqual(len(problems), 1)
        self.assertIn('home-behind', problems[0])
        self.assertEqual(page.waited, [10.0])

    def test_another_browser_is_not_measured(self):
        problems = []
        self.assertIsNone(web_ide_tour.cpu(FakePage(None), 'ide-alone', 1, 5, problems))
        self.assertEqual(problems, [])

    def test_the_act_line(self):
        problems = []
        page = FakePage(FakeSession([0.0, 0.0]))
        web_ide_tour.act(page, ['ACT', '3', 'cpu', 'ide-alone', '0.01', '5'], '.', [], problems)
        self.assertEqual(problems, [])
        self.assertEqual(page.waited, [10.0])
        web_ide_tour.act(page, ['ACT', '4', 'cpu', 'ide-alone'], '.', [], problems)
        self.assertEqual(len(problems), 1)
        self.assertIn('cannot do', problems[0])


class IdleTour(unittest.TestCase):
    def setUp(self):
        self.tour = read(IDLE)

    def test_the_extension(self):
        self.assertEqual(web_ide_tour.tour_extension(IDLE), 'oxtwebideidle')

    def test_the_steps(self):
        steps = re.search(r'^constant kSteps = "([^"]*)"', self.tour, re.M).group(1).split(',')
        self.assertEqual(steps, ['pictures', 'front', 'behind', 'back', 'learn', 'alone'])
        for step in steps:
            handler(self.tour, 'idle_' + step)

    def test_the_budgets(self):
        budgets = dict(re.findall(r'^constant k(Front|Behind|Alone)Budget = (\d+)', self.tour, re.M))
        # (measured on rc.6.15's fix: 28, 0.5 and 0.3; rc.6.14 took 38 and
        # 39 behind a stack of the user's)
        self.assertEqual(budgets, {'Front': '85', 'Behind': '5', 'Alone': '5'})
        self.assertIn('constant kTolerance = 3', self.tour)
        for name, budget in (('home-front', 'kFrontBudget'), ('home-behind', 'kBehindBudget'),
                             ('examples-front', 'kFrontBudget'), ('examples-behind', 'kBehindBudget'),
                             ('ide-alone', 'kAloneBudget')):
            self.assertIn('tourAct "cpu %s" && kSeconds && %s' % (name, budget), self.tour)

    def test_the_workflow_runs_it(self):
        workflow = read(WORKFLOW)
        self.assertIn('--tour tools/ci/web-ide-idle.livecodescript', workflow)
        self.assertEqual(workflow.count('      - tools/ci/web-ide-idle.livecodescript\n'), 2)


if __name__ == '__main__':
    unittest.main()
