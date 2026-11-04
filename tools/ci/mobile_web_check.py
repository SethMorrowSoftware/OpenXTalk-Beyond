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

"""Check the Mobile Web library and the Phone Starter on emulated phones.

  python3 tools/ci/mobile_web_check.py --runtime DIR (--engine FILE | --engine-cache DIR)
      [--browser chromium|webkit] [--device NAME]... [--rebuild] [--work DIR]
      [--timeout SECONDS] [--shots DIR] [--touch auto|cdp|page]

--runtime, --engine and --engine-cache are tools/ci/web_check.py's: the web
runtime, and the development engine that writes the standalone's startup
data (tools/ci/mobile-web-deploy.livecodescript). The standalone's main
stack is the committed tools/web-player/stacks/Phone Starter.oxtstack, or
with --rebuild a stack that tools/web-player/phone-starter.livecodescript
builds now; beside it go the Mobile Web library
(extensions/script-libraries/mobileweb) and the check's own stack
(tools/ci/mobile-web-check.livecodescript), which reports what the Phone
Starter shows.

Without --rebuild, the committed stack's script must first be
phone-starter-stack.livecodescript's: a change to that file needs the
stack built again.

Each device (Playwright's profiles: by default "Pixel 7" and "iPhone 13"
in Chromium, "iPhone 13" in WebKit; Firefox has no touch screen to
emulate) opens the page with a touch screen and a phone's window, and:

  1. the stack fills the window (mwFillScreen), with its tab bar at the
     bottom, and the Home card says it is on a touch screen in a browser
  2. a tap on the List tab goes to List; a finger dragged up the list
     scrolls it (mwDragScroll) and picks nothing; a tap then picks a line
  3. a swipe right goes back to Home, and a swipe left to List (mwSwipe)
  4. on Form, a tap in Name, typing and Save: the form says it saved
  5. the keyboard: with Notes focused, the library is told that a
     keyboard covers the bottom of the window, and the form moves up so
     that Notes is above it (mwViewportChanged)
  6. on Gestures, two fingers spread on the pad make the dot bigger
     (pinch), a swipe on the pad is reported and stays on the card, a
     finger held still is a long press (longPress), and two fingers held
     down are two rings, gone when they let go (touchStart, touchEnd)
  7. on Phone: "Where am I?" says where the browser is (locationChanged),
     "Take a photo" opens the file chooser and the photo, made 1000
     pixels wide, is put in the frame (mwPickPhoto), "Roll the ball" and
     a tilt roll the ball (accelerationChanged), "Keep screen on" keeps
     it on (mwKeepAwake), and "Share" says what it did (mwShare)
  8. the phone turns: the stack fills the window again, in landscape,
     and on each card its controls end above the tab bar
  9. a stack laid out for a desktop (800 by 500), of a fixed size, is
     fitted to the window by mwStart alone, as it is too big for it: a
     tap where its far corner's button is drawn reaches the button; when
     the phone turns, the stack filled before is left as it was; fitted
     by mwFitStack alone and turned back, it is fitted again
  10. mwStop takes away the style that filling gave the page, and in a
     page that keeps its own layout (data-mobile-web-fill="no", as the
     Stack Player's page has) mwFillScreen fills nothing

Playwright's WebKit on Linux makes no touch events (no Touch
constructor, no touch points), so there the taps and drags are the
mouse's and the gestures (3, and 6 but for the tab) are left out, and
the page has no motion sensor to tilt: WebKit checks the layout, the
fill, the keyboard, the Phone card but for the tilt, the turns and the
fit. A
real iPhone's Safari has touch events; Chromium checks every step.
WebKit runs with as little JavaScript stack as an iPhone gives a page
(IPHONE_STACK).

Without a device the engine's mouse messages are those of a touch; the
library only adds its own. Ends with "MOBILE WEB CHECK OK" or a list of
what failed, and exit status 1.
"""

import argparse
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
sys.path.insert(0, HERE)
import web_check  # noqa: E402

STARTER = os.path.join(REPO, 'tools', 'web-player', 'stacks', 'Phone Starter.oxtstack')
STARTER_BUILDER = os.path.join(REPO, 'tools', 'web-player', 'phone-starter.livecodescript')
STARTER_SCRIPT = os.path.join(REPO, 'tools', 'web-player', 'phone-starter-stack.livecodescript')
LIBRARY = os.path.join(REPO, 'extensions', 'script-libraries', 'mobileweb', 'mobileweb.livecodescript')
CHECK_STACK = os.path.join(HERE, 'mobile-web-check.livecodescript')
DEPLOY_SCRIPT = os.path.join(HERE, 'mobile-web-deploy.livecodescript')
PAGE = 'PhoneStarter.html'
DEFAULT_DEVICES = {'chromium': ['Pixel 7', 'iPhone 13'], 'webkit': ['iPhone 13']}
TABS = ['Home', 'List', 'Form', 'Gestures', 'Phone']
# where the check's browser says it is
WHERE = {'latitude': 51.50735, 'longitude': -0.12776}


class CheckError(Exception):
    pass


# An iPhone's or an iPad's Safari gives a page's script far less stack
# than a desktop's WebKit: a Phone Starter ran out of it as it opened
# there ("Maximum call stack size exceeded", a blank page), while it
# opened in every browser this check ran. So WebKit runs with its
# JavaScript stack cut to IPHONE_STACK bytes (JavaScriptCore's
# maxPerThreadStackUsage option, read from the environment): under it
# that Phone Starter fails at the start, and it fails this check.
IPHONE_STACK = 300000


def launch_options(browser_name):
    if browser_name != 'webkit':
        return {}
    return {'env': dict(os.environ, JSC_maxPerThreadStackUsage=str(IPHONE_STACK))}


def log(msg=''):
    print(msg, flush=True)


def build_starter(engine, work, timeout):
    """A Phone Starter built now by its builder."""
    out = os.path.join(work, 'Phone Starter.oxtstack')
    env = dict(os.environ, OXT_PHONE_STARTER=out)
    r = subprocess.run([engine, '-ui', STARTER_BUILDER], env=env, stdout=subprocess.PIPE,
                       stderr=subprocess.STDOUT, timeout=timeout)
    text = r.stdout.decode('utf-8', 'replace')
    if r.returncode != 0 or 'BUILT' not in text:
        raise CheckError('building the Phone Starter failed: %s' % text.strip())
    return out


def deploy(engine, runtime, version, stack, work, timeout):
    output = os.path.join(work, '__startup.data')
    env = dict(os.environ, OXT_MW_STACK=stack, OXT_MW_LIBRARY=LIBRARY, OXT_MW_CHECK=CHECK_STACK,
               OXT_MW_OUTPUT=output, OXT_MW_VERSION=version,
               OXT_MW_TEMPLATE=os.path.join(runtime, 'emscripten-startup-template.livecodescript'))
    r = subprocess.run([engine, '-ui', DEPLOY_SCRIPT], cwd=work, env=env, stdout=subprocess.PIPE,
                       stderr=subprocess.STDOUT, timeout=timeout)
    text = r.stdout.decode('utf-8', 'replace')
    for line in text.splitlines():
        if line.strip():
            log('  deploy: %s' % line)
    if r.returncode != 0 or 'DEPLOY OK' not in text:
        raise CheckError('deploying the Phone Starter failed')
    return output


def state(page):
    """What the Phone Starter shows (mobile-web-check.livecodescript's
    mwcState), as a dict."""
    text = page.evaluate("() => { var h = document.liveCode && document.liveCode.findStackWithName('MobileWebCheck');"
                         " return h && h.mwcState ? String(h.mwcState()) : ''; }")
    out = {}
    for line in (text or '').split('\n'):
        if '=' in line:
            key, value = line.split('=', 1)
            out[key] = value
    return out


def rect(text):
    try:
        return [int(x) for x in text.split(',')]
    except ValueError:
        return None


def middle(text):
    """The middle of a rectangle "left,top,right,bottom" """
    r = rect(text)
    if not r or len(r) != 4:
        raise CheckError('not a rectangle: %r' % text)
    return (r[0] + r[2]) / 2, (r[1] + r[3]) / 2


# Whether the page can make touch events of its own (Playwright's WebKit
# on Linux has none: "new Touch()" is an illegal constructor there, and
# navigator.maxTouchPoints is 0 whatever the device profile says)
CAN_MAKE_TOUCHES = """() => {
    if (typeof TouchEvent === 'undefined' || typeof Touch === 'undefined') return false;
    try { new Touch({identifier: 1, target: document.body, clientX: 0, clientY: 0}); return true; }
    catch (e) { return false; }
}"""


class Fingers:
    """Touches sent as a touch screen sends them: Chromium's
    Input.dispatchTouchEvent (cdp), or touch events made in the page
    (page). In a browser that can make neither (Playwright's WebKit on
    Linux), the mouse (mouse): taps and drags, but no gestures, which the
    library sees only in touch events; .touches says which."""

    def __init__(self, page, context, browser, touch='auto'):
        self.page = page
        self.cdp = None
        self.mouse = False
        if touch == 'cdp' or (touch == 'auto' and browser == 'chromium'):
            self.cdp = context.new_cdp_session(page)
        elif touch == 'mouse' or not page.evaluate(CAN_MAKE_TOUCHES):
            self.mouse = True
        self.touches = not self.mouse

    def _send(self, kind, points):
        if self.mouse:
            if kind == 'touchStart':
                self.page.mouse.move(*points[0])
                self.page.mouse.down()
            elif kind == 'touchMove':
                self.page.mouse.move(*points[0])
            else:
                self.page.mouse.up()
        elif self.cdp:
            self.cdp.send('Input.dispatchTouchEvent', {
                'type': kind, 'touchPoints': [{'x': x, 'y': y, 'id': i + 1} for i, (x, y) in enumerate(points)]})
        else:
            # touch events made in the page, at the element under the
            # first point, as WebKit would send them
            self.page.evaluate("""([kind, points]) => {
                var target = document.elementFromPoint(points.length ? points[0][0] : 0, points.length ? points[0][1] : 0)
                    || document.querySelector('canvas');
                if (kind !== 'touchEnd') window.__mwcTarget = target; else target = window.__mwcTarget || target;
                var touches = points.map(function(p, i) {
                    return new Touch({identifier: i + 1, target: target, clientX: p[0], clientY: p[1]}); });
                var type = {touchStart: 'touchstart', touchMove: 'touchmove', touchEnd: 'touchend'}[kind];
                // (a touchstart's changed touches are the new fingers only)
                var was = window.__mwcLast || [];
                var changed = !touches.length ? was : kind === 'touchStart' && touches.length > was.length
                    ? touches.slice(was.length) : touches;
                target.dispatchEvent(new TouchEvent(type, {bubbles: true, cancelable: true, composed: true,
                    touches: kind === 'touchEnd' ? [] : touches, targetTouches: kind === 'touchEnd' ? [] : touches,
                    changedTouches: changed}));
                window.__mwcLast = touches.length ? touches : window.__mwcLast;
            }""", [kind, [list(p) for p in points]])

    def drag(self, x0, y0, x1, y1, steps=8, pause=0.02):
        self._send('touchStart', [(x0, y0)])
        for i in range(1, steps + 1):
            self._send('touchMove', [(x0 + (x1 - x0) * i / steps, y0 + (y1 - y0) * i / steps)])
            time.sleep(pause)
        self._send('touchEnd', [])

    def tap(self, x, y):
        self._send('touchStart', [(x, y)])
        time.sleep(0.05)
        self._send('touchEnd', [])

    def hold(self, x, y, seconds=0.9):
        self._send('touchStart', [(x, y)])
        time.sleep(seconds)
        self._send('touchEnd', [])

    def down(self, points):
        """Fingers put down one after another, and left there"""
        for i in range(1, len(points) + 1):
            self._send('touchStart', points[:i])
            time.sleep(0.05)

    def up(self):
        self._send('touchEnd', [])

    def spread(self, x, y, start=30, by=70, steps=6):
        self._send('touchStart', [(x - start, y)])
        self._send('touchStart', [(x - start, y), (x + start, y)])
        for i in range(1, steps + 1):
            d = start + by * i / steps
            self._send('touchMove', [(x - d, y), (x + d, y)])
            time.sleep(0.04)
        self._send('touchEnd', [])


def png(width, height):
    """A PNG picture, width by height, of a gradient: a phone's photo, for
    the file chooser"""
    import struct
    import zlib
    rows = b''.join(b'\x00' + bytes(v for x in range(width) for v in (x * 255 // width, y * 255 // height, 160))
                    for y in range(height))

    def chunk(kind, data):
        return struct.pack('>I', len(data)) + kind + data + struct.pack('>I', zlib.crc32(kind + data) & 0xffffffff)
    return (b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', width, height, 8, 2, 0, 0, 0))
            + chunk(b'IDAT', zlib.compress(rows, 6)) + chunk(b'IEND', b''))


def buttons(s):
    """The Phone card's buttons, by name, as rectangles"""
    out = {}
    for part in s.get('buttons', '').split(';'):
        if ':' in part:
            name, value = part.split(':', 1)
            out[name] = value
    return out


def labels(s):
    out = {}
    for part in s.get('labels', '').split(';'):
        if ':' in part:
            name, value = part.split(':', 1)
            out[name] = value
    return out


def wait_for(page, test, seconds=6.0):
    """The state once test(state) is true, or the last one."""
    end = time.time() + seconds
    while True:
        s = state(page)
        if test(s) or time.time() > end:
            return s
        time.sleep(0.2)


def check_device(playwright, browser_name, device, url, timeout, shots, touch='auto', check_script=False, work=None):
    problems = []

    def expect(what, ok, s):
        if ok:
            log('  ok: %s' % what)
        else:
            problems.append('%s: %s' % (device, what))
            log('  FAILED: %s (%s)' % (what, ', '.join('%s=%s' % kv for kv in sorted(s.items()))))

    profile = dict(playwright.devices[device])
    profile.pop('default_browser_type', None)
    browser = getattr(playwright, browser_name).launch(**launch_options(browser_name))
    try:
        # (a permission not granted here is denied: Chromium's motion
        # sensors too)
        permissions = ['geolocation'] + (['accelerometer', 'gyroscope'] if browser_name == 'chromium' else [])
        context = browser.new_context(geolocation=WHERE, permissions=permissions, **profile)
        page = context.new_page()
        page.on('pageerror', lambda e: log('  page error: %s' % e))
        page.on('console', lambda m: log('  console.%s: %s' % (m.type, m.text)) if m.type == 'error' else None)
        page.goto(url)
        page.wait_for_function("() => { var h = document.liveCode && document.liveCode.findStackWithName('MobileWebCheck');"
                               " return !!(h && h.mwcState && String(h.mwcState()).indexOf('card=') === 0); }",
                               timeout=timeout * 1000)
        width, height = profile['viewport']['width'], profile['viewport']['height']
        fingers = Fingers(page, context, browser_name, touch)

        def shot(name):
            if shots:
                page.screenshot(path=os.path.join(shots, '%s-%s-%s.png' % (browser_name, device.replace(' ', '-'), name)))

        # 0. the stack is the one its files build: the committed stack's
        # script is phone-starter-stack.livecodescript's (without its
        # first line), so a change there that was never built fails here
        if check_script:
            with open(STARTER_SCRIPT, encoding='utf-8') as f:
                want = f.read().split('\n', 1)[1]
            got = str(page.evaluate("() => document.liveCode.findStackWithName('MobileWebCheck').mwcStarterScript()"))
            expect('the stack is built from phone-starter-stack.livecodescript (build it again)',
                   got.rstrip('\n') == want.rstrip('\n'), {'script': '%d characters' % len(got)})

        # 1. it fills the window
        s = wait_for(page, lambda s: rect(s.get('rect', '')) == [0, 0, width, height])
        shot('1-home')
        expect('the stack fills the window (%dx%d)' % (width, height),
               rect(s.get('rect', '')) == [0, 0, width, height], s)
        expect('the tab bar is at the bottom', s.get('tabs', '').isdigit() and height - 130 <= int(s['tabs']) < height, s)
        if fingers.touches:
            expect('Home says it is on a touch screen in a browser',
                   'Touch screen: true' in s.get('screen', '') and 'In a browser: true' in s.get('screen', ''), s)
        else:
            log('  (this browser makes no touch events: taps and drags are the mouse\'s, and the '
                'gestures are left out)')
            expect('Home says it is in a browser', 'In a browser: true' in s.get('screen', ''), s)

        tab_y = height - 30

        def on_card(name):
            # the card, once the stack has gone to it; then the push
            # effect's time, in which the engine takes no touches
            s = wait_for(page, lambda s: s.get('card') == name)
            time.sleep(0.6)
            return s

        def tab(i):
            fingers.tap(width * (i + 0.5) / len(TABS), tab_y)

        # 2. the list
        tab(1)
        s = on_card('List')
        expect('the List tab goes to List', s.get('card') == 'List', s)
        fingers.drag(width / 2, height * 0.7, width / 2, height * 0.3)
        s = wait_for(page, lambda s: s.get('vscroll', '0') not in ('', '0'))
        expect('a finger scrolls the list', s.get('vscroll', '0') not in ('', '0'), s)
        expect('a drag picks nothing', s.get('picked', '').startswith('Tap an item'), s)
        fingers.tap(width / 2, height / 2)
        s = wait_for(page, lambda s: s.get('picked', '').startswith('You picked Item '))
        expect('a tap picks a line', s.get('picked', '').startswith('You picked Item '), s)
        shot('2-list')

        # 3. swipes change tab
        if fingers.touches:
            fingers.drag(width * 0.2, height / 2, width * 0.8, height / 2, steps=5, pause=0.016)
            s = on_card('Home')
            expect('a swipe right goes back to Home', s.get('card') == 'Home', s)
            fingers.drag(width * 0.8, height / 2, width * 0.2, height / 2, steps=5, pause=0.016)
            s = on_card('List')
            expect('a swipe left goes on to List', s.get('card') == 'List', s)

        # 4. the form
        tab(2)
        s = on_card('Form')
        expect('the Form tab goes to Form', s.get('card') == 'Form', s)
        # (where the stack has put them: it fills the page from its top
        # left, so its card's coordinates are the page's)
        fingers.tap(*middle(s.get('namerect', '')))
        time.sleep(0.5)
        page.keyboard.type('Ada')
        s = wait_for(page, lambda s: s.get('name') == 'Ada')
        expect('typing reaches the Name field', s.get('name') == 'Ada', s)
        fingers.tap(*middle(s.get('saverect', '')))
        s = wait_for(page, lambda s: s.get('saved', '').startswith('Saved'))
        expect('Save says it saved', s.get('saved') == 'Saved, thank you Ada.', s)
        shot('3-form')

        # 5. the keyboard over the form: Notes focused, then the library
        # told that a keyboard covers the window from 60 pixels below the
        # top of Notes (so Notes, 120 high, is under it on any phone)
        before = int(s.get('notestop') or 0)
        fingers.tap(width / 2, before + 40)
        time.sleep(0.5)
        keyboard = height - before - 60
        page.evaluate("""([w, h, k]) => {
            var lib = document.liveCode.findStackWithName('com.livecode.library.mobileweb');
            lib.mwFromBrowser('viewport', [w, h - k, k, 0, 0, 0, 0, 'portrait'].join(','));
        }""", [width, height, keyboard])
        s = wait_for(page, lambda s: s.get('notestop', '').lstrip('-').isdigit() and int(s['notestop']) < before)
        top = int(s.get('notestop') or 0)
        expect('the form moves up for the keyboard', top < before, s)
        expect('Notes ends above the keyboard', top + 120 <= height - keyboard, s)
        page.evaluate("""([w, h]) => {
            var lib = document.liveCode.findStackWithName('com.livecode.library.mobileweb');
            lib.mwFromBrowser('viewport', [w, h, 0, 0, 0, 0, 0, 'portrait'].join(','));
        }""", [width, height])
        s = wait_for(page, lambda s: s.get('notestop') == str(before))
        expect('the form comes back when the keyboard goes', s.get('notestop') == str(before), s)
        # the keyboard up for Name, which it does not cover, and then
        # Notes tapped while it stays up: no keyboard message comes, and
        # the form must move up for Notes all the same (openField)
        fingers.tap(*middle(s.get('namerect', '')))
        time.sleep(0.5)
        page.evaluate("""([w, h, k]) => {
            var lib = document.liveCode.findStackWithName('com.livecode.library.mobileweb');
            lib.mwFromBrowser('viewport', [w, h - k, k, 0, 0, 0, 0, 'portrait'].join(','));
        }""", [width, height, keyboard])
        time.sleep(1)
        s = state(page)
        expect('the form stays put for Name, above the keyboard', s.get('notestop') == str(before), s)
        fingers.tap(width / 2, before + 40)
        s = wait_for(page, lambda s: s.get('notestop', '').lstrip('-').isdigit() and int(s['notestop']) < before)
        top = int(s.get('notestop') or 0)
        expect('Notes tapped while the keyboard is up moves the form up', top < before and top + 120 <= height - keyboard, s)
        page.evaluate("""([w, h]) => {
            var lib = document.liveCode.findStackWithName('com.livecode.library.mobileweb');
            lib.mwFromBrowser('viewport', [w, h, 0, 0, 0, 0, 0, 'portrait'].join(','));
        }""", [width, height])
        s = wait_for(page, lambda s: s.get('notestop') == str(before))
        expect('and it comes back when the keyboard goes', s.get('notestop') == str(before), s)

        # 6. gestures
        tab(3)
        s = on_card('Gestures')
        expect('the Gestures tab goes to Gestures', s.get('card') == 'Gestures', s)
        if fingers.touches:
            fingers.spread(width / 2, height / 2 + 30)
            s = wait_for(page, lambda s: s.get('dot', '').isdigit() and int(s['dot']) > 120)
            expect('a pinch makes the dot bigger', s.get('dot', '').isdigit() and int(s['dot']) > 120, s)
            expect('the pinch is reported', s.get('said', '').startswith('A pinch'), s)
            shot('4-gestures')
            fingers.drag(width * 0.8, height / 2, width * 0.2, height / 2, steps=5, pause=0.016)
            s = wait_for(page, lambda s: s.get('said', '').startswith('A swipe'))
            expect('a swipe on the pad is reported', s.get('said') == 'A swipe left.', s)
            expect('and stays on Gestures', s.get('card') == 'Gestures', s)
            fingers.hold(width / 2 - 60, height / 2 + 60)
            s = wait_for(page, lambda s: s.get('said', '').startswith('A long press'))
            expect('a finger held still is a long press', s.get('said', '').startswith('A long press at'), s)
            # (put down away from the dot, so that the pinch they also
            # make leaves it be)
            fingers.down([(width * 0.3, height / 2 + 90), (width * 0.7, height / 2 + 90)])
            s = wait_for(page, lambda s: s.get('fingers') == '2')
            shot('4-fingers')
            expect('two fingers down are two rings (touchStart)', s.get('fingers') == '2', s)
            fingers.up()
            s = wait_for(page, lambda s: s.get('fingers') == '0')
            expect('and the rings go when they let go (touchEnd)', s.get('fingers') == '0', s)
        else:
            shot('4-gestures')

        # 7. the Phone card
        tab(4)
        s = on_card('Phone')
        expect('the Phone tab goes to Phone', s.get('card') == 'Phone', s)

        def press(name):
            fingers.tap(*middle(buttons(state(page)).get(name, '')))

        press('Where')
        s = wait_for(page, lambda s: s.get('phonesaid', '').startswith('You are at'))
        expect('"Where am I?" says where the browser is (locationChanged)',
               s.get('phonesaid') == 'You are at %s, %s.' % (WHERE['latitude'], WHERE['longitude']), s)

        picture = os.path.join(work or tempfile.gettempdir(), 'photo.png')
        with open(picture, 'wb') as f:
            f.write(png(1600, 1200))
        try:
            with page.expect_file_chooser(timeout=8000) as chooser:
                press('Camera')
            chooser.value.set_files(picture)
            s = wait_for(page, lambda s: s.get('photo', '') != '', seconds=15)
        except Exception as e:  # the chooser never opened
            log('  (no file chooser: %s)' % str(e).splitlines()[0])
            s = state(page)
        shot('7-photo')
        photo = (s.get('photo') or '').split(',')
        frame = rect(s.get('frame', ''))
        expect('"Take a photo" puts the photo in, made 1000 by 750 (mwPickPhoto)', photo[:2] == ['1000', '750'], s)
        expect('in the frame', len(photo) == 6 and frame is not None and frame[0] <= int(photo[2])
               and frame[1] <= int(photo[3]) and int(photo[4]) <= frame[2] and int(photo[5]) <= frame[3], s)
        expect('and says so', s.get('phonesaid') == 'A photo, 1000 by 750 pixels.', s)

        if fingers.touches:
            press('Tilt')
            s = wait_for(page, lambda s: labels(s).get('Tilt') == 'Stop the ball')
            expect('"Roll the ball" starts the motion sensor', labels(s).get('Tilt') == 'Stop the ball', s)
            before = rect(s.get('ball', ''))
            # the phone lying flat, tipped to its right
            for _ in range(20):
                page.evaluate("""() => window.dispatchEvent(new DeviceMotionEvent('devicemotion', {
                    accelerationIncludingGravity: {x: -4, y: 0, z: 9}, interval: 16}))""")
                time.sleep(0.07)
            s = wait_for(page, lambda s: rect(s.get('ball', '')) and before and rect(s['ball'])[0] > before[0] + 20)
            shot('7-tilt')
            after = rect(s.get('ball', ''))
            expect('the ball rolls to the side tipped down (accelerationChanged)',
                   before and after and after[0] > before[0] + 20, s)
            press('Tilt')
            s = wait_for(page, lambda s: labels(s).get('Tilt') == 'Roll the ball')
            expect('and stops', labels(s).get('Tilt') == 'Roll the ball', s)
        else:
            # (a browser without touch events may have the motion
            # sensor's events, with no sensor behind them)
            press('Tilt')
            s = wait_for(page, lambda s: 'no motion sensor' in s.get('phonesaid', '') or labels(s).get('Tilt') == 'Stop the ball')
            started = labels(s).get('Tilt') == 'Stop the ball'
            expect('"Roll the ball" starts the motion sensor, or says there is none',
                   started or 'no motion sensor' in s.get('phonesaid', ''), s)
            if started:
                press('Tilt')
                s = wait_for(page, lambda s: labels(s).get('Tilt') == 'Roll the ball')
                expect('and stops', labels(s).get('Tilt') == 'Roll the ball', s)

        press('Awake')
        s = wait_for(page, lambda s: s.get('phonesaid', '').startswith(('The screen stays on', 'This browser cannot keep')))
        expect('"Keep screen on" keeps it on, or says it cannot (mwKeepAwake)',
               (s.get('phonesaid', '').startswith('The screen stays on') and labels(s).get('Awake') == 'Screen stays on')
               or s.get('phonesaid', '').startswith('This browser cannot keep'), s)
        press('Share')
        s = wait_for(page, lambda s: s.get('phonesaid') in ('Sent to the share sheet.', 'Copied, ready to paste.',
                                                             'This browser cannot share.'))
        expect('"Share" says what it did (mwShare)', s.get('phonesaid') in (
            'Sent to the share sheet.', 'Copied, ready to paste.', 'This browser cannot share.'), s)
        shot('7-phone')

        # 8. the phone turns
        tab(0)
        page.set_viewport_size({'width': height, 'height': width})
        s = wait_for(page, lambda s: rect(s.get('rect', '')) == [0, 0, height, width] and 'landscape' in s.get('screen', ''))
        shot('5-landscape')
        expect('turned, the stack fills the window again (%dx%d)' % (height, width),
               rect(s.get('rect', '')) == [0, 0, height, width], s)
        expect('Home says landscape', 'landscape' in s.get('screen', ''), s)
        for i, name in enumerate(TABS):
            if i:
                fingers.tap(height * (i + 0.5) / len(TABS), width - 24)
            s = on_card(name)
            shot('5-landscape-%s' % name.lower())
            expect('in landscape, %s ends above the tab bar' % name,
                   s.get('card') == name and s.get('contentbottom', '').isdigit() and s.get('tabs', '').isdigit()
                   and int(s['contentbottom']) <= int(s['tabs']), s)
        fingers.tap(height * 0.5 / len(TABS), width - 24)
        s = on_card('Home')
        page.set_viewport_size({'width': width, 'height': height})
        s = wait_for(page, lambda s: rect(s.get('rect', '')) == [0, 0, width, height])
        expect('turned back, it fills the window again', rect(s.get('rect', '')) == [0, 0, width, height], s)

        # 9. a desktop stack fitted to the phone: the button at 680,420 to
        # 780,480 of an 800x500 stack, shown as big as fits and centred
        page.evaluate("() => document.liveCode.findStackWithName('MobileWebCheck').mwcFit()")
        s = wait_for(page, lambda s: s.get('fullscreen') == 'true')
        expect('the desktop stack is made fullscreen', s.get('fullscreen') == 'true', s)
        time.sleep(1)
        scale = min(width / 800.0, height / 500.0)
        x = (width - 800 * scale) / 2 + 730 * scale
        y = (height - 500 * scale) / 2 + 450 * scale
        fingers.tap(x, y)
        s = wait_for(page, lambda s: s.get('farhit') == 'true')
        shot('6-fit')
        expect('a tap reaches the fitted stack\'s far button', s.get('farhit') == 'true', s)
        # turned, it is fitted again, and the Phone Starter, filled
        # before, is left as it was: the window is the new stack's now
        page.set_viewport_size({'width': height, 'height': width})
        time.sleep(2)
        s = state(page)
        expect('turned, the stack filled before is left as it was',
               rect(s.get('rect', '')) == [0, 0, width, height], s)

        # the same stack fitted by mwFitStack alone (after mwStop), then
        # turned back: fitted again for the new window
        got = str(page.evaluate("() => document.liveCode.findStackWithName('MobileWebCheck').mwcFitAlone()"))
        expect('mwFitStack alone fits it', got == '', {'result': got})
        time.sleep(1)
        page.set_viewport_size({'width': width, 'height': height})
        time.sleep(2)
        fingers.tap(x, y)
        s = wait_for(page, lambda s: s.get('farhit') == 'true')
        expect('turned back, mwFitStack alone has fitted it again: a tap reaches the far button',
               s.get('farhit') == 'true', s)

        # 10. mwStop gives the page back its own look, and a page that keeps
        # its own layout (as the Stack Player's does) is not filled
        got = str(page.evaluate("() => document.liveCode.findStackWithName('MobileWebCheck').mwcStopAndKeep()"))
        items = got.split(',')
        seen = {'stop-and-keep': got}
        expect('the page wears the fill style while the stack fills it', items[:1] == ['true'], seen)
        expect('mwStop takes the fill style away', items[1:2] == ['false'], seen)
        expect('a page that keeps its own layout is not filled',
               items[2:4] == ['the page keeps its own layout', 'false'], seen)
    finally:
        browser.close()
    return problems


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    ap.add_argument('--runtime', required=True, help='the web runtime folder')
    ap.add_argument('--engine', help='a development engine (LiveCode-Community)')
    ap.add_argument('--engine-cache', help='download the pinned development engine into this folder')
    ap.add_argument('--browser', choices=('chromium', 'webkit'), default='chromium')
    ap.add_argument('--device', action='append', help="a Playwright device profile (default: %s)" % DEFAULT_DEVICES)
    ap.add_argument('--rebuild', action='store_true', help='build the Phone Starter now instead of the committed one')
    ap.add_argument('--work', help='the work folder (default: a temporary folder)')
    ap.add_argument('--timeout', type=int, default=120, help='seconds for each step (default 120)')
    ap.add_argument('--shots', help='a folder for screenshots of each device')
    ap.add_argument('--touch', choices=('auto', 'cdp', 'page', 'mouse'), default='auto',
                    help="how touches are sent: Chromium's own (cdp), touch events made in the page "
                         "(page, as in WebKit; it can be tried in Chromium too), the mouse (mouse: no "
                         "gestures), or whichever the browser takes (auto)")
    args = ap.parse_args(argv)
    if not args.engine and not args.engine_cache:
        ap.error('--engine or --engine-cache is needed')
    work = args.work or tempfile.mkdtemp(prefix='mobile-web-check-')
    os.makedirs(work, exist_ok=True)
    if args.shots:
        os.makedirs(args.shots, exist_ok=True)
    try:
        from playwright.sync_api import sync_playwright
    except ImportError:
        log('FAILED: the Python package playwright is missing')
        return 1
    try:
        version, js, wasm, html = web_check.runtime_files(args.runtime)
        engine = args.engine or web_check.fetch_engine(args.engine_cache)
        stack = build_starter(engine, work, args.timeout) if args.rebuild else STARTER
        if not os.path.isfile(stack):
            raise CheckError('there is no %s' % stack)
        log('Deploying %s with %s' % (stack, engine))
        data = deploy(engine, args.runtime, version, stack, work, args.timeout)
        site = os.path.join(work, 'site')
        shutil.rmtree(site, ignore_errors=True)
        web_check.make_standalone(args.runtime, js, wasm, html, data, site, title='Phone Starter')
        os.replace(os.path.join(site, web_check.STACK_NAME + '.html'), os.path.join(site, PAGE))
        server = web_check.make_server(site)
        url = 'http://127.0.0.1:%d/%s' % (server.server_address[1], PAGE)
        problems = []
        with sync_playwright() as p:
            for device in args.device or DEFAULT_DEVICES[args.browser]:
                log('%s, %s:' % (args.browser, device))
                problems += check_device(p, args.browser, device, url, args.timeout, args.shots, args.touch,
                                         check_script=not args.rebuild, work=work)
        server.shutdown()
    except (CheckError, web_check.CheckError, subprocess.TimeoutExpired) as e:
        log('FAILED: %s' % e)
        return 1
    if problems:
        log('MOBILE WEB CHECK FAILED')
        for problem in problems:
            log('  %s' % problem)
        return 1
    log('MOBILE WEB CHECK OK')
    return 0


if __name__ == '__main__':
    sys.exit(main())
