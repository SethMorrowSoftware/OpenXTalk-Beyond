#!/usr/bin/env python3
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

"""Full screen from a tap, in Safari on Apple's iPad simulator, with the web
engine of the checkout.

The forum's report on 0.2.8-dp.1 (CamelCaps, an iPad with iPadOS 18.5,
Safari and Chrome): the Phone Starter's "Full screen" goes full screen
"but in a split second it comes back". WebKit ends a page's full screen
on an iPhone or an iPad when a text input takes the focus (its bug
185617), and the web engine's hidden text input had the focus from the
first press. 0.2.8-dp.2 keeps the input without the focus there while the
page asks for full screen and is full screen (engine/src/em-event.js,
_watchFullScreen). WebKit's rule is in no browser on Linux, so this runs
the Phone Starter, built with the checkout's web runtime, in Safari on the
iPad simulator of a Mac, tapped as a finger taps it: Safari opened by
`simctl openurl` (no automation, whose taps give the page no user
activation) and the mouse clicked on the Simulator's window (a Quartz
event, which the Simulator makes a touch of; System Events' clicks are
refused). A script in the page's head (ipad-simulator-reporter.js) posts
what the page does to this script's server, and takes its commands.

  stage --runtime DIR (--engine FILE | --engine-cache DIR) --out DIR
      (on Linux) the Phone Starter as an HTML5 standalone, made as
      tools/ci/mobile_web_check.py makes it (with its check stack,
      MobileWebCheck, which says what the stack shows), the reporter in
      its page: the folder to serve on the Mac
  pick VERSION
      reads `xcrun simctl list devices available -j` on stdin and prints
      the UDID of the iPad to boot: of iOS VERSION ("18.5"), or of the
      newest system of a major version ("26")
  drive --site DIR --udid UDID [--out DIR] [--port N]
      (on the Mac, the iPad booted and the Simulator's window open)
      serves the folder and checks, in order:
        1. the page opens and the stack fills the window; two clicks on
           its Home card give where a click on the window lands in the
           page (each axis: the window's points = a * the page's CSS
           pixels + b); a click that reaches the page as no touch is
           made again, TAP_TRIES times in all (TOUCH_WAIT)
        2. a tap on the Phone tab goes to Phone
        3. a tap on "Full screen": a touch the browser made reaches the
           page, the page asks for full screen with something else than
           the engine's input focused, goes full screen and STAYS so for
           HOLD seconds (the bug took it back after 1.2 to 1.4 s); the
           engine's input never has the focus, and the button then says
           "Show the bars" (a tap that a busy Mac held so long that the
           browser took it as a long press, which gives the page no user
           activation, is tapped again, TAP_TRIES times in all: LONG_PRESS)
        4. a second press, on the Phone tab, while full screen: the page
           stays full screen (a press gave the input the focus)
        5. the page leaves full screen (its own call, no tap): the button
           says "Full screen" again and the stack fills the window; a tap
           on the Phone tab says where the page is now (Safari's bars may
           come back smaller than they were)
        6. the control: the engine made to do what it did before
           0.2.8-dp.2 (the reporter's "unfix": its input with the focus
           when the page asks and in full screen), a tap on "Full screen"
           again: full screen comes and WebKit TAKES IT BACK. Without
           that, this simulator does not apply WebKit's rule and steps 3
           and 4 prove nothing, so the check fails.
      Screenshots of the iPad at each step and the page's events
      (events.json) go in --out. Ends with "IPAD SIMULATOR CHECK OK" or a
      list of what failed, and exit status 1.

.github/workflows/ipad-simulator.yml runs it on iOS 18.5 (the report's
system) and the newest iOS 26.
"""

import argparse
import http.server
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import threading
import time

HERE = os.path.dirname(os.path.abspath(__file__))
REPORTER = os.path.join(HERE, 'ipad-simulator-reporter.js')
REPORTER_NAME = 'ipad-reporter.js'
PAGE = 'PhoneStarter.html'
TABS = ['Home', 'List', 'Form', 'Gestures', 'Phone']
LABEL_OFF = 'Full screen'
LABEL_ON = 'Show the bars'

# Seconds of the page's time that full screen must stay after the tap
# (the engine before 0.2.8-dp.2 lost it after 1.2 to 1.4 s on the iPad
# simulator, iOS 18.5 and 26), and after a press in full screen
HOLD = 6.0
HOLD_AFTER_PRESS = 4.0
# The control: how soon after full screen came WebKit must take it back
TAKEN_BACK_WITHIN = 8.0

# Pauses of the driver's own, in seconds of the wall clock (a test of the
# driver sets them to nothing): after a click, for the page to be drawn
# again; after the tab, for the push effect, in which the engine takes no
# touches
PAUSES = {'click': 0.8, 'effect': 0.9, 'settle': 1.0}

# A tap that must give the page the browser's user activation (Full
# screen) is tapped again, up to TAP_TRIES times in all, when the browser
# took it as a long press: no activation, and held LONG_PRESS ms of the
# page's time or more (UIKit's long press starts at 500 ms). On a busy Mac
# the Simulator can hold a click that long: in the iOS 26 run of #597 (20
# Nov 2026) the tap on Full screen ended 874 ms after it began, gave no
# activation, and the page (mobileweb's noTap()) rightly asked nothing.
# A quick tap without activation is not tapped again: that is the page's.
LONG_PRESS = 500
TAP_TRIES = 3

# Seconds of the wall clock a click has to reach the page as a touch. A
# calibration click that reaches it as none is made again, TAP_TRIES
# times in all, with the Simulator brought to the front again before
# each: in the iOS 18.5 run of #603 (20 Nov 2026) the run's first click,
# at the point of the Simulator's window where the three green runs
# before it had clicked, reached the page as no touch. What the page
# posted meanwhile is said: a page still posting its states (every 2 s)
# had a click the Simulator did not pass on; one posting nothing had
# stopped, and no click will help.
TOUCH_WAIT = 6

# Where the calibration clicks go, as fractions of the Simulator's window:
# inside the iPad's screen, on the Home card's text (or its Buzz button,
# which does nothing a check sees), never on Safari's bars
CALIBRATION = [(0.40, 0.45), (0.62, 0.62)]


class CheckError(Exception):
    pass


def log(msg=''):
    print(msg, flush=True)


# ---------------------------------------------------------------- staging

def inject_reporter(page):
    """The standalone's page with the reporter loaded first, in its head:
    before the engine, which wraps the browser's request for full screen
    around the reporter's."""
    if REPORTER_NAME in page:
        raise CheckError('the page already loads %s' % REPORTER_NAME)
    if page.count('</head>') != 1:
        raise CheckError('the page has %d </head> (one is needed for the reporter)' % page.count('</head>'))
    return page.replace('</head>', '<script src=%s></script></head>' % REPORTER_NAME)


def stage(runtime, engine, engine_cache, out, timeout):
    sys.path.insert(0, HERE)
    import mobile_web_check
    import web_check
    version, js, wasm, html = web_check.runtime_files(runtime)
    engine = engine or web_check.fetch_engine(engine_cache)
    work = tempfile.mkdtemp(prefix='ipad-stage-')
    try:
        log('Deploying %s with %s' % (mobile_web_check.STARTER, engine))
        data = mobile_web_check.deploy(engine, runtime, version, mobile_web_check.STARTER, work, timeout)
        shutil.rmtree(out, ignore_errors=True)
        web_check.make_standalone(runtime, js, wasm, html, data, out, title='Phone Starter')
    finally:
        shutil.rmtree(work, ignore_errors=True)
    built = os.path.join(out, web_check.STACK_NAME + '.html')
    with open(built, encoding='utf-8') as f:
        page = inject_reporter(f.read())
    os.remove(built)
    with open(os.path.join(out, PAGE), 'w', encoding='utf-8') as f:
        f.write(page)
    shutil.copyfile(REPORTER, os.path.join(out, REPORTER_NAME))
    log('Staged %s' % ', '.join(sorted(os.listdir(out))))


# ------------------------------------------------------------- the iPad

def pick(devices, version):
    """(udid, name, runtime) of the iPad to boot, from `simctl list devices
    available -j`: of iOS MAJOR.MINOR, or of the newest system of MAJOR; a
    plain iPad before an Air, a mini or a Pro"""
    wanted = [int(n) for n in version.split('.')]
    best = None
    for runtime, entries in devices.get('devices', {}).items():
        m = re.search(r'iOS-(\d+)-(\d+)', runtime)
        if not m:
            continue
        found = (int(m.group(1)), int(m.group(2)))
        if list(found[:len(wanted)]) != wanted:
            continue
        for d in entries:
            name = d.get('name', '')
            if not d.get('isAvailable') or not name.startswith('iPad'):
                continue
            rank = (found, 1 if name.startswith('iPad (') else 0, name)
            if best is None or rank > best[0]:
                best = (rank, d['udid'], name, runtime)
    if best is None:
        raise CheckError('no iPad among the available simulators of iOS %s' % version)
    return best[1], best[2], best[3]


class Mapping:
    """Where a point of the page (CSS pixels) is on the Mac's screen: on
    each axis, the window's points = a * the page's pixels + b"""

    def __init__(self, ax, bx, ay, by):
        self.ax, self.bx, self.ay, self.by = ax, bx, ay, by

    def to_mac(self, x, y):
        return int(round(self.ax * x + self.bx)), int(round(self.ay * y + self.by))

    def moved(self, page_point, mac_point):
        """The same scale (the screen's), the page where a click at
        mac_point landed at page_point"""
        return Mapping(self.ax, mac_point[0] - self.ax * page_point[0],
                       self.ay, mac_point[1] - self.ay * page_point[1])

    def __repr__(self):
        return 'x * %.4f + %.1f, y * %.4f + %.1f' % (self.ax, self.bx, self.ay, self.by)


def solve(pairs):
    """The Mapping of two (page point, Mac point) pairs: two clicks that
    landed in the page"""
    if len(pairs) != 2:
        raise CheckError('two clicks are needed to find the page on the screen, not %d' % len(pairs))
    (p1, m1), (p2, m2) = pairs
    dx, dy = p2[0] - p1[0], p2[1] - p1[1]
    if abs(dx) < 20 or abs(dy) < 20:
        raise CheckError('the two clicks landed too close in the page (%s and %s)' % (p1, p2))
    ax, ay = (m2[0] - m1[0]) / dx, (m2[1] - m1[1]) / dy
    if ax <= 0 or ay <= 0:
        raise CheckError('the page is not the right way round on the screen (%.3f, %.3f)' % (ax, ay))
    if max(ax, ay) / min(ax, ay) > 1.1:
        raise CheckError('the page is not drawn at one scale (%.3f across, %.3f down)' % (ax, ay))
    return Mapping(ax, m1[0] - ax * p1[0], ay, m1[1] - ay * p1[1])


def rect_of(text):
    try:
        r = [int(round(float(x))) for x in str(text).split(',')]
    except ValueError:
        return None
    return r if len(r) == 4 else None


def fills(state):
    """Whether the stack fills the page's window"""
    return rect_of(state.get('rect')) == [0, 0, state.get('w'), state.get('h')]


def tab_point(state, name):
    """The middle of a tab, in the page's pixels (the stack fills the
    page, so the card's pixels are the page's)"""
    r = rect_of(state.get('rect'))
    tabs = str(state.get('tabs', ''))
    if not r or not tabs.lstrip('-').isdigit():
        raise CheckError('the stack says nothing of its tabs: %s' % state)
    width, height = r[2] - r[0], r[3] - r[1]
    return width * (TABS.index(name) + 0.5) / len(TABS), (int(tabs) + height) / 2


def button_point(state, name):
    for item in str(state.get('buttons', '')).split(';'):
        key, _, value = item.partition(':')
        r = rect_of(value)
        if key == name and r:
            return (r[0] + r[2]) / 2, (r[1] + r[3]) / 2
    raise CheckError('the stack says nothing of its button %s: %s' % (name, state.get('buttons')))


def label_of(state, name):
    for item in str(state.get('labels', '')).split(';'):
        key, _, value = item.partition(':')
        if key == name:
            return value
    return None


# ------------------------------------------------------------- the record

class Record:
    """What the page posted, in order, each event with the time it came
    (got, the wall clock here)"""

    def __init__(self):
        self.events = []
        self.lock = threading.Lock()

    def add(self, events):
        with self.lock:
            for e in events:
                if isinstance(e, dict):
                    self.events.append(dict(e, got=time.time()))

    def mark(self):
        with self.lock:
            return len(self.events)

    def since(self, i=0):
        with self.lock:
            return list(self.events[i:])

    def wait(self, test, seconds, since=0):
        """The first event since the mark that passes test, within the
        seconds; or None"""
        end = time.time() + seconds
        while True:
            for e in self.since(since):
                if test(e):
                    return e
            if time.time() >= end:
                return None
            time.sleep(0.05)

    def until(self, decide, seconds):
        """decide(events), a pair whose first item is True or False, or
        None while it cannot say: until it can, within the seconds"""
        end = time.time() + seconds
        while True:
            answer = decide(self.since())
            if answer[0] is not None or time.time() >= end:
                return answer
            time.sleep(0.05)

    def state(self):
        """The latest state the page posted"""
        for e in reversed(self.since()):
            if e.get('kind') == 'state':
                return e
        return {}


def says_full(e):
    """Whether the page said it was full screen in this event (None: the
    event does not say)"""
    if e.get('kind') in ('fullscreenchange', 'state') and isinstance(e.get('full'), bool):
        return e['full']
    return None


def entered(events, after):
    """The page's time it went full screen, after the page time after (or
    None)"""
    for e in events:
        if e.get('t', -1) > after and e.get('kind') == 'fullscreenchange' and e.get('full') is True:
            return e['t']
    return None


def held(events, start, seconds):
    """(True, None) if the page said it was full screen at every word of
    it from start (the page's time, in ms) to the seconds after, and said
    so after; (False, t) if it said it was not at t; (None, None) while it
    has not said enough"""
    end = start + seconds * 1000
    late = False
    for e in events:
        full, t = says_full(e), e.get('t', -1)
        if full is None or t <= start:
            continue
        if not full:
            return False, t
        if t >= end:
            late = True
    return (True, None) if late else (None, None)


def taken_back(events, start, seconds):
    """(True, t) if the page said it was not full screen at t, after start
    (the page's time, in ms) and within the seconds; (False, None) if it
    said it was full screen after that; (None, None) while it has not said
    enough"""
    end = start + seconds * 1000
    for e in events:
        full, t = says_full(e), e.get('t', -1)
        if full is None or t <= start:
            continue
        if not full:
            return (True, t) if t <= end else (False, None)
        if t > end:
            return False, None
    return None, None


def held_as_long_press(events, touchend):
    """The ms the touch that ended in touchend was held, when the browser
    took it as a long press (see LONG_PRESS); else None. A browser that
    does not say whether it gave activation (null) is not judged."""
    if not touchend or touchend.get('active') is not False:
        return None
    starts = [e for e in events if e.get('kind') == 'touchstart' and e.get('t', 0) <= touchend.get('t', 0)]
    if not starts:
        return None
    held = touchend.get('t', 0) - starts[-1].get('t', 0)
    return held if held >= LONG_PRESS else None


def focused_input(events, after):
    """The page times the engine's hidden input had the focus, after the
    page time after"""
    out = []
    for e in events:
        if e.get('t', -1) <= after:
            continue
        if (e.get('kind') == 'focus' and e.get('to') == 'engine-input') or \
                (e.get('kind') in ('state', 'fullscreenchange') and e.get('focus') == 'engine-input'):
            out.append(e['t'])
    return out


# ------------------------------------------------------------ the server

class Commands:
    """The commands for the page, taken one at a time by its reporter"""

    def __init__(self):
        self.queue = []
        self.lock = threading.Lock()

    def put(self, command):
        with self.lock:
            self.queue.append(command)

    def take(self):
        with self.lock:
            return self.queue.pop(0) if self.queue else ''


def make_server(site, record, commands, port):
    class Handler(http.server.SimpleHTTPRequestHandler):
        extensions_map = dict(http.server.SimpleHTTPRequestHandler.extensions_map,
                              **{'.wasm': 'application/wasm', '.js': 'text/javascript'})

        def __init__(self, *args, **kwargs):
            super().__init__(*args, directory=site, **kwargs)

        def end_headers(self):
            self.send_header('Cache-Control', 'no-store')
            super().end_headers()

        def log_message(self, fmt, *args):
            pass

        def reply(self, code, body=b''):
            self.send_response(code)
            self.send_header('Content-Type', 'text/plain; charset=utf-8')
            self.send_header('Content-Length', str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        def do_GET(self):
            if self.path.split('?')[0] == '/ipad/command':
                return self.reply(200, commands.take().encode('utf-8'))
            return super().do_GET()

        def do_POST(self):
            if self.path.split('?')[0] != '/ipad/log':
                return self.reply(404)
            size = int(self.headers.get('Content-Length') or 0)
            try:
                events = json.loads(self.rfile.read(min(size, 1 << 20)).decode('utf-8', 'replace'))
            except ValueError:
                return self.reply(400)
            record.add(events if isinstance(events, list) else [])
            for e in events if isinstance(events, list) else []:
                if isinstance(e, dict) and e.get('kind') != 'state':
                    log('    page %6s ms: %s' % (e.get('t'), json.dumps(e, sort_keys=True)[:300]))
            return self.reply(204)

    server = http.server.ThreadingHTTPServer(('127.0.0.1', port), Handler)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    return server


# -------------------------------------------------- the Mac and the iPad

def osa(script, javascript=False):
    cmd = ['osascript'] + (['-l', 'JavaScript'] if javascript else []) + ['-e', script]
    try:
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=40)
    except subprocess.TimeoutExpired:
        return 1, 'osascript did not answer in 40 s'
    return r.returncode, (r.stdout + r.stderr).strip()[:300]


WINDOW = '''
tell application "System Events" to tell process "Simulator"
  set frontmost to true
  set p to position of window 1
  set s to size of window 1
  return (item 1 of p as text) & "," & (item 2 of p as text) & "," & (item 1 of s as text) & "," & (item 2 of s as text)
end tell'''

# The same from the window server's list, which asks no permission of
# System Events: the biggest window of the Simulator on the screen
WINDOW_QUARTZ = '''
ObjC.import('CoreGraphics');
var ref = $.CGWindowListCopyWindowInfo($.kCGWindowListOptionOnScreenOnly | $.kCGWindowListExcludeDesktopElements, 0);
var list = ObjC.deepUnwrap(ObjC.castRefToObject(ref));
var best = null;
list.forEach(function(w) {
  if (w.kCGWindowOwnerName != 'Simulator' || w.kCGWindowLayer != 0) return;
  var b = w.kCGWindowBounds;
  if (!best || b.Width * b.Height > best.Width * best.Height) best = b;
});
best ? [best.X, best.Y, best.Width, best.Height].map(Math.round).join(',') : 'no window';
'''

# A click as the mouse makes it, which the Simulator makes a touch of
CLICK_QUARTZ = '''
ObjC.import('CoreGraphics');
var p = $.CGPointMake(%d, %d);
var down = $.CGEventCreateMouseEvent(null, $.kCGEventLeftMouseDown, p, $.kCGMouseButtonLeft);
var up = $.CGEventCreateMouseEvent(null, $.kCGEventLeftMouseUp, p, $.kCGMouseButtonLeft);
$.CGEventPost($.kCGHIDEventTap, down);
delay(0.08);
$.CGEventPost($.kCGHIDEventTap, up);
'''


class Simulator:
    """The booted iPad and the Simulator's window on the Mac's screen"""

    def __init__(self, udid):
        self.udid = udid

    def open_url(self, url):
        r = subprocess.run(['xcrun', 'simctl', 'openurl', self.udid, url], capture_output=True, text=True,
                           timeout=120)
        if r.returncode != 0:
            raise CheckError('simctl openurl failed: %s' % (r.stdout + r.stderr).strip()[:300])

    def window(self):
        """(left, top, width, height) of the Simulator's window"""
        for attempt in range(20):
            subprocess.run(['open', '-a', 'Simulator'], capture_output=True, timeout=60)
            for name, script, javascript in (('System Events', WINDOW, False), ('the window list', WINDOW_QUARTZ, True)):
                code, out = osa(script, javascript)
                numbers = re.findall(r'-?\d+', out) if code == 0 else []
                if len(numbers) == 4 and int(numbers[2]) > 100 and int(numbers[3]) > 100:
                    log('  the Simulator\'s window by %s: %s' % (name, out))
                    return tuple(int(n) for n in numbers)
                log('  the Simulator\'s window by %s: %s (%d)' % (name, out, code))
            time.sleep(3)
        raise CheckError('the Simulator has no window to click on')

    def click(self, point):
        code, out = osa(CLICK_QUARTZ % point, javascript=True)
        if code != 0:
            log('  the click at %s: osascript %d: %s' % (point, code, out))

    def screenshot(self, path):
        """A picture of the iPad for the people who read the run, not a
        step of the check: one that simctl does not take within 60 s is
        left out and said so (the iOS 26 run on main of 20 Nov 2026 stopped
        at the first, though nothing the check judges had failed)."""
        try:
            subprocess.run(['xcrun', 'simctl', 'io', self.udid, 'screenshot', path], capture_output=True,
                           timeout=60)
        except subprocess.TimeoutExpired:
            log('  no screenshot %s: simctl did not take it within 60 s' % os.path.basename(path))


# --------------------------------------------------------------- the drive

def is_state(e):
    return e.get('kind') == 'state'


def check(sim, record, commands, url, out=None):
    """The steps of the module's docstring; the list of what failed"""
    problems = []

    def expect(what, ok, detail=''):
        if ok:
            log('  ok: %s' % what)
        else:
            problems.append(what)
            log('  FAILED: %s%s' % (what, ' (%s)' % detail if detail else ''))
        return ok

    def shot(name):
        if out:
            sim.screenshot(os.path.join(out, name + '.png'))

    def latest():
        s = record.state()
        return 'the page said %s' % json.dumps({k: s.get(k) for k in ('card', 'full', 'focus', 'labels', 'rect')})

    def tap(point, kind='touchstart', seconds=None):
        i = record.mark()
        sim.click(point)
        return i, record.wait(lambda e: e.get('kind') == kind, TOUCH_WAIT if seconds is None else seconds,
                              since=i)

    def meanwhile(i):
        """What the page posted since the mark (see TOUCH_WAIT)"""
        since = record.since(i)
        if not since:
            return 'the page posted nothing meanwhile'
        return 'the page posted %d events meanwhile, the last %s' % (len(since), since[-1].get('kind'))

    def tap_to_activate(point, what):
        """(mark, touchend, held): a tap that must give the page the
        browser's user activation, tapped again while the browser takes it
        as a long press (see LONG_PRESS); held: the ms the last was held,
        when it was still a long press, else None"""
        for attempt in range(1, TAP_TRIES + 1):
            i, touch = tap(point, 'touchend')
            ms = held_as_long_press(record.since(i), touch)
            if ms is None:
                return i, touch, None
            log('  the Simulator held the tap on %s %d ms, a long press to the browser (no user activation)%s'
                % (what, ms, ': tapping again' if attempt < TAP_TRIES else ''))
            time.sleep(PAUSES['click'])
        return i, touch, ms

    # 1. the page, the stack, and where it is on the screen
    log('Opening %s in Safari' % url)
    sim.open_url(url)
    loaded = record.wait(lambda e: e.get('kind') == 'loaded', 90)
    if not loaded:
        raise CheckError('the page posted nothing within 90 s of opening')
    log('  the page: %s, %s, %s touch points, %sx%s' % (loaded.get('agent'), loaded.get('platform'),
                                                       loaded.get('touchPoints'), loaded.get('w'), loaded.get('h')))
    home = record.wait(lambda e: is_state(e) and e.get('card') == 'Home' and fills(e), 240)
    if not expect('the Phone Starter opens and fills the window', home is not None, latest()):
        return problems
    time.sleep(PAUSES['settle'])
    shot('1-home')
    window = sim.window()
    pairs = []
    for fx, fy in CALIBRATION:
        for attempt in range(1, TAP_TRIES + 1):
            left, top, width, height = window
            point = int(round(left + width * fx)), int(round(top + height * fy))
            i, touch = tap(point)
            if touch is not None and touch.get('x') is not None:
                break
            if attempt == TAP_TRIES:
                raise CheckError('a click on the Simulator\'s window at %s reached the page as no touch (%d %s; %s)'
                                 % (point, attempt, 'click' if attempt == 1 else 'clicks', meanwhile(i)))
            log('  a click at %s reached the page as no touch within %s s; %s: bringing the Simulator to the '
                'front and clicking again' % (point, TOUCH_WAIT, meanwhile(i)))
            window = sim.window()
        log('  a click at %s landed at %s, %s in the page' % (point, touch['x'], touch['y']))
        pairs.append(((touch['x'], touch['y']), point))
        time.sleep(PAUSES['click'])
    mapping = solve(pairs)
    log('  the page on the screen: %r' % mapping)

    # 2. the Phone tab
    phone_tab = mapping.to_mac(*tab_point(home, 'Phone'))
    i, touch = tap(phone_tab)
    phone = record.wait(lambda e: is_state(e) and e.get('card') == 'Phone', 8, since=i)
    if not expect('a tap on the Phone tab goes to Phone', phone is not None, latest()):
        return problems
    time.sleep(PAUSES['effect'])
    phone = record.state()
    expect('the Full button says "%s"' % LABEL_OFF, label_of(phone, 'Full') == LABEL_OFF, latest())
    full_button = mapping.to_mac(*button_point(phone, 'Full'))
    before = rect_of(phone.get('rect'))
    shot('2-phone')

    # 3. full screen from the tap, and it stays
    i, touch, long_held = tap_to_activate(full_button, 'Full screen')
    expect('the tap on Full screen reaches the page as a touch the browser made',
           touch is not None and touch.get('trusted') is True, json.dumps(touch))
    expect('the tap on Full screen is a tap to the browser, not a long press (%d tries)' % TAP_TRIES,
           long_held is None, 'the last held %s ms' % long_held)
    asked = record.wait(lambda e: e.get('kind') == 'asked', 6, since=i)
    expect('the page asks for full screen, with the engine\'s input without the focus',
           asked is not None and asked.get('focus') != 'engine-input', json.dumps(asked))
    came = record.wait(lambda e: e.get('kind') in ('fullscreenerror',) or
                       (e.get('kind') == 'fullscreenchange' and e.get('full') is True), 8, since=i)
    if not expect('the page goes full screen', came is not None and came.get('kind') == 'fullscreenchange',
                  json.dumps(came) if came else 'nothing within 8 s'):
        return problems
    t_full = came['t']
    ok, t_left = record.until(lambda events: held(events, t_full, HOLD), HOLD + 8)
    expect('full screen stays for %d s (before 0.2.8-dp.2 it was taken back after about 1.3 s)' % HOLD,
           ok is True, 'taken back after %d ms' % (t_left - t_full) if t_left else latest())
    expect('the engine\'s input never has the focus in full screen', not focused_input(record.since(i), t_full - 1),
           'at %s ms' % focused_input(record.since(i), t_full - 1))
    on = record.wait(lambda e: is_state(e) and label_of(e, 'Full') == LABEL_ON, 6, since=i)
    expect('the Full button says "%s"' % LABEL_ON, on is not None, latest())
    shot('3-full')

    # 4. a press in full screen
    i, touch = tap(phone_tab)
    if expect('a tap in full screen reaches the page', touch is not None, latest()):
        log('  the tap landed at %s, %s in the page' % (touch.get('x'), touch.get('y')))
        ok, t_left = record.until(lambda events: held(events, touch['t'], HOLD_AFTER_PRESS), HOLD_AFTER_PRESS + 8)
        expect('full screen stays for %d s after a press in full screen' % HOLD_AFTER_PRESS, ok is True,
               'taken back %d ms after the press' % (t_left - touch['t']) if t_left else latest())
        expect('the press gives the engine\'s input no focus in full screen',
               not focused_input(record.since(i), touch['t'] - 1),
               'at %s ms' % focused_input(record.since(i), touch['t'] - 1))
    shot('4-pressed')

    # 5. the page leaves full screen
    i = record.mark()
    commands.put('leave')
    gone = record.wait(lambda e: e.get('kind') == 'fullscreenchange' and e.get('full') is False, 10, since=i)
    expect('the page leaves full screen when it asks to', gone is not None, latest())
    off = record.wait(lambda e: is_state(e) and e.get('full') is False and label_of(e, 'Full') == LABEL_OFF and
                      fills(e), 10, since=i)
    expect('the Full button says "%s" again, and the stack fills the window' % LABEL_OFF, off is not None, latest())
    time.sleep(PAUSES['settle'])
    shot('5-left')
    if gone is None or off is None:
        return problems
    if rect_of(record.state().get('rect')) != before:
        log('  the stack is %s now, %s before full screen' % (record.state().get('rect'), before))
    # Safari's bars may come back smaller than they were: a tap on the
    # Phone tab, where it was, says where the page is now (the tab bar is
    # at the bottom of the page, and the page at the bottom of the screen)
    i, touch = tap(phone_tab)
    if not expect('a tap on the Phone tab reaches the page again', touch is not None, latest()):
        return problems
    mapping = mapping.moved((touch['x'], touch['y']), phone_tab)
    log('  the page on the screen now: %r' % mapping)
    time.sleep(PAUSES['effect'])
    full_button = mapping.to_mac(*button_point(record.state(), 'Full'))

    # 6. the control: the engine as it was before 0.2.8-dp.2
    i = record.mark()
    commands.put('unfix')
    done = record.wait(lambda e: e.get('kind') == 'done' and e.get('command') == 'unfix', 10, since=i)
    if not expect('the page is made to do what the engine did before 0.2.8-dp.2', done is not None, latest()):
        return problems
    i, touch, long_held = tap_to_activate(full_button, 'Full screen')
    came = record.wait(lambda e: e.get('kind') == 'fullscreenchange' and e.get('full') is True, 8, since=i)
    if not expect('as before 0.2.8-dp.2, a tap on Full screen goes full screen', came is not None,
                  'the tap held %s ms, a long press, %d times' % (long_held, TAP_TRIES) if long_held
                  else latest()):
        return problems
    back, t_back = record.until(lambda events: taken_back(events, came['t'], TAKEN_BACK_WITHIN),
                                TAKEN_BACK_WITHIN + 8)
    expect('as before 0.2.8-dp.2 (the engine\'s input with the focus), WebKit takes full screen back, '
           'so this check can see the bug it is for', back is True,
           'still full screen %d s later: this simulator does not apply WebKit\'s rule' % TAKEN_BACK_WITHIN
           if back is False else latest())
    if t_back:
        log('  taken back %d ms after it came' % (t_back - came['t']))
    shot('6-unfixed')
    return problems


def drive(site, udid, out, port):
    if not os.path.isfile(os.path.join(site, PAGE)):
        raise CheckError('%s has no %s (stage it first)' % (site, PAGE))
    if out:
        os.makedirs(out, exist_ok=True)
    record, commands = Record(), Commands()
    server = make_server(site, record, commands, port)
    try:
        return check(Simulator(udid), record, commands, 'http://localhost:%d/%s' % (port, PAGE), out)
    finally:
        server.shutdown()
        if out:
            with open(os.path.join(out, 'events.json'), 'w', encoding='utf-8') as f:
                json.dump(record.since(), f, indent=1)


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    sub = ap.add_subparsers(dest='command', required=True)
    s = sub.add_parser('stage', help='make the folder to serve (on Linux)')
    s.add_argument('--runtime', required=True, help='the web runtime folder')
    s.add_argument('--engine', help='a development engine (LiveCode-Community)')
    s.add_argument('--engine-cache', help='download the pinned development engine into this folder')
    s.add_argument('--out', required=True, help='the folder to make')
    s.add_argument('--timeout', type=int, default=300)
    p = sub.add_parser('pick', help='the iPad to boot, from simctl list devices available -j on stdin')
    p.add_argument('version', help='18.5, or 26 for the newest iOS 26')
    d = sub.add_parser('drive', help='serve the folder and tap the page (on the Mac)')
    d.add_argument('--site', required=True)
    d.add_argument('--udid', required=True)
    d.add_argument('--out', help='a folder for the screenshots and the events')
    d.add_argument('--port', type=int, default=8765)
    args = ap.parse_args(argv)
    if args.command == 'stage' and not args.engine and not args.engine_cache:
        ap.error('--engine or --engine-cache is needed')
    try:
        if args.command == 'pick':
            udid, name, runtime = pick(json.load(sys.stdin), args.version)
            sys.stderr.write('picked %s, %s\n' % (name, runtime))
            print(udid)
            return 0
        if args.command == 'stage':
            stage(args.runtime, args.engine, args.engine_cache, args.out, args.timeout)
            return 0
        problems = drive(args.site, args.udid, args.out, args.port)
    except (CheckError, subprocess.TimeoutExpired, OSError) as e:
        log('FAILED: %s' % e)
        return 1
    except Exception as e:
        # mobile_web_check's and web_check's own CheckError (stage)
        if type(e).__name__ != 'CheckError':
            raise
        log('FAILED: %s' % e)
        return 1
    if problems:
        log('IPAD SIMULATOR CHECK FAILED')
        for problem in problems:
            log('  %s' % problem)
        return 1
    log('IPAD SIMULATOR CHECK OK')
    return 0


if __name__ == '__main__':
    sys.exit(main())
