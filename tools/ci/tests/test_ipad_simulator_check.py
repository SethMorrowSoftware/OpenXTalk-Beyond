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

"""tools/ci/ipad_simulator_check.py and .github/workflows/ipad-simulator.yml.

The check runs only on a Mac with Apple's iPad simulator. What is tested
here: choosing the iPad, finding the page on the screen from two clicks,
judging the page's events (full screen held, taken back), the page's
reporter (ipad-simulator-reporter.js, under node, in a page of plain
objects), the server between them, and the whole drive against a model of
the iPad: the engine of 0.2.8-dp.2 passes, the engine before it fails
(full screen taken back, as CamelCaps saw it), and a simulator without
WebKit's rule fails the control step, so that the check cannot pass
blind. The workflow's wiring is held too.

  python3 -m unittest discover -s tools/ci/tests -p test_ipad_simulator_check.py
"""

import inspect
import json
import os
import shutil
import subprocess
import sys
import tempfile
import threading
import time
import unittest
import urllib.request

import yaml

REPO = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', '..'))
sys.path.insert(0, os.path.join(REPO, 'tools', 'ci'))

import ipad_simulator_check as isc  # noqa: E402

NODE = shutil.which('node')
WORKFLOW = os.path.join(REPO, '.github', 'workflows', 'ipad-simulator.yml')


# ------------------------------------------------------------------ picking

DEVICES = {'devices': {
    'com.apple.CoreSimulator.SimRuntime.iOS-18-5': [
        {'name': 'iPhone 16', 'udid': 'P185', 'isAvailable': True},
        {'name': 'iPad Pro 11-inch (M4)', 'udid': 'PRO185', 'isAvailable': True},
        {'name': 'iPad (A16)', 'udid': 'IPAD185', 'isAvailable': True},
        {'name': 'iPad mini (A17 Pro)', 'udid': 'MINI185', 'isAvailable': True},
    ],
    'com.apple.CoreSimulator.SimRuntime.iOS-18-6': [
        {'name': 'iPad (A16)', 'udid': 'IPAD186', 'isAvailable': True},
    ],
    'com.apple.CoreSimulator.SimRuntime.iOS-26-0': [
        {'name': 'iPad (A16)', 'udid': 'IPAD260', 'isAvailable': True},
    ],
    'com.apple.CoreSimulator.SimRuntime.iOS-26-2': [
        {'name': 'iPad (A16)', 'udid': 'IPAD262-GONE', 'isAvailable': False},
        {'name': 'iPad Air 11-inch (M3)', 'udid': 'AIR262', 'isAvailable': True},
    ],
    'com.apple.CoreSimulator.SimRuntime.watchOS-11-5': [
        {'name': 'iPad-ish watch', 'udid': 'W', 'isAvailable': True},
    ],
}}


class Pick(unittest.TestCase):
    def test_a_version_picks_that_system_and_a_plain_ipad(self):
        self.assertEqual(isc.pick(DEVICES, '18.5')[:2], ('IPAD185', 'iPad (A16)'))

    def test_a_major_version_picks_its_newest_system(self):
        # 26.2's plain iPad is not available: its Air is the newest
        self.assertEqual(isc.pick(DEVICES, '26')[0], 'AIR262')
        self.assertEqual(isc.pick(DEVICES, '18')[0], 'IPAD186')

    def test_no_ipad_fails(self):
        with self.assertRaises(isc.CheckError):
            isc.pick(DEVICES, '17')
        with self.assertRaises(isc.CheckError):
            isc.pick({'devices': {}}, '26')

    def test_from_the_command_line(self):
        r = subprocess.run([sys.executable, os.path.join(REPO, 'tools', 'ci', 'ipad_simulator_check.py'), 'pick',
                            '18.5'], input=json.dumps(DEVICES), capture_output=True, text=True, timeout=60)
        self.assertEqual((r.returncode, r.stdout.strip()), (0, 'IPAD185'), r.stderr)


# ----------------------------------------------------------------- geometry

class Geometry(unittest.TestCase):
    def test_two_clicks_give_where_the_page_is(self):
        # the page at half size, 100 points right and 80 down
        m = isc.solve([((100, 200), (150, 180)), ((500, 900), (350, 530))])
        self.assertEqual(m.to_mac(0, 0), (100, 80))
        self.assertEqual(m.to_mac(729, 1050), (464, 605))

    def test_clicks_that_say_nothing_are_refused(self):
        for pairs in ([((100, 200), (150, 180)), ((105, 900), (152, 530))],   # the same column
                      [((100, 200), (150, 180)), ((500, 210), (350, 185))],   # the same row
                      [((100, 200), (150, 180)), ((500, 900), (100, 530))],   # mirrored
                      [((100, 200), (150, 180)), ((500, 900), (350, 880))],   # two scales
                      [((100, 200), (150, 180))]):
            with self.assertRaises(isc.CheckError, msg=pairs):
                isc.solve(pairs)

    STATE = {'rect': '0,0,810,1080', 'w': 810, 'h': 1080, 'tabs': '1020',
             'buttons': 'Camera:20,100,400,148;Full:430,216,790,264',
             'labels': 'Camera:Take a photo;Full:Show the bars'}

    def test_the_tabs_and_the_buttons(self):
        self.assertEqual(isc.tab_point(self.STATE, 'Phone'), (729.0, 1050.0))
        self.assertEqual(isc.tab_point(self.STATE, 'Home'), (81.0, 1050.0))
        self.assertEqual(isc.button_point(self.STATE, 'Full'), (610.0, 240.0))
        self.assertEqual(isc.label_of(self.STATE, 'Full'), 'Show the bars')
        self.assertIsNone(isc.label_of(self.STATE, 'Share'))
        with self.assertRaises(isc.CheckError):
            isc.button_point(self.STATE, 'Share')
        with self.assertRaises(isc.CheckError):
            isc.tab_point({'rect': '0,0,810,1080'}, 'Phone')

    def test_the_stack_fills_the_window(self):
        self.assertTrue(isc.fills(self.STATE))
        self.assertFalse(isc.fills(dict(self.STATE, rect='0,0,810,1000')))
        self.assertFalse(isc.fills(dict(self.STATE, rect='')))


# ------------------------------------------------------------------ judging

def changes(*pairs):
    return [{'kind': 'fullscreenchange', 'full': full, 't': t} for t, full in pairs]


def states(*pairs):
    return [{'kind': 'state', 'full': full, 't': t} for t, full in pairs]


class Judging(unittest.TestCase):
    def test_the_page_times_are_milliseconds(self):
        # a word 7 ms after full screen came is not 6 s of it (the first
        # version of the check took the page's ms for seconds)
        self.assertEqual(isc.held(changes((1000, True)) + states((1007, True)), 1000, 6), (None, None))
        self.assertEqual(isc.held(states((1007, True), (7000, True)), 1000, 6), (True, None))

    def test_full_screen_taken_back_is_not_held(self):
        # CamelCaps' report, as the simulator showed it: 1.3 s
        events = changes((1000, True)) + states((1400, True)) + changes((2300, False)) + states((8000, False))
        self.assertEqual(isc.held(events, 1000, 6), (False, 2300))
        self.assertEqual(isc.taken_back(events, 1000, 8), (True, 2300))

    def test_full_screen_kept_is_held(self):
        events = changes((1000, True), (1001, True)) + states((3000, True), (5000, True), (7100, True))
        self.assertEqual(isc.held(events, 1000, 6), (True, None))
        self.assertEqual(isc.taken_back(events, 1000, 6), (False, None))
        self.assertEqual(isc.taken_back(events, 1000, 8), (None, None))

    def test_words_before_the_start_do_not_count(self):
        events = states((500, False)) + changes((1000, True)) + states((7000, True))
        self.assertEqual(isc.held(events, 1000, 6), (True, None))
        self.assertEqual(isc.entered(events, 0), 1000)
        self.assertIsNone(isc.entered(events, 1000))

    def test_late_take_back_is_not_the_bug(self):
        events = changes((1000, True)) + states((8500, True)) + changes((9500, False))
        self.assertEqual(isc.taken_back(events, 1000, 8), (False, None))

    def test_the_engine_input_with_the_focus(self):
        events = [{'kind': 'focus', 'to': 'engine-input', 't': 900},
                  {'kind': 'state', 'focus': 'body', 't': 1100},
                  {'kind': 'focus', 'to': 'engine-input', 't': 1200},
                  {'kind': 'state', 'focus': 'engine-input', 't': 1300},
                  {'kind': 'touchstart', 'focus': 'engine-input', 't': 1400}]
        self.assertEqual(isc.focused_input(events, 1000), [1200, 1300])


# ------------------------------------------------------------------ staging

class Staging(unittest.TestCase):
    def test_the_reporter_comes_before_the_engine(self):
        page = ('<!doctypehtml><html><head><title>t</title></head><body>'
                '<script async src=standalone-community-9.7.1.js></script></body></html>')
        out = isc.inject_reporter(page)
        self.assertLess(out.index(isc.REPORTER_NAME), out.index('standalone-community'))
        self.assertLess(out.index(isc.REPORTER_NAME), out.index('</head>'))
        with self.assertRaises(isc.CheckError):
            isc.inject_reporter(out)
        with self.assertRaises(isc.CheckError):
            isc.inject_reporter('<html><body></body></html>')

    def test_the_runtimes_page_has_one_head(self):
        # the page template of the web runtime, as web_check makes it
        import web_check
        self.assertTrue(os.path.isfile(isc.REPORTER))
        self.assertTrue(hasattr(web_check, 'STACK_NAME'))

    def test_what_stage_takes_from_the_mobile_web_check(self):
        # stage() calls these as the mobile web check does: a change to
        # them must be seen here, as this workflow runs on few changes
        import mobile_web_check
        import web_check
        self.assertEqual(list(inspect.signature(mobile_web_check.deploy).parameters),
                         ['engine', 'runtime', 'version', 'stack', 'work', 'timeout'])
        self.assertTrue(os.path.isfile(mobile_web_check.STARTER))
        self.assertEqual(list(inspect.signature(web_check.runtime_files).parameters), ['runtime'])
        self.assertEqual(list(inspect.signature(web_check.fetch_engine).parameters), ['cache'])
        self.assertEqual(list(inspect.signature(web_check.make_standalone).parameters)[:6],
                         ['runtime', 'js', 'wasm', 'html', 'startup_data', 'site'])
        self.assertIn('title', inspect.signature(web_check.make_standalone).parameters)

    def test_the_check_stack_says_what_the_drive_reads(self):
        with open(os.path.join(REPO, 'tools', 'ci', 'mobile-web-check.livecodescript'), encoding='utf-8') as f:
            text = f.read()
        for key in ('card', 'rect', 'tabs', 'labels', 'buttons'):
            self.assertIn('put "%s=" &' % key, text)
        self.assertIn('Full', text.split('function mwcButtons')[1].split('end mwcButtons')[0])
        with open(isc.REPORTER, encoding='utf-8') as f:
            reporter = f.read()
        self.assertIn("['card', 'rect', 'tabs', 'labels', 'buttons']", reporter)
        self.assertIn("findStackWithName('MobileWebCheck')", reporter)

    def test_the_phone_starter_says_what_the_drive_expects(self):
        with open(os.path.join(REPO, 'tools', 'web-player', 'phone-starter-stack.livecodescript'),
                  encoding='utf-8') as f:
            text = f.read()
        self.assertIn('"%s", "%s"' % (isc.LABEL_OFF, isc.LABEL_ON), text)
        self.assertIn('constant kTabs = "%s"' % ','.join(isc.TABS),
                      open(os.path.join(REPO, 'tools', 'web-player', 'phone-starter.livecodescript'),
                           encoding='utf-8').read())


# ------------------------------------------------------------------- server

class Server(unittest.TestCase):
    def setUp(self):
        self.site = tempfile.mkdtemp(prefix='ipad-site-')
        with open(os.path.join(self.site, 'x.wasm'), 'wb') as f:
            f.write(b'\0asm')
        self.record, self.commands = isc.Record(), isc.Commands()
        self.log, isc.log = isc.log, lambda *args: None
        self.server = isc.make_server(self.site, self.record, self.commands, 0)
        self.base = 'http://127.0.0.1:%d' % self.server.server_address[1]

    def tearDown(self):
        self.server.shutdown()
        isc.log = self.log
        shutil.rmtree(self.site, ignore_errors=True)

    def test_the_page_posts_and_takes_commands(self):
        body = json.dumps([{'kind': 'loaded', 't': 3}, {'kind': 'state', 't': 400, 'card': 'Home'}]).encode()
        r = urllib.request.urlopen(urllib.request.Request(self.base + '/ipad/log', data=body, method='POST'))
        self.assertEqual(r.status, 204)
        self.assertEqual([e['kind'] for e in self.record.since()], ['loaded', 'state'])
        self.assertEqual(self.record.state()['card'], 'Home')
        self.assertEqual(urllib.request.urlopen(self.base + '/ipad/command').read(), b'')
        self.commands.put('leave')
        self.commands.put('unfix')
        self.assertEqual(urllib.request.urlopen(self.base + '/ipad/command').read(), b'leave')
        self.assertEqual(urllib.request.urlopen(self.base + '/ipad/command?n=2').read(), b'unfix')

    def test_the_site_is_served_as_a_browser_needs_it(self):
        r = urllib.request.urlopen(self.base + '/x.wasm')
        self.assertEqual((r.headers['Content-Type'], r.headers['Cache-Control']), ('application/wasm', 'no-store'))

    def test_anything_else_is_refused(self):
        for path, data in (('/other', b'[]'), ('/ipad/log', b'not json')):
            with self.assertRaises(urllib.error.HTTPError):
                urllib.request.urlopen(urllib.request.Request(self.base + path, data=data, method='POST'))
        self.assertEqual(self.record.since(), [])


# -------------------------------------------------------------- the driving

class FakeIPad:
    """The page on an iPad as the reporter tells it, at SPEED times the wall
    clock: the stack's card and Full button, full screen, what has the
    focus, and WebKit's rule (a text input with the focus in full screen
    ends full screen, 1.3 s later as on the simulator). fixed: the engine
    of 0.2.8-dp.2, which gives its input up when the page asks for full
    screen and gives it no focus in full screen; rule: the simulator
    applies WebKit's rule; refuse: the browser refuses the request."""

    W, H, TABS_TOP = 810, 1080, 1020
    FULL = (430, 216, 790, 264)
    SCALE, LEFT, TOP, BAR = 0.5, 100, 60, 40
    SPEED = 20

    def __init__(self, record, commands, fixed=True, rule=True, refuse=False, smaller_bar=False,
                 long_presses=0, no_activation=False):
        self.record, self.commands = record, commands
        self.fixed, self.rule_on, self.refuse, self.smaller_bar = fixed, rule, refuse, smaller_bar
        # long_presses: how many taps on the Full button the Simulator
        # holds as a busy Mac did (20 Nov 2026, iOS 26: 874 ms), which the
        # browser takes as a long press, giving no user activation; the
        # page then asks nothing (mobileweb's noTap()). no_activation: a
        # quick tap that gives none either
        self.long_presses, self.no_activation = long_presses, no_activation
        self.card, self.full, self.focus, self.unfixed = 'Home', False, 'body', False
        self.lock = threading.RLock()
        self.later = []
        self.start = None
        self.stopped = False
        self.clicks = []

    def t(self):
        return int((time.time() - self.start) * 1000 * self.SPEED)

    def post(self, kind, **data):
        self.record.add([dict(data, t=self.t(), kind=kind)])

    def state(self):
        return {'card': self.card, 'full': self.full, 'focus': self.focus, 'w': self.W, 'h': self.H,
                'rect': '0,0,%d,%d' % (self.W, self.H), 'tabs': str(self.TABS_TOP),
                'labels': 'Camera:Take a photo;Full:%s' % (isc.LABEL_ON if self.full else isc.LABEL_OFF),
                'buttons': 'Camera:20,216,400,264;Full:%s' % ','.join(map(str, self.FULL))}

    def after(self, ms, fn):
        self.later.append((self.t() + ms, fn))

    def run(self):
        while not self.stopped:
            with self.lock:
                now = self.t()
                due = [x for x in self.later if x[0] <= now]
                self.later = [x for x in self.later if x[0] > now]
                for _, fn in due:
                    fn()
                command = self.commands.take()
                if command == 'leave':
                    self.set_full(False)
                    if self.smaller_bar:
                        # Safari's bar comes back 30 points smaller: the
                        # page is 60 pixels taller, its bottom where it was
                        self.BAR, self.H, self.TABS_TOP = self.BAR - 30, self.H + 60, self.TABS_TOP + 60
                    self.post('done', command=command)
                elif command == 'unfix':
                    self.unfixed = True
                    self.post('done', command=command)
                self.post('state', **self.state())
            time.sleep(0.02)

    # the Simulator
    def open_url(self, url):
        self.start = time.time()
        self.post('loaded', agent='fake', platform='MacIntel', touchPoints=5, w=self.W, h=self.H)
        threading.Thread(target=self.run, daemon=True).start()

    def window(self):
        return self.LEFT, self.TOP, int(self.W * self.SCALE), int(self.H * self.SCALE) + self.BAR

    def click(self, point):
        x = (point[0] - self.LEFT) / self.SCALE
        y = (point[1] - self.TOP - self.BAR) / self.SCALE
        self.clicks.append((round(x), round(y)))
        with self.lock:
            # a press: the engine gives its input the focus, but the fixed
            # one not while the page is full screen
            if not (self.fixed and self.full) or self.unfixed:
                self.set_focus('engine-input')
            on_full = self.card == 'Phone' and self.FULL[0] <= x <= self.FULL[2] and self.FULL[1] <= y <= self.FULL[3]
            self.post('touchstart', x=round(x), y=round(y), trusted=True, focus=self.focus, active=False)
            if on_full and self.long_presses:
                self.long_presses -= 1
                self.after(900, lambda: self.post('touchend', x=round(x), y=round(y), trusted=True,
                                                  focus=self.focus, active=False))
                return
            active = not (on_full and self.no_activation)
            self.post('touchend', x=round(x), y=round(y), trusted=True, focus=self.focus, active=active)
            if y >= self.TABS_TOP:
                self.card = isc.TABS[int(x // (self.W / len(isc.TABS)))]
            elif on_full and active:
                self.ask()

    def screenshot(self, path):
        pass

    # the page
    def set_focus(self, what):
        if what != self.focus:
            self.focus = what
            self.post('focus', to=what)
            self.rule()

    def set_full(self, full):
        if full != self.full:
            self.full = full
            self.post('fullscreenchange', full=full, focus=self.focus)
            if not full and self.fixed:
                self.set_focus('engine-input')

    def ask(self):
        if self.fixed:
            self.focus = 'body'
        self.post('asked', focus=self.focus)
        if self.unfixed:
            self.set_focus('engine-input')
        if self.refuse:
            self.post('fullscreenerror', focus=self.focus)
            return

        def come():
            self.set_full(True)
            self.rule()
        self.after(30, come)

    def rule(self):
        if self.rule_on and self.full and self.focus == 'engine-input':
            self.after(1300, lambda: self.set_full(False))


class Pictures(unittest.TestCase):
    def test_a_screenshot_simctl_does_not_take_is_left_out(self):
        # the iOS 26 run on main of 20 Nov 2026 stopped at its first
        # screenshot ("timed out after 60 seconds"), though nothing the
        # check judges had failed: a picture is for the people who read
        # the run, not a step of the check
        said, asked = [], []

        def hang(cmd, **kwargs):
            asked.append(cmd)
            raise subprocess.TimeoutExpired(cmd, kwargs.get('timeout'))

        run, log = isc.subprocess.run, isc.log
        isc.subprocess.run, isc.log = hang, said.append
        try:
            isc.Simulator('UDID').screenshot('/nowhere/1-home.png')
        finally:
            isc.subprocess.run, isc.log = run, log
        self.assertEqual(asked, [['xcrun', 'simctl', 'io', 'UDID', 'screenshot', '/nowhere/1-home.png']])
        self.assertEqual(said, ['  no screenshot 1-home.png: simctl did not take it within 60 s'])


class Opening(unittest.TestCase):
    def simulate(self, run):
        said = []
        was_run, was_log = isc.subprocess.run, isc.log
        isc.subprocess.run, isc.log = run, said.append
        try:
            isc.Simulator('UDID').open_url('http://localhost:8765/PhoneStarter.html')
        finally:
            isc.subprocess.run, isc.log = was_run, was_log
        return said

    def test_an_openurl_that_does_not_answer_leaves_it_to_the_page(self):
        # the iOS 18.5 run of #603 (20 Nov 2026): simctl openurl did not
        # answer in 120 s on a newly booted iPad, where green runs had the
        # page loaded 31 to 64 s after asking; whether the page opened is
        # the page's to say (it posts "loaded"), not simctl's
        asked = []

        def hang(cmd, **kwargs):
            asked.append((cmd, kwargs.get('timeout')))
            raise subprocess.TimeoutExpired(cmd, kwargs.get('timeout'))

        said = self.simulate(hang)
        self.assertEqual(asked, [(['xcrun', 'simctl', 'openurl', 'UDID', 'http://localhost:8765/PhoneStarter.html'],
                                  isc.OPEN_WAIT)])
        self.assertEqual(said, ['  simctl openurl did not answer within %d s: the page has %d s more to say it '
                                'opened' % (isc.OPEN_WAIT, isc.LOAD_WAIT)])

    def test_an_openurl_that_fails_fails(self):
        def refuse(cmd, **kwargs):
            return subprocess.CompletedProcess(cmd, 1, 'An error was encountered', '')

        with self.assertRaisesRegex(isc.CheckError, 'simctl openurl failed: An error was encountered'):
            self.simulate(refuse)

    def test_a_page_that_never_says_it_opened_fails(self):
        class Silent(FakeIPad):
            def open_url(self, url):
                pass

        record, commands = isc.Record(), isc.Commands()
        was = isc.LOAD_WAIT
        isc.LOAD_WAIT = 0.2
        try:
            with self.assertRaisesRegex(isc.CheckError, r'the page posted nothing within 0\.2 s of opening'):
                isc.check(Silent(record, commands), record, commands, 'http://localhost/' + isc.PAGE)
        finally:
            isc.LOAD_WAIT = was


class Driving(unittest.TestCase):
    def setUp(self):
        self.pauses = dict(isc.PAUSES)
        for k in isc.PAUSES:
            isc.PAUSES[k] = 0
        self.log, isc.log = isc.log, lambda *args: None

    def tearDown(self):
        isc.PAUSES.update(self.pauses)
        isc.log = self.log

    def drive(self, **kwargs):
        record, commands = isc.Record(), isc.Commands()
        ipad = FakeIPad(record, commands, **kwargs)
        try:
            problems = isc.check(ipad, record, commands, 'http://localhost/' + isc.PAGE)
        finally:
            ipad.stopped = True
        return problems, ipad, record

    def test_the_engine_of_dp2_keeps_full_screen(self):
        problems, ipad, record = self.drive()
        self.assertEqual(problems, [])
        # the Phone tab, Full screen, the tab again in full screen, the tab
        # after it, Full screen for the control (after the two calibration
        # clicks)
        self.assertEqual(len(ipad.clicks), 7)
        self.assertEqual([e['command'] for e in record.since() if e['kind'] == 'done'], ['leave', 'unfix'])

    def test_the_engine_before_dp2_loses_it(self):
        # CamelCaps' report: full screen, and in a split second it comes back
        problems, ipad, record = self.drive(fixed=False)
        self.assertIn('full screen stays for 6 s (before 0.2.8-dp.2 it was taken back after about 1.3 s)',
                      problems)
        self.assertIn('the page asks for full screen, with the engine\'s input without the focus', problems)
        self.assertIn('the engine\'s input never has the focus in full screen', problems)

    def test_a_simulator_without_the_rule_fails_the_control(self):
        problems, ipad, record = self.drive(rule=False)
        self.assertEqual(len(problems), 1, problems)
        self.assertIn('so this check can see the bug it is for', problems[0])

    def test_the_page_is_found_again_after_full_screen(self):
        # the control's tap where the Full button was before would land 60
        # pixels below it, outside it
        problems, ipad, record = self.drive(smaller_bar=True)
        self.assertEqual(problems, [])
        self.assertTrue(FakeIPad.FULL[1] <= ipad.clicks[-1][1] <= FakeIPad.FULL[3], ipad.clicks)

    def test_a_tap_the_simulator_held_as_a_long_press_is_tapped_again(self):
        # the iOS 26 run of #597 (20 Nov 2026): the tap on Full screen
        # came to the page 874 ms after its touchstart, with no user
        # activation, and the page asked nothing
        problems, ipad, record = self.drive(long_presses=2)
        self.assertEqual(problems, [])
        full = [c for c in ipad.clicks if FakeIPad.FULL[1] <= c[1] <= FakeIPad.FULL[3]]
        self.assertEqual(len(full), 4, ipad.clicks)

    def test_a_tap_held_every_time_fails_as_such(self):
        problems, ipad, record = self.drive(long_presses=10)
        self.assertIn('the tap on Full screen is a tap to the browser, not a long press (3 tries)', problems)
        full = [c for c in ipad.clicks if FakeIPad.FULL[1] <= c[1] <= FakeIPad.FULL[3]]
        self.assertEqual(len(full), 3, ipad.clicks)

    def test_a_quick_tap_without_activation_is_not_tapped_again(self):
        # only a long press is the Simulator's: a tap that gives the page
        # no activation is the page's own failure
        problems, ipad, record = self.drive(no_activation=True)
        self.assertIn('the page asks for full screen, with the engine\'s input without the focus', problems)
        self.assertNotIn('the tap on Full screen is a tap to the browser, not a long press (3 tries)', problems)
        full = [c for c in ipad.clicks if FakeIPad.FULL[1] <= c[1] <= FakeIPad.FULL[3]]
        self.assertEqual(len(full), 1, ipad.clicks)

    def test_the_control_tap_is_tapped_again_too(self):
        # the tap of step 6 also needs the browser's activation
        record, commands = isc.Record(), isc.Commands()

        class HeldLast(FakeIPad):
            def click(self, point):
                # the first click after the page is unfixed is the
                # control's tap on Full screen
                with self.lock:
                    if self.unfixed and not getattr(self, 'held_once', False):
                        self.held_once = True
                        self.long_presses = 1
                FakeIPad.click(self, point)

        ipad = HeldLast(record, commands)
        try:
            problems = isc.check(ipad, record, commands, 'http://localhost/' + isc.PAGE)
        finally:
            ipad.stopped = True
        self.assertEqual(problems, [])

    def test_a_refusal_fails(self):
        problems, ipad, record = self.drive(refuse=True)
        self.assertEqual(problems, ['the page goes full screen'])

    def test_a_click_that_reaches_nothing_fails(self):
        class Deaf(FakeIPad):
            def click(self, point):
                self.clicks.append(point)

        record, commands = isc.Record(), isc.Commands()
        ipad = Deaf(record, commands)
        said = []
        isc.TOUCH_WAIT, isc.log = 0.3, said.append
        try:
            with self.assertRaisesRegex(isc.CheckError, r'reached the page as no touch \(3 clicks; the page '
                                                        r'posted \d+ events meanwhile, the last state\)'):
                isc.check(ipad, record, commands, 'http://localhost/' + isc.PAGE)
        finally:
            ipad.stopped = True
            isc.TOUCH_WAIT = 6
        self.assertEqual(len(ipad.clicks), isc.TAP_TRIES)
        # each time the Simulator is brought to the front again
        self.assertEqual(sum('clicking again' in s for s in said), isc.TAP_TRIES - 1)

    def test_a_click_the_simulator_did_not_pass_on_is_made_again(self):
        # the iOS 18.5 run of #603 (20 Nov 2026): the run's first click on
        # the Simulator's window, where the three green runs before it had
        # clicked, reached the page as no touch within 6 s
        class LosesFirst(FakeIPad):
            lost, windows = 1, 0

            def window(self):
                self.windows += 1
                return FakeIPad.window(self)

            def click(self, point):
                if self.lost:
                    self.lost -= 1
                    self.clicks.append(None)
                    return
                FakeIPad.click(self, point)

        record, commands = isc.Record(), isc.Commands()
        ipad = LosesFirst(record, commands)
        isc.TOUCH_WAIT = 0.3
        try:
            problems = isc.check(ipad, record, commands, 'http://localhost/' + isc.PAGE)
        finally:
            ipad.stopped = True
            isc.TOUCH_WAIT = 6
        self.assertEqual(problems, [])
        self.assertEqual(ipad.clicks[0], None)
        self.assertEqual(len(ipad.clicks), 8)
        # the first, and again before the click made again
        self.assertEqual(ipad.windows, 2)

    def test_a_page_that_posts_nothing_is_said_so(self):
        class Deaf(FakeIPad):
            def click(self, point):
                self.stopped = True

        record, commands = isc.Record(), isc.Commands()
        ipad = Deaf(record, commands)
        isc.TOUCH_WAIT, isc.TAP_TRIES = 0.3, 1
        try:
            with self.assertRaisesRegex(isc.CheckError, r'\(1 click; the page posted nothing meanwhile\)'):
                isc.check(ipad, record, commands, 'http://localhost/' + isc.PAGE)
        finally:
            ipad.stopped = True
            isc.TOUCH_WAIT, isc.TAP_TRIES = 6, 3


# ----------------------------------------------------------------- reporter

# The reporter in a page of plain objects: the window's and the document's
# listeners, fetch (the server), the timers on a clock of the harness's,
# the engine's hidden input, and the engine's own wrapper of the request
# for full screen (which blurs its input), installed after the reporter as
# the engine installs it
REPORTER_HARNESS = r'''
var fs = require('fs');
var source = fs.readFileSync(process.argv[process.argv.length - 1], 'utf8');
var listeners = {window: {}, document: {}};
function adder(where) {
  return function(type, fn) { (listeners[where][type] = listeners[where][type] || []).push(fn); };
}
function fire(where, type, e) { (listeners[where][type] || []).forEach(function(fn) { fn(e || {}); }); }
var clock = 0, timers = [], posted = [], commands = [], exits = 0, asks = 0;
function Element(tag, extra) { this.tagName = tag; for (var k in extra) this[k] = extra[k]; }
Element.prototype.requestFullscreen = function() { asks++; return Promise.resolve(); };
var body = new Element('BODY'), html = new Element('HTML');
var input = new Element('INPUT', {type: 'text', focus: function() {
  document.activeElement = input; fire('window', 'focusin', {target: input}); }});
var mwc = 'card=Home\nrect=0,0,810,1080\ntabs=1020\nlabels=Full:Full screen\nbuttons=Full:1,2,3,4\nsaid=x';
global.window = global;
global.addEventListener = adder('window');
global.innerWidth = 810;
global.innerHeight = 1080;
global.Element = Element;
// (node has a navigator of its own, which a plain assignment leaves as it is)
Object.defineProperty(global, 'navigator', {configurable: true, writable: true,
  value: {userAgent: 'test', platform: 'MacIntel', maxTouchPoints: 5, userActivation: {isActive: true}}});
global.performance = {now: function() { return clock; }};
global.setTimeout = function(fn, ms) { timers.push({at: clock + (ms || 0), fn: fn}); };
global.setInterval = function(fn, ms) { timers.push({at: clock + ms, fn: fn, every: ms}); };
global.fetch = function(url, opts) {
  if (url === '/ipad/log') {
    JSON.parse(opts.body).forEach(function(e) { posted.push(e); });
    return Promise.resolve({ok: true});
  }
  var c = commands.length ? commands.shift() : '';
  return Promise.resolve({ok: true, text: function() { return Promise.resolve(c); }});
};
global.document = {
  addEventListener: adder('document'), activeElement: body, body: body, documentElement: html,
  fullscreenElement: null,
  querySelector: function(q) { return q === 'input[inputmode="none"]' ? input : null; },
  exitFullscreen: function() { exits++; return Promise.resolve(); },
  liveCode: {findStackWithName: function(n) { return n === 'MobileWebCheck' ? {mwcState: function() { return mwc; }} : null; }}
};
(0, eval)(source);

// the engine, after the reporter: it blurs its input when the page asks,
// and when the page is full screen
var reporterAsk = Element.prototype.requestFullscreen;
Element.prototype.requestFullscreen = function() {
  if (document.activeElement === input) document.activeElement = body;
  return reporterAsk.apply(this, arguments);
};
function engineChange() { if (document.fullscreenElement && document.activeElement === input) document.activeElement = body; }
document.addEventListener('fullscreenchange', engineChange);

async function advance(ms) {
  var end = clock + ms;
  for (;;) {
    timers.sort(function(a, b) { return a.at - b.at; });
    var next = timers.length && timers[0].at <= end ? timers.shift() : null;
    if (!next) break;
    clock = next.at;
    if (next.every) timers.push({at: clock + next.every, fn: next.fn, every: next.every});
    next.fn();
    for (var i = 0; i < 5; i++) await new Promise(function(r) { setImmediate(r); });
  }
  clock = end;
}
function since(n) { return posted.slice(n); }
function goFull(on) { document.fullscreenElement = on ? html : null; fire('document', 'fullscreenchange'); }

(async function() {
  var out = {};
  await advance(1000);
  out.start = since(0);
  var n = posted.length;
  fire('window', 'touchstart', {changedTouches: [{clientX: 100.4, clientY: 200.6}], isTrusted: true});
  input.focus();
  await advance(500);
  out.touch = since(n);
  n = posted.length;
  html.requestFullscreen();
  goFull(true);
  await advance(500);
  out.asked = since(n);
  out.focusInFull = document.activeElement === input ? 'input' : 'body';
  n = posted.length;
  commands.push('leave');
  await advance(500);
  goFull(false);
  await advance(500);
  out.left = since(n);
  out.exits = exits;
  n = posted.length;
  commands.push('unfix');
  await advance(500);
  input.focus();
  html.requestFullscreen();
  out.focusAfterAsk = document.activeElement === input ? 'input' : 'body';
  goFull(true);
  out.focusAfterChange = document.activeElement === input ? 'input' : 'body';
  await advance(50);
  out.focusLater = document.activeElement === input ? 'input' : 'body';
  await advance(500);
  out.unfixed = since(n);
  n = posted.length;
  await advance(5000);
  out.quiet = since(n);
  out.asks = asks;
  var d = window.__oxtIPadReporter.describe;
  out.described = [d(new Element('BUTTON', {type: 'button', id: 'go'})), d(body), d(html), d(input), d(null)];
  console.log(JSON.stringify(out));
})();
'''


@unittest.skipIf(NODE is None, 'no node')
class Reporter(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        run = subprocess.run([NODE, '-e', REPORTER_HARNESS, isc.REPORTER], capture_output=True, text=True,
                             timeout=60)
        if run.returncode != 0:
            raise AssertionError('node: %s' % run.stderr.strip()[-800:])
        cls.out = json.loads(run.stdout)

    def kinds(self, events):
        return [e['kind'] for e in events]

    def test_it_says_it_loaded_and_what_the_stack_shows(self):
        loaded, state = self.out['start'][0], self.out['start'][1]
        self.assertEqual((loaded['kind'], loaded['platform'], loaded['touchPoints']), ('loaded', 'MacIntel', 5))
        self.assertEqual((state['kind'], state['card'], state['rect'], state['tabs'], state['full']),
                         ('state', 'Home', '0,0,810,1080', '1020', False))
        self.assertEqual((state['labels'], state['buttons']), ('Full:Full screen', 'Full:1,2,3,4'))
        self.assertNotIn('said', state)

    def test_it_says_where_a_finger_was(self):
        touch = [e for e in self.out['touch'] if e['kind'] == 'touchstart'][0]
        self.assertEqual((touch['x'], touch['y'], touch['trusted'], touch['active'], touch['focus']),
                         (100, 201, True, True, 'body'))
        self.assertIn({'kind': 'focus', 'to': 'engine-input', 't': touch['t']}, self.out['touch'])

    def test_it_says_what_had_the_focus_when_the_browser_got_the_request(self):
        asked = [e for e in self.out['asked'] if e['kind'] == 'asked'][0]
        # the engine blurred its input before the request reached the browser
        self.assertEqual((asked['how'], asked['focus']), ('requestFullscreen', 'body'))
        change = [e for e in self.out['asked'] if e['kind'] == 'fullscreenchange'][0]
        self.assertEqual((change['full'], change['w'], change['h']), (True, 810, 1080))
        self.assertEqual(self.out['focusInFull'], 'body')

    def test_leave_leaves_full_screen(self):
        self.assertEqual(self.out['exits'], 1)
        self.assertIn('done', self.kinds(self.out['left']))
        self.assertIn(False, [e['full'] for e in self.out['left'] if e['kind'] == 'fullscreenchange'])

    def test_unfix_gives_the_engine_input_the_focus_as_before_dp2(self):
        self.assertEqual([e.get('command') for e in self.out['unfixed'] if e['kind'] == 'done'], ['unfix'])
        # when the page asks, and again after the engine blurred its input
        # as the page went full screen
        self.assertEqual((self.out['focusAfterAsk'], self.out['focusAfterChange'], self.out['focusLater']),
                         ('input', 'body', 'input'))
        self.assertEqual([e['focus'] for e in self.out['unfixed'] if e['kind'] == 'unfixed'],
                         ['engine-input', 'engine-input'])
        self.assertEqual(self.out['asks'], 2)

    def test_a_quiet_page_still_says_its_state(self):
        # every 2 s whatever happens, so that "it stayed so" has a time
        times = [e['t'] for e in self.out['quiet'] if e['kind'] == 'state']
        self.assertGreaterEqual(len(times), 2)
        self.assertTrue(all(b - a <= 2400 for a, b in zip(times, times[1:])), times)

    def test_what_has_the_focus_is_named(self):
        self.assertEqual(self.out['described'], ['button:button#go', 'body', 'html', 'engine-input', 'none'])


# ----------------------------------------------------------------- workflow

class Workflow(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        with open(WORKFLOW, encoding='utf-8') as f:
            cls.text = f.read()
        cls.wf = yaml.safe_load(cls.text)

    def steps(self, job):
        return self.wf['jobs'][job]['steps']

    def runs(self, job):
        return '\n'.join(s.get('run', '') for s in self.steps(job))

    def test_it_runs_for_what_can_change_the_answer(self):
        on = self.wf[True]
        self.assertIn('workflow_dispatch', on)
        paths = on['pull_request']['paths']
        self.assertEqual(on['push']['paths'], paths)
        self.assertEqual(on['push']['branches'], ['main'])
        for path in ('.github/workflows/ipad-simulator.yml', 'tools/ci/ipad_simulator_check.py',
                     'tools/ci/ipad-simulator-reporter.js', 'engine/src/em-event.js',
                     'extensions/script-libraries/mobileweb/mobileweb.livecodescript',
                     'tools/web-player/stacks/Phone Starter.oxtstack',
                     'tools/ci/mobile-web-check.livecodescript', 'tools/ci/mobile-web-deploy.livecodescript'):
            self.assertIn(path, paths)
        for path in paths:
            self.assertTrue(os.path.exists(os.path.join(REPO, path)), path)

    def test_the_runtime_is_the_commits(self):
        web = self.wf['jobs']['web']
        self.assertEqual(web['uses'], './.github/workflows/web.yml')
        self.assertFalse(web['with'].get('check', False))
        artifact = web['with']['artifact']
        download = [s for s in self.steps('stage') if 'download-artifact' in s.get('uses', '')][0]
        self.assertEqual(download['with']['name'], artifact)

    def test_the_page_is_made_on_linux_and_tapped_on_the_mac(self):
        self.assertEqual(self.wf['jobs']['stage']['needs'], 'web')
        self.assertIn('tools/ci/ipad_simulator_check.py stage --runtime', self.runs('stage'))
        upload = [s for s in self.steps('stage') if 'upload-artifact' in s.get('uses', '')][0]
        ipad = self.wf['jobs']['ipad']
        self.assertEqual(ipad['needs'], 'stage')
        self.assertTrue(ipad['runs-on'].startswith('macos-'))
        self.assertEqual(ipad['strategy']['matrix']['ios'], ['18.5', '26'])
        self.assertFalse(ipad['strategy']['fail-fast'])
        download = [s for s in self.steps('ipad') if 'download-artifact' in s.get('uses', '')][0]
        self.assertEqual(download['with']['name'], upload['with']['name'])
        runs = self.runs('ipad')
        self.assertIn('ipad_simulator_check.py pick "$IOS"', runs)
        self.assertIn('xcrun simctl bootstatus "$udid" -b', runs)
        self.assertIn('ipad_simulator_check.py drive --site', runs)
        last = self.steps('ipad')[-1]
        self.assertEqual(last.get('if'), 'always()')

    def test_it_can_only_read(self):
        self.assertEqual(self.wf['permissions'], {'contents': 'read'})
        for job in ('stage', 'ipad'):
            checkout = [s for s in self.steps(job) if s.get('uses', '').startswith('actions/checkout')][0]
            self.assertIs(checkout['with']['persist-credentials'], False)

    def test_apt_asks_the_public_name_servers_first(self):
        # through tools/ci/apt-install.sh, which asks them before apt does
        # (test_apt_retry.py, test_the_name_servers_come_first) and tries a
        # package server that is out again; apt-get itself, never
        run = self.runs('stage')
        self.assertIn('bash "$GITHUB_WORKSPACE/tools/ci/apt-install.sh" "${missing[@]}"', run)
        self.assertNotIn('apt-get', run)

    def test_the_builds_do_not_start_for_it(self):
        for build in ('build-linux.yml', 'build-windows.yml', 'build-macos.yml'):
            with open(os.path.join(REPO, '.github', 'workflows', build), encoding='utf-8') as f:
                ignore = yaml.safe_load(f)[True]['push']['paths-ignore']
            for path in ('.github/workflows/ipad-simulator.yml', 'tools/ci/ipad_simulator_check.py',
                         'tools/ci/ipad-simulator-reporter.js'):
                self.assertIn(path, ignore, build)


if __name__ == '__main__':
    unittest.main()
