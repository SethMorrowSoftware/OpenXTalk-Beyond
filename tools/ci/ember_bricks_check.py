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

"""Play Ember Bricks on emulated phones, a duel between two pages, the
online lobby between three, and a level with a mouse.

  python3 tools/ci/ember_bricks_check.py --runtime DIR (--engine FILE | --engine-cache DIR)
      [--browser chromium|webkit] [--device NAME]... [--rebuild] [--work DIR]
      [--timeout SECONDS] [--shots DIR] [--min-fps N] [--extensions DIR]
      [--no-duel] [--no-lobby] [--no-pointer]

--runtime, --engine and --engine-cache are tools/ci/web_check.py's: the web
runtime (its engine is the one with the xTalk Suite's libraries, so
DataChannelXT's, over the browser's own WebRTC, is in it), and the
development engine that writes the standalone's startup data
(tools/ci/mobile-web-deploy.livecodescript, as the Phone Starter's check
deploys). The standalone's main stack is the committed
tools/web-player/stacks/Ember Bricks.oxtstack, or with --rebuild one that
tools/web-player/ember-bricks.livecodescript builds now; beside it go the
Mobile Web library, the check's own stack
(tools/ci/ember-bricks-check.livecodescript), which says how the game is
(its ebState) and hears of any script error in it, and what the game
uses of the xTalk Suite: DataChannelXT's LCB module for the link, and for
the lobby SodiumXT's and CoinXT's modules, CoinXT's script library and
NostrXT's two. They come from --extensions, or are built now from the
members that tools/oxt/xtalk-extensions.json pins
(tools/oxt/xtalk_extensions.py build, which fetches them once into its
cache).

Each device (Playwright's profiles: by default "Pixel 7" and "iPhone 13"
in Chromium, "iPhone 13" in WebKit) opens the page with a touch screen and
a phone's window, and:

  1. the game opens on its title, the window its own, the arena on it,
     with its font, the browser's sound and the Mobile Web library
  2. a tap on Play shows how to play (the first time), and a tap on its
     button begins a run: a ball waits on the paddle
  3. a finger dragged across the screen moves the paddle with it, and
     lifted, sends the ball off
  4. the ball breaks a brick: the score goes up (and a finger has no
     pointer for the game to hide)
  5. the Pause button pauses (the run's clock stops) and Resume goes on
  6. the game keeps at least --min-fps frames a second (by default 20 in
     Chromium and 10 in WebKit, which draws without a graphics card on
     Linux)
  7. the phone turns: the HUD goes beside the arena, both on the window,
     and the run waits; a tap on Resume goes on
  8. no script error, in the game or the page

Then, in Chromium (--no-duel leaves it out; Playwright's WebKit on Linux
has no clipboard a check can give a page), a duel between two pages of one
browser, a desktop's window that hosts and a phone that joins, by the two
codes, over a real WebRTC link:

  9. the lobby opens on a name, with nothing sent to any relay; PLAY BY
     CODE is the swap of two codes. The host's lobby makes an invite code;
     COPY THE INVITE puts it on the clipboard
 10. the phone's PASTE reads the invite off its clipboard and makes an
     answer code; the host's PASTE of that one connects them
 11. both begin the same wall with three minutes on clocks in step
 12. each sees the other's score
 13. the clocks run out: the one with more points wins and the other is
     told so, by the same scores
 14. both ask for a rematch: a new match begins
 15. the phone leaves: the host is told, and its match is over
 16. no script error, in either game or page

And, in Chromium too (--no-lobby leaves it out), the online lobby: three
pages of one browser, a desktop's window and two phones, that find each
other on a Nostr relay of the check's own on 127.0.0.1
(tools/ci/nostr_test_relay.py, which the game is told to use in place of
the public ones: ebTestSet "relays"), through NostrXT's relay library and
the browser's WebSocket, and link over WebRTC as the codes do. The relay
keeps for five minutes what it passes on and gives it to whoever asks,
as some public relays do, so a game that took an old message for news
would list players who have gone, or be challenged again by a match
that is over:

 17. a name typed and Return: the page is online, on the relay, in the
     lobby; each page lists the others by the names they gave
 18. a tap on a player challenges them: they are asked, by name, and
     ACCEPT begins the match on both, with no code carried
 19. the third page sees both of them in a duel
 20. the match over, LEAVE comes back to the lobby, online again
 21. the relay hangs up on all three: each is back on it by itself, in
     the lobby all the while, and what follows is played over the new
     connections
 22. QUICK MATCH on two pages matches them
 23. PLAY A FRIEND makes a room; COPY THE LINK puts the page's address
     with the room's code on the clipboard, and a page opened at that
     address has JOIN YOUR FRIEND, which begins the match with the room's
     maker
 24. no script error, in any of the games or pages

Last, in either browser (--no-pointer leaves it out), a desktop's window
with a mouse plays a level. The pointer is what the page shows where the
mouse is (the CSS cursor of the element there), and what the game says
of it (its ebState's "hidden"). The page asks for no clipboard, which
WebKit has none to give, and where a browser's own page says that it has
no mouse (outside MOUSE_BROWSERS) the game is told that it has one:

 25. on the title the pointer shows, over where the arena is too
 26. in a level it is hidden over the arena
 27. it shows over the pause button beside the arena, and is hidden again
     back over the arena
 28. a pause shows it over the arena, and Resume hides it again
 29. no script error, in the game or the page

Playwright's WebKit on Linux makes no touch events, so there the taps and
the drag are the mouse's, which the game reads as it reads a finger. Ends
with "EMBER BRICKS CHECK OK" or a list of what failed, and exit status 1.
"""

import argparse
import os
import shutil
import subprocess
import sys
import tempfile
import time

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
sys.path.insert(0, HERE)
import web_check  # noqa: E402
import mobile_web_check  # noqa: E402

GAME = os.path.join(REPO, 'tools', 'web-player', 'stacks', 'Ember Bricks.oxtstack')
GAME_BUILDER = os.path.join(REPO, 'tools', 'web-player', 'ember-bricks.livecodescript')
CHECK_STACK = os.path.join(HERE, 'ember-bricks-check.livecodescript')
CHECK_NAME = 'EmberBricksCheck'
# the check stack's handlers that the page may call
HANDLERS = ['ecBegin', 'ecState', 'ecRect', 'ecText', 'ecSet', 'ecErrors']
PAGE = 'EmberBricks.html'
XTALK_EXTENSIONS = os.path.join(REPO, 'tools', 'oxt', 'xtalk_extensions.py')
DATACHANNELXT = 'org.openxtalk.library.datachannel'
# the lobby's: NostrXT signs with CoinXT and seals with SodiumXT. The LCB
# modules bind to libraries the web engine has built in; the script
# libraries are started beside the game, each after those it uses
SODIUMXT = 'org.openxtalk.library.sodium'
COINXT = 'org.openxtalk.library.coin'
MODULES = (SODIUMXT, COINXT, DATACHANNELXT)
LIBRARIES = ('coinxt', 'nostrxt', 'nostr-relay')
DEFAULT_DEVICES = {'chromium': ['Pixel 7', 'iPhone 13'], 'webkit': ['iPhone 13']}
DEFAULT_MIN_FPS = {'chromium': 20, 'webkit': 10}
# the duel's pages: a desktop's window with room for the game at its own
# size (900 x 640), and a phone
DUEL_HOST = {'viewport': {'width': 1000, 'height': 700}}
DUEL_GUEST = 'Pixel 7'
# the browsers whose pages a check can give a clipboard to read
DUEL_BROWSERS = ('chromium',)
# the browsers whose desktop page is known to say it has a mouse, which
# the check then holds it to
MOUSE_BROWSERS = ('chromium',)
# the lobby's third page, a phone too
LOBBY_THIRD = 'iPhone 13'
# the seconds the lobby's relay keeps an ephemeral event for (strfry's
# five minutes, which nos.lol and relay.damus.io run)
LOBBY_RELAY_KEEPS = 300
# the seconds a page has to be back on a relay that hung up on it: fewer
# than the game keeps a lobby with no relay open (its kNetOpenFor), so a
# game that asked again only after that would have given the lobby up
LOBBY_BACK_IN = 10
# the state's keys a failure is printed with
KEYS = ('mode', 'phase', 'score', 'lives', 'level', 'bricks', 'now', 'padx', 'ball', 'fps', 'font', 'audio',
        'library', 'arena', 'wide', 'window', 'pointer', 'hidden', 'rtc', 'duel', 'lobby', 'stage', 'left', 'rival',
        'link', 'shift', 'nostr', 'online', 'name', 'relays', 'room', 'who', 'doing', 'foe', 'invite', 'back')

# A handler of the check stack, called from the page
CALL = ("(a) => { var h = document.liveCode && document.liveCode.findStackWithName('EmberBricksCheck');"
        " if (!h || !h[a[0]]) return ''; return String(h[a[0]].apply(h, a.slice(1))); }")
# The page once the game is on its title
OPENED = ("() => { var h = document.liveCode && document.liveCode.findStackWithName('EmberBricksCheck');"
          " return !!(h && h.ecState && String(h.ecState()).indexOf('mode:title') === 0); }")
# The pointer a page shows at a point: the CSS cursor of what is there
CURSOR_AT = ("(p) => { var e = document.elementFromPoint(p[0], p[1]);"
             " return e ? String(getComputedStyle(e).cursor) : ''; }")
# The page once the game is in its lobby (a page opened by a friend's link
# goes straight there)
OPENED_LOBBY = OPENED.replace("'mode:title'", "'mode:lobby'")


class CheckError(Exception):
    pass


def log(msg=''):
    print(msg, flush=True)


def build_game(engine, work, timeout):
    """An Ember Bricks built now by its builder."""
    out = os.path.join(work, 'Ember Bricks.oxtstack')
    env = dict(os.environ, OXT_EMBER_BRICKS=out)
    r = subprocess.run([engine, '-ui', GAME_BUILDER], env=env, stdout=subprocess.PIPE,
                       stderr=subprocess.STDOUT, timeout=timeout)
    text = r.stdout.decode('utf-8', 'replace')
    if r.returncode != 0 or 'BUILT' not in text:
        raise CheckError('building Ember Bricks failed: %s' % text.strip())
    return out


def suite_files(engine, extensions, work, timeout):
    """What the game uses of the xTalk Suite: (the module.lcm files of
    MODULES, the script files of LIBRARIES), from --extensions (a folder
    that tools/oxt/xtalk_extensions.py build wrote, or an install's
    Extensions), or built now from the pinned members with the engine's
    lc-compile. The web engine has the Suite's native libraries built in
    (DataChannelXT's over the browser's RTCPeerConnection); the standalone
    needs the modules that bind to them, and the script libraries."""
    if not extensions:
        extensions = os.path.join(work, 'extensions')
        if not os.path.isfile(os.path.join(extensions, DATACHANNELXT, 'module.lcm')):
            r = subprocess.run([sys.executable, XTALK_EXTENSIONS, 'build', '--bin', os.path.dirname(engine),
                                '--out', extensions, '--platforms', 'x86_64-linux'],
                               stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=timeout * 5)
            if r.returncode != 0:
                raise CheckError('building the xTalk Suite extensions failed: %s'
                                 % r.stdout.decode('utf-8', 'replace').strip()[-2000:])
    modules = [os.path.join(extensions, name, 'module.lcm') for name in MODULES]
    libraries = [os.path.join(extensions, name, name + '.livecodescript') for name in LIBRARIES]
    for path in modules + libraries:
        if not os.path.isfile(path):
            raise CheckError('there is no %s' % path)
    return modules, libraries


def deploy(engine, runtime, version, stack, work, timeout, modules=(), libraries=()):
    output = os.path.join(work, '__startup.data')
    env = dict(os.environ, OXT_MW_STACK=stack, OXT_MW_LIBRARY=mobile_web_check.LIBRARY,
               OXT_MW_MODULES='\n'.join(modules), OXT_MW_LIBRARIES='\n'.join(libraries),
               OXT_MW_CHECK=CHECK_STACK, OXT_MW_CHECK_NAME=CHECK_NAME, OXT_MW_HANDLERS=','.join(HANDLERS),
               OXT_MW_OUTPUT=output, OXT_MW_VERSION=version,
               OXT_MW_TEMPLATE=os.path.join(runtime, 'emscripten-startup-template.livecodescript'))
    r = subprocess.run([engine, '-ui', mobile_web_check.DEPLOY_SCRIPT], cwd=work, env=env,
                       stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=timeout)
    text = r.stdout.decode('utf-8', 'replace')
    for line in text.splitlines():
        if line.strip():
            log('  deploy: %s' % line)
    if r.returncode != 0 or 'DEPLOY OK' not in text:
        raise CheckError('deploying Ember Bricks failed')
    return output


def call(page, *args):
    return str(page.evaluate(CALL, list(args)))


def parse_state(text):
    """ebState's lines, name:value, as a dict"""
    out = {}
    for line in (text or '').split('\n'):
        if ':' in line:
            key, value = line.split(':', 1)
            out[key] = value
    return out


def state(page):
    return parse_state(call(page, 'ecState'))


def number(s, key, default=None):
    try:
        return float(s.get(key, ''))
    except ValueError:
        return default


def rect(text):
    try:
        r = [int(float(x)) for x in text.split(',')]
    except ValueError:
        return None
    return r if len(r) == 4 else None


def inside(inner, outer):
    """Whether a rect is all in another"""
    return (inner is not None and outer is not None and inner[0] >= outer[0] and inner[1] >= outer[1]
            and inner[2] <= outer[2] and inner[3] <= outer[3])


def apart(a, b):
    """Whether two rects share no point"""
    return a is not None and b is not None and (a[2] <= b[0] or b[2] <= a[0] or a[3] <= b[1] or b[3] <= a[1])


def middle(page, name):
    """The middle of a control of the game, where a finger taps it"""
    r = rect(call(page, 'ecRect', name))
    if not r:
        raise CheckError('the game shows no %s to tap' % name)
    return (r[0] + r[2]) / 2, (r[1] + r[3]) / 2


def wait_for(page, test, seconds=6.0):
    """The state once test(state) is true, or the last one."""
    end = time.time() + seconds
    while True:
        s = state(page)
        if test(s) or time.time() > end:
            return s
        time.sleep(0.15)


def said(s):
    """A state's lines for a failure"""
    return ', '.join('%s=%s' % (k, s[k]) for k in KEYS if k in s) or str(s)


def check_device(playwright, browser_name, device, url, timeout, shots, min_fps):
    problems = []
    page_errors = []

    def expect(what, ok, s):
        if ok:
            log('  ok: %s' % what)
        else:
            problems.append('%s, %s: %s' % (browser_name, device, what))
            log('  FAILED: %s (%s)' % (what, said(s)))

    profile = dict(playwright.devices[device])
    profile.pop('default_browser_type', None)
    browser = getattr(playwright, browser_name).launch(**mobile_web_check.launch_options(browser_name))
    try:
        context = browser.new_context(**profile)
        page = context.new_page()
        page.on('pageerror', lambda e: page_errors.append(str(e)))
        page.on('console', lambda m: log('  console.%s: %s' % (m.type, m.text)) if m.type == 'error' else None)
        page.goto(url)
        page.wait_for_function(OPENED, timeout=timeout * 1000)
        call(page, 'ecBegin')
        width, height = profile['viewport']['width'], profile['viewport']['height']
        fingers = mobile_web_check.Fingers(page, context, browser_name)
        if not fingers.touches:
            log('  (this browser makes no touch events: the taps and the drag are the mouse\'s)')

        def shot(name):
            if shots:
                page.screenshot(path=os.path.join(shots, '%s-%s-%s.png' % (browser_name, device.replace(' ', '-'), name)))

        def tap(name):
            x, y = middle(page, name)
            fingers.tap(x, y)

        def control(name):
            return rect(call(page, 'ecRect', name))

        # 1. the title, the whole window the game's
        window = '%d,%d' % (width, height)
        s = wait_for(page, lambda s: s.get('window') == window)
        time.sleep(0.5)
        shot('1-title')
        expect('the game opens on its title', s.get('mode') == 'title', s)
        expect('the window is the game\'s (%dx%d)' % (width, height), s.get('window') == window, s)
        expect('the arena is on it', inside(rect(s.get('arena', '')), [0, 0, width, height]), s)
        expect('with its font', s.get('font') == 'true', s)
        expect('the browser\'s sound', s.get('audio') == 'web', s)
        expect('and the Mobile Web library', s.get('library') == 'true', s)

        # 2. Play: how to play, then a run
        tap('Play')
        s = wait_for(page, lambda s: s.get('mode') == 'howto', 3)
        shot('2-howto')
        expect('the first Play shows how to play', s.get('mode') == 'howto', s)
        tap('Howto Go')
        s = wait_for(page, lambda s: s.get('mode') == 'play' and s.get('phase') == 'serve', 3)
        expect('its button begins a run', s.get('mode') == 'play', s)
        expect('a ball waits on the paddle', s.get('phase') == 'serve' and s.get('ball', '').endswith(',true'), s)
        time.sleep(0.6)

        # 3. a finger moves the paddle, and lifted, sends the ball off
        s = state(page)
        x0 = number(s, 'padx', 0)
        arena = rect(s.get('arena', '')) or [0, 0, width, height]
        y = arena[3] - 30
        fingers._send('touchStart', [(width / 2 + 50, y)])
        for i in range(1, 11):
            fingers._send('touchMove', [(width / 2 + 50 - 10 * i, y)])
            time.sleep(0.04)
        time.sleep(0.3)
        s = state(page)
        shot('3-drag')
        expect('a finger dragged left moves the paddle left', number(s, 'padx', x0) <= x0 - 30, s)
        expect('the ball still waits on it', s.get('phase') == 'serve', s)
        fingers._send('touchEnd', [])
        s = wait_for(page, lambda s: s.get('phase') == 'live', 3)
        expect('lifted, the finger sends the ball off', s.get('phase') == 'live' and s.get('ball', '').endswith(',false'), s)

        # 4. the ball breaks a brick
        bricks = number(s, 'bricks', 0)
        s = wait_for(page, lambda s: number(s, 'score', 0) > 0, 8)
        shot('4-play')
        expect('the ball breaks a brick', number(s, 'bricks', bricks) < bricks, s)
        expect('for points', number(s, 'score', 0) >= 10, s)
        if s.get('pointer') == 'touch':
            expect('a finger has no pointer for the game to hide', s.get('hidden') == 'false', s)

        # 5. Pause and Resume
        tap('Pause')
        s = wait_for(page, lambda s: s.get('mode') == 'pause', 3)
        shot('5-pause')
        expect('Pause pauses', s.get('mode') == 'pause', s)
        was = s.get('now')
        time.sleep(1)
        s = state(page)
        expect('the run waits', s.get('now') == was, s)
        tap('Resume')
        s = wait_for(page, lambda s: s.get('mode') == 'play', 3)
        expect('Resume goes on', s.get('mode') == 'play', s)

        # 6. the frame rate (a run that ended meanwhile is begun again: the
        # paddle is nobody's)
        time.sleep(3)
        s = state(page)
        if s.get('mode') in ('play', 'clear', 'over'):
            log('  (%s frames a second; the game\'s own work %s ms a frame, the drawing %s ms)'
                % (s.get('fps'), s.get('work'), s.get('draw')))
            expect('at least %d frames a second' % min_fps, number(s, 'fps', 0) >= min_fps, s)
        else:
            expect('the run is still playing', False, s)
        if s.get('mode') == 'over':
            tap('Again')
            s = wait_for(page, lambda s: s.get('mode') == 'play', 3)

        # 7. the phone turns
        if s.get('mode') == 'play':
            page.set_viewport_size({'width': height, 'height': width})
            turned = '%d,%d' % (height, width)
            s = wait_for(page, lambda s: s.get('window') == turned and s.get('mode') == 'pause', 5)
            time.sleep(0.5)
            shot('6-turned')
            arena = rect(s.get('arena', ''))
            expect('turned, the window is the game\'s (%dx%d)' % (height, width), s.get('window') == turned, s)
            expect('the arena is on it', inside(arena, [0, 0, height, width]), s)
            expect('the HUD goes beside the arena', s.get('wide') == 'true', s)
            score = control('Score')
            expect('on the window, off the arena', inside(score, [0, 0, height, width]) and apart(score, arena),
                   {'Score': score, 'arena': arena})
            expect('the run waits for the player', s.get('mode') == 'pause', s)
            if s.get('mode') == 'pause':
                tap('Resume')
                s = wait_for(page, lambda s: s.get('mode') == 'play', 3)
                expect('Resume goes on', s.get('mode') == 'play', s)
                time.sleep(0.5)
        else:
            expect('a run to turn the phone in', False, s)

        # 8. no script error
        errors = call(page, 'ecErrors')
        expect('no script error in the game', errors.strip() == '', {'errors': errors.strip()[:400]})
        expect('none in the page', not page_errors, {'page errors': page_errors[:3]})
    finally:
        browser.close()
    return problems


class Player:
    """One page of a duel, of the lobby or of a level with a mouse: its
    taps, its state, and its clipboard where the browser can give it one
    (DUEL_BROWSERS) and it is asked for"""

    def __init__(self, playwright, browser, browser_name, name, profile, url, timeout, shots, scene='duel',
                 clipboard=True):
        self.name = name
        self.shots = shots
        self.scene = scene
        self.timeout = timeout
        self.browser_name = browser_name
        self.page_errors = []
        profile = dict(profile)
        profile.pop('default_browser_type', None)
        self.touch = bool(profile.get('has_touch'))
        if clipboard:
            # (only for a page that reads one: WebKit knows no such
            # permission, and refuses the context's first page for it)
            profile['permissions'] = ['clipboard-read', 'clipboard-write']
        self.context = browser.new_context(**profile)
        self.page = self.context.new_page()
        self.page.on('pageerror', lambda e: self.page_errors.append(str(e)))
        self.page.on('console', lambda m: log('  %s console.%s: %s' % (name, m.type, m.text))
                     if m.type == 'error' else None)
        self.fingers = mobile_web_check.Fingers(self.page, self.context, browser_name) if self.touch else None
        self.open(url)

    def open(self, url, opened=OPENED):
        """The page at an address, once the game is up (on its title, or
        with opened=OPENED_LOBBY in its lobby)"""
        self.page.goto(url)
        self.page.wait_for_function(opened, timeout=self.timeout * 1000)
        call(self.page, 'ecBegin')
        time.sleep(0.8)

    def state(self):
        return state(self.page)

    def wait_for(self, test, seconds=6.0):
        return wait_for(self.page, test, seconds)

    def tap(self, name):
        x, y = middle(self.page, name)
        if self.fingers:
            self.fingers.tap(x, y)
        else:
            self.page.mouse.click(x, y)
        time.sleep(0.3)

    def text(self, name):
        return call(self.page, 'ecText', name)

    def set(self, name, value):
        return call(self.page, 'ecSet', name, str(value))

    def clipboard(self):
        return str(self.page.evaluate("() => navigator.clipboard.readText().catch(function(e) { return 'ERROR ' + e; })"))

    def to_clipboard(self, text):
        return str(self.page.evaluate(
            "(t) => navigator.clipboard.writeText(t).then(function() { return 'done'; },"
            " function(e) { return 'ERROR ' + e; })", text))

    def shot(self, step):
        if self.shots:
            self.page.screenshot(path=os.path.join(self.shots, '%s-%s-%s-%s.png'
                                                   % (self.browser_name, self.scene, step, self.name)))

    def type_name(self, name):
        """A name typed over the one in the lobby's field, and Return"""
        x, y = middle(self.page, 'Name')
        self.page.mouse.click(x, y)
        time.sleep(0.3)
        self.page.keyboard.press('Control+a')
        self.page.keyboard.type(name, delay=40)
        time.sleep(0.2)
        self.page.keyboard.press('Enter')
        time.sleep(0.3)

    def errors(self):
        return call(self.page, 'ecErrors').strip()


def check_duel(playwright, browser_name, url, timeout, shots):
    """A duel between two pages of one browser: 9 to 16 of the list."""
    problems = []

    def expect(what, ok, *states):
        if ok:
            log('  ok: %s' % what)
        else:
            problems.append('%s, the duel: %s' % (browser_name, what))
            log('  FAILED: %s (%s)' % (what, ' | '.join(said(s) if isinstance(s, dict) else str(s) for s in states)))

    browser = getattr(playwright, browser_name).launch(**mobile_web_check.launch_options(browser_name))
    try:
        host = Player(playwright, browser, browser_name, 'host', DUEL_HOST, url, timeout, shots)
        guest = Player(playwright, browser, browser_name, 'guest', playwright.devices[DUEL_GUEST], url, timeout, shots)

        # 9. the lobby's first step, and the host's invite
        host.tap('Duel Open')
        h = host.wait_for(lambda s: s.get('lobby') == 'start', 3)
        expect('the title\'s ONLINE DUEL opens the lobby, on a name', h.get('mode') == 'lobby'
               and h.get('lobby') == 'start' and h.get('name', '') != '', h)
        expect('a link can be made here, and there is a lobby', h.get('rtc') == 'yes' and h.get('nostr') == 'yes', h)
        expect('nothing is sent anywhere before the player goes online', h.get('online') == 'false'
               and h.get('relays') == '0', h)
        host.tap('Codes Open')
        h = host.wait_for(lambda s: s.get('lobby') == 'choose', 3)
        expect('PLAY BY CODE is the swap of two codes', h.get('lobby') == 'choose', h)
        host.tap('Host')
        h = host.wait_for(lambda s: s.get('lobby') == 'host-invite', 30)
        invite = h.get('code', '')
        host.shot('1-invite')
        expect('HOST A DUEL makes an invite code', h.get('lobby') == 'host-invite' and invite.startswith('EB1O')
               and len(invite) > 100, h)
        host.tap('Code Copy')
        copied = host.clipboard()
        expect('COPY THE INVITE puts it on the clipboard', copied == invite and invite != '',
               {'clipboard': copied[:60], 'code': invite[:60]})
        host.tap('Code Go')
        h = host.wait_for(lambda s: s.get('lobby') == 'host-answer', 3)
        expect('NEXT waits for the answer', h.get('lobby') == 'host-answer', h)

        # 10. the phone's answer, and the link
        guest.tap('Duel Open')
        guest.wait_for(lambda s: s.get('lobby') == 'start', 3)
        guest.tap('Codes Open')
        guest.wait_for(lambda s: s.get('lobby') == 'choose', 3)
        guest.tap('Join')
        g = guest.wait_for(lambda s: s.get('lobby') == 'join-invite', 3)
        expect('JOIN A DUEL asks for the invite', g.get('lobby') == 'join-invite', g)
        guest.to_clipboard(invite)
        guest.tap('Code Paste')
        g = guest.wait_for(lambda s: s.get('lobby') == 'join-answer', 30)
        answer = g.get('code', '')
        guest.shot('2-answer')
        expect('the phone\'s PASTE reads the invite and makes an answer code',
               g.get('lobby') == 'join-answer' and answer.startswith('EB1A') and len(answer) > 100, g)
        host.to_clipboard(answer)
        host.tap('Code Paste')
        h = host.wait_for(lambda s: s.get('duel') == 'true' and s.get('mode') == 'play', 40)
        g = guest.wait_for(lambda s: s.get('duel') == 'true' and s.get('mode') == 'play', 10)
        expect('the host\'s PASTE of the answer connects them', h.get('link') == 'true' and g.get('link') == 'true', h, g)

        # 11. the same wall, clocks in step
        expect('a match begins on both', h.get('stage') == 'play' and g.get('stage') == 'play'
               and h.get('duel') == 'true' and g.get('duel') == 'true', h, g)
        expect('on the same wall', h.get('shift') == g.get('shift') and h.get('shift', '') != ''
               and h.get('level') == '1' and g.get('level') == '1', h, g)
        h = host.wait_for(lambda s: number(s, 'left', 180) < 180, 8)
        t0 = time.time()
        g = guest.state()
        between = abs(number(h, 'left', 0) - number(g, 'left', 99)) - (time.time() - t0)
        host.shot('3-play')
        guest.shot('3-play')
        expect('three minutes on clocks in step', 170 < number(h, 'left', 0) < 180 and between < 1.5, h, g)

        # 12. each sees the other's score (what the unsteered balls break
        # is added to these)
        guest.set('score', 5000)
        host.set('score', 3000)
        h = host.wait_for(lambda s: number(s, 'rival', 0) >= 5000, 5)
        g = guest.wait_for(lambda s: number(s, 'rival', 0) >= 3000, 5)
        expect('the host sees the phone\'s score', 5000 <= number(h, 'rival', 0) < 6000, h)
        expect('the phone sees the host\'s', 3000 <= number(g, 'rival', 0) < 4000, g)

        # 13. the clocks run out
        host.set('left', 2)
        guest.set('left', 2)
        h = host.wait_for(lambda s: s.get('mode') == 'result', 8)
        g = guest.wait_for(lambda s: s.get('mode') == 'result', 8)
        expect('time: the result on both', h.get('mode') == 'result' and g.get('mode') == 'result', h, g)
        # (each waits for the other's last score before it names a winner)
        end = time.time() + 6
        while time.time() < end and (host.text('Result Title') == 'TIME!' or guest.text('Result Title') == 'TIME!'):
            time.sleep(0.2)
        h, g = host.state(), guest.state()
        host.shot('4-result')
        guest.shot('4-result')
        titles = {'host': host.text('Result Title'), 'guest': guest.text('Result Title')}
        expect('the phone, with more, wins and the host is told its rival did',
               titles == {'host': 'RIVAL WINS', 'guest': 'YOU WIN'}, titles)
        expect('by the same scores', h.get('rival') == g.get('score') and g.get('rival') == h.get('score'), h, g)

        # 14. a rematch
        host.tap('Rematch')
        h = host.state()
        expect('one Rematch waits for the other', h.get('mode') == 'result', h)
        guest.tap('Rematch')
        h = host.wait_for(lambda s: s.get('mode') == 'play', 8)
        g = guest.wait_for(lambda s: s.get('mode') == 'play', 8)
        expect('both ask for a rematch: a new match', h.get('mode') == 'play' and g.get('mode') == 'play'
               and number(h, 'left', 0) > 170 and number(g, 'left', 0) > 170
               and number(h, 'score', 1) < 1000 and h.get('shift') == g.get('shift'), h, g)

        # 15. the phone leaves
        guest.tap('Pause')
        g = guest.wait_for(lambda s: s.get('mode') == 'pause', 3)
        guest.tap('Pause Home')
        g = guest.wait_for(lambda s: s.get('mode') == 'title', 3)
        expect('the phone leaves by its Pause', g.get('mode') == 'title' and g.get('duel') == 'false', g)
        h = host.wait_for(lambda s: s.get('mode') == 'result', 12)
        host.shot('5-left')
        expect('the host is told, its match over', h.get('mode') == 'result'
               and host.text('Result Title') == 'RIVAL LEFT', h, {'title': host.text('Result Title')})

        # 16. no script error
        for player in (host, guest):
            errors = player.errors()
            expect('no script error in the %s\'s game' % player.name, errors == '', {'errors': errors[:400]})
            expect('none in its page', not player.page_errors, {'page errors': player.page_errors[:3]})
    finally:
        browser.close()
    return problems


def check_pointer(playwright, browser_name, url, timeout, shots):
    """A level played with a mouse in a desktop's window: 25 to 29 of the
    list."""
    problems = []

    def expect(what, ok, *states):
        if ok:
            log('  ok: %s' % what)
        else:
            problems.append('%s, the pointer: %s' % (browser_name, what))
            log('  FAILED: %s (%s)' % (what, ' | '.join(said(s) if isinstance(s, dict) else str(s) for s in states)))

    browser = getattr(playwright, browser_name).launch(**mobile_web_check.launch_options(browser_name))
    try:
        # (no clipboard: nothing here reads one, and the page has to open
        # in WebKit too)
        me = Player(playwright, browser, browser_name, 'desktop', DUEL_HOST, url, timeout, shots, scene='pointer',
                    clipboard=False)

        def pointer_at(x, y, hidden, seconds=3.0):
            """The mouse at a point of the page, and once the pointer is
            hidden there (or shows), or after so many seconds: the game's
            state and the page's cursor at the point"""
            me.page.mouse.move(x, y, steps=4)
            end = time.time() + seconds
            while True:
                s = me.state()
                cursor = str(me.page.evaluate(CURSOR_AT, [x, y]))
                if ((s.get('hidden') == 'true') == hidden and (cursor == 'none') == hidden) or time.time() > end:
                    return s, {'cursor': cursor}
                time.sleep(0.1)

        def is_hidden(s, c):
            return s.get('hidden') == 'true' and c['cursor'] == 'none'

        def shows(s, c):
            return s.get('hidden') == 'false' and c['cursor'] != 'none'

        def arena_middle():
            a = rect(me.state().get('arena', ''))
            if not a:
                raise CheckError('the game has no arena')
            return (a[0] + a[2]) / 2, (a[1] + a[3]) / 2

        # 25. the title
        x, y = arena_middle()
        s = me.state()
        if s.get('pointer') != 'mouse' and browser_name not in MOUSE_BROWSERS:
            # the page's (any-pointer) is the build's to answer, and a
            # headless one may answer as a phone does whatever the page:
            # the game is told what a desktop's browser tells it
            log('  (%s says this page has no mouse (%s): the game is told that it has)'
                % (browser_name, s.get('pointer')))
            me.set('pointer', 'mouse')
        s, c = pointer_at(x, y, False, 1.5)
        expect('a desktop\'s page plays with a mouse', s.get('pointer') == 'mouse', s)
        expect('on the title the pointer shows, over where the arena is too', s.get('mode') == 'title' and shows(s, c), s, c)

        # 26. a level
        me.tap('Play')
        s = me.wait_for(lambda s: s.get('mode') in ('howto', 'play'), 3)
        if s.get('mode') == 'howto':
            me.tap('Howto Go')
        s = me.wait_for(lambda s: s.get('mode') == 'play', 3)
        x, y = arena_middle()
        s, c = pointer_at(x, y, True)
        me.shot('1-hidden')
        expect('in a level the pointer is hidden over the arena', s.get('mode') == 'play' and is_hidden(s, c), s, c)

        # 27. the pause button, beside the arena, and back
        px, py = middle(me.page, 'Pause')
        s, c = pointer_at(px, py, False)
        expect('it shows over the pause button', s.get('mode') == 'play' and shows(s, c), s, c)
        s, c = pointer_at(x, y, True)
        expect('and is hidden again back over the arena', s.get('mode') == 'play' and is_hidden(s, c), s, c)

        # 28. a pause, and Resume
        me.tap('Pause')
        s = me.wait_for(lambda s: s.get('mode') == 'pause', 3)
        s, c = pointer_at(x, y, False)
        me.shot('2-paused')
        expect('a pause shows it over the arena', s.get('mode') == 'pause' and shows(s, c), s, c)
        me.tap('Resume')
        s = me.wait_for(lambda s: s.get('mode') == 'play', 3)
        s, c = pointer_at(x, y, True)
        expect('Resume hides it again', s.get('mode') == 'play' and is_hidden(s, c), s, c)

        # 29. no script error
        errors = me.errors()
        expect('no script error in the game', errors == '', {'errors': errors[:400]})
        expect('none in the page', not me.page_errors, {'page errors': me.page_errors[:3]})
    finally:
        browser.close()
    return problems


def check_lobby(playwright, browser_name, url, timeout, shots, relay, relay_url):
    """The online lobby between three pages of one browser, on a relay of
    the check's own: 17 to 24 of the list."""
    problems = []

    def expect(what, ok, *states):
        if ok:
            log('  ok: %s' % what)
        else:
            problems.append('%s, the lobby: %s' % (browser_name, what))
            log('  FAILED: %s (%s)' % (what, ' | '.join(said(s) if isinstance(s, dict) else str(s) for s in states)))

    def playing(s):
        return s.get('duel') == 'true' and s.get('mode') == 'play'

    def listed(s):
        """The players a page lists: {name: what they are doing}"""
        return dict(item.split('=', 1) for item in s.get('who', '').split('|') if '=' in item)

    def row_of(s, name):
        """The list's row for a player, to tap"""
        names = [item.split('=', 1)[0] for item in s.get('who', '').split('|')]
        return 'Who %d' % (names.index(name) + 1)

    def leave_match(player):
        """Out of a match by its Pause, and back in the lobby"""
        player.tap('Pause')
        player.wait_for(lambda s: s.get('mode') == 'pause', 3)
        player.tap('Pause Home')
        return player.wait_for(lambda s: s.get('lobby') == 'online', 20)

    def leave_result(player):
        """Out of a match that is over, and back in the lobby"""
        player.wait_for(lambda s: s.get('mode') == 'result', 15)
        player.tap('Result Home')
        return player.wait_for(lambda s: s.get('lobby') == 'online', 20)

    browser = getattr(playwright, browser_name).launch(**mobile_web_check.launch_options(browser_name))
    try:
        ada = Player(playwright, browser, browser_name, 'ada', DUEL_HOST, url, timeout, shots, 'lobby')
        bo = Player(playwright, browser, browser_name, 'bo', playwright.devices[DUEL_GUEST], url, timeout, shots, 'lobby')
        cy = Player(playwright, browser, browser_name, 'cy', playwright.devices[LOBBY_THIRD], url, timeout, shots, 'lobby')
        players = (ada, bo, cy)
        for player in players:
            player.set('relays', relay_url)

        # 17. a name, online, and who is there
        ada.tap('Duel Open')
        a = ada.wait_for(lambda s: s.get('lobby') == 'start', 3)
        ada.shot('1-name')
        expect('the lobby opens on a name', a.get('lobby') == 'start' and a.get('nostr') == 'yes', a)
        expect('with no word to the relay yet', len(relay.relay.clients) == 0, {'clients': len(relay.relay.clients)})
        ada.type_name('Ada')
        a = ada.wait_for(lambda s: s.get('lobby') == 'online', 20)
        expect('a name typed and Return: online, in the lobby, on the relay', a.get('lobby') == 'online'
               and a.get('name') == 'Ada' and a.get('online') == 'true' and a.get('relays') == '1'
               and len(relay.relay.clients) == 1, a, {'clients': len(relay.relay.clients)})
        expect('with nobody there yet', a.get('who') == '', a)
        for player, name in ((bo, 'Bo'), (cy, 'Cy')):
            player.tap('Duel Open')
            player.wait_for(lambda s: s.get('lobby') == 'start', 3)
            # (a phone's field takes its name from a keyboard the check
            # has not got: the name is the one the game made up)
            player.tap('Net Go')
            s = player.wait_for(lambda s: s.get('lobby') == 'online', 20)
            expect('%s\'s GO ONLINE is the lobby' % name, s.get('lobby') == 'online' and s.get('relays') == '1'
                   and s.get('name', '') != '', s)
        names = {player: player.state().get('name', '') for player in players}
        expect('each has a name of its own', len(set(names.values())) == 3, sorted(names.values()))
        for player in players:
            others = {names[other]: 'free' for other in players if other is not player}
            s = player.wait_for(lambda s: listed(s) == others, 12)
            expect('%s lists the other two, by name' % player.name, listed(s) == others, s)
        ada.shot('2-players')
        bo.shot('2-players')

        # 18. a challenge, and the match
        ada.tap(row_of(ada.state(), names[bo]))
        a = ada.wait_for(lambda s: s.get('lobby') == 'asking', 3)
        b = bo.wait_for(lambda s: s.get('lobby') == 'asked', 10)
        bo.shot('3-challenged')
        expect('a tap on a player challenges them', a.get('lobby') == 'asking' and a.get('foe') == names[bo], a)
        expect('they are asked, by the challenger\'s name', b.get('lobby') == 'asked' and b.get('foe') == 'Ada'
               and bo.text('Lobby Text') == 'ADA challenges you to a duel.', b, {'text': bo.text('Lobby Text')})
        bo.tap('Accept')
        a = ada.wait_for(playing, 45)
        b = bo.wait_for(playing, 15)
        ada.shot('4-match')
        bo.shot('4-match')
        expect('ACCEPT begins the match on both, with no code carried', playing(a) and playing(b)
               and a.get('link') == 'true' and b.get('link') == 'true', a, b)
        expect('on the same wall', a.get('shift') == b.get('shift') and a.get('shift', '') != '', a, b)
        expect('against a rival with a name', ada.text('Banner Sub') == 'You against %s. Most points wins.' % names[bo]
               and bo.text('Banner Sub') == 'You against Ada. Most points wins.',
               {'ada': ada.text('Banner Sub'), 'bo': bo.text('Banner Sub')})

        # 19. the third page sees them in a duel; they have left the relay
        duel = {'Ada': 'duel', names[bo]: 'duel'}
        c = cy.wait_for(lambda s: listed(s) == duel, 10)
        cy.shot('5-others-in-a-duel')
        expect('the third page sees both in a duel', listed(c) == duel, c)
        a = ada.wait_for(lambda s: s.get('online') == 'false' and s.get('relays') == '0', 8)
        expect('a match leaves the lobby', a.get('online') == 'false' and a.get('relays') == '0', a)
        end = time.time() + 8
        while time.time() < end and len(relay.relay.clients) != 1:
            time.sleep(0.2)
        expect('and the relay', len(relay.relay.clients) == 1, {'clients': len(relay.relay.clients)})

        # 20. the match over, and back to the lobby
        ada.set('score', 3000)
        ada.set('left', 2)
        bo.set('left', 2)
        a = ada.wait_for(lambda s: s.get('mode') == 'result', 10)
        end = time.time() + 8
        while time.time() < end and (ada.text('Result Title') == 'TIME!' or bo.text('Result Title') == 'TIME!'):
            time.sleep(0.2)
        ada.shot('6-result')
        expect('time: the result names the rival', a.get('mode') == 'result'
               and ada.text('Result Them').startswith(names[bo].upper()[:10] + ' '), a, {'them': ada.text('Result Them')})
        a = leave_result(ada)
        expect('LEAVE comes back to the lobby, online again', a.get('lobby') == 'online' and a.get('online') == 'true'
               and a.get('name') == 'Ada', a)
        b = leave_result(bo)
        expect('for the other too', b.get('lobby') == 'online' and b.get('online') == 'true', b)
        for player in players:
            others = {names[other]: 'free' for other in players if other is not player}
            s = player.wait_for(lambda s: listed(s) == others, 30)
            expect('%s lists the other two again' % player.name, listed(s) == others, s)

        # 21. the relay hangs up on everyone, and each comes back by itself
        was = relay.relay.connected()
        cut = relay.relay.hang_up()
        expect('the relay hangs up on all three', cut == 3 and len(was) == 3, {'clients': cut})
        end = time.time() + LOBBY_BACK_IN
        now = relay.relay.connected()
        while time.time() < end and (len(now) != 3 or was & now):
            time.sleep(0.2)
            now = relay.relay.connected()
        expect('each asks again, well before the lobby would be given up', len(now) == 3 and not was & now,
               {'clients': len(now), 'of before': len(was & now)})
        for player in players:
            others = {names[other]: 'free' for other in players if other is not player}
            s = player.wait_for(lambda s: s.get('relays') == '1' and s.get('lobby') == 'online', 5)
            expect('%s is on the relay again, in the lobby all the while, with the other two' % player.name,
                   s.get('relays') == '1' and s.get('lobby') == 'online' and s.get('online') == 'true'
                   and listed(s) == others, s)

        # 22. a quick match
        cy.tap('Quick')
        c = cy.wait_for(lambda s: s.get('lobby') == 'quick', 3)
        expect('QUICK MATCH looks for a rival', c.get('lobby') == 'quick' and c.get('doing') == 'quick', c)
        b = bo.wait_for(lambda s: listed(s).get(names[cy]) == 'quick', 8)
        expect('the others see who wants one', listed(b).get(names[cy]) == 'quick', b)
        ada.tap('Quick')
        a = ada.wait_for(playing, 45)
        c = cy.wait_for(playing, 15)
        cy.shot('7-quick-match')
        expect('a second QUICK MATCH matches the two', playing(a) and playing(c) and a.get('shift') == c.get('shift'), a, c)
        expect('by name', cy.text('Banner Sub') == 'You against Ada. Most points wins.', {'cy': cy.text('Banner Sub')})
        b = bo.state()
        expect('and not the one who asked for none', b.get('lobby') == 'online' and b.get('duel') == 'false', b)
        c = leave_match(cy)
        expect('one leaves by Pause, back to the lobby', c.get('lobby') == 'online', c)
        a = leave_result(ada)
        expect('the other is told, and comes back too', a.get('lobby') == 'online', a)

        # 23. a friend's room, by its link
        ada.tap('Friend')
        a = ada.wait_for(lambda s: s.get('lobby') == 'room', 3)
        code = a.get('room', '')
        ada.shot('8-room')
        expect('PLAY A FRIEND makes a room, with a code of six', a.get('lobby') == 'room' and len(code) == 6
               and ada.text('Code') == code, a)
        ada.tap('Code Copy')
        link = ada.clipboard()
        expect('COPY THE LINK puts the page\'s address with the room on the clipboard',
               link.startswith(url) and ('duel=%s' % code) in link, {'clipboard': link[:200], 'room': code})
        if ('duel=%s' % code) not in link:
            link = '%s?duel=%s' % (url, code)
        bo.open(link, OPENED_LOBBY)
        bo.set('relays', relay_url)
        b = bo.state()
        bo.shot('9-friends-link')
        expect('a page opened at the link has JOIN YOUR FRIEND', b.get('lobby') == 'start' and b.get('invite') == code
               and b.get('online') == 'false', b)
        expect('and the name it had', b.get('name') == names[bo], b)
        bo.tap('Net Go')
        a = ada.wait_for(playing, 60)
        b = bo.wait_for(playing, 15)
        expect('which begins the match with the room\'s maker', playing(a) and playing(b)
               and a.get('shift') == b.get('shift'), a, b)
        c = cy.state()
        expect('and with nobody else', c.get('lobby') == 'online' and c.get('duel') == 'false', c)

        # 24. no script error
        for player in players:
            errors = player.errors()
            expect('no script error in %s\'s game' % player.name, errors == '', {'errors': errors[:400]})
            expect('none in its page', not player.page_errors, {'page errors': player.page_errors[:3]})
    finally:
        browser.close()
    return problems


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    ap.add_argument('--runtime', required=True, help='the web runtime folder')
    ap.add_argument('--engine', help='a development engine (LiveCode-Community)')
    ap.add_argument('--engine-cache', help='download the pinned development engine into this folder')
    ap.add_argument('--browser', choices=('chromium', 'webkit'), default='chromium')
    ap.add_argument('--device', action='append', help='a Playwright device profile (default: %s)' % DEFAULT_DEVICES)
    ap.add_argument('--rebuild', action='store_true', help='build Ember Bricks now instead of the committed one')
    ap.add_argument('--extensions', help='a folder of the xTalk Suite extensions with %s in it '
                    '(default: built now into the work folder by tools/oxt/xtalk_extensions.py)' % DATACHANNELXT)
    ap.add_argument('--work', help='the work folder (default: a temporary folder)')
    ap.add_argument('--timeout', type=int, default=120, help='seconds for the page to open (default 120)')
    ap.add_argument('--shots', help='a folder for screenshots of each device and of the duel')
    ap.add_argument('--min-fps', type=int, help='the fewest frames a second (default: %s)' % DEFAULT_MIN_FPS)
    ap.add_argument('--no-duel', action='store_true', help='leave out the duel between two pages')
    ap.add_argument('--no-lobby', action='store_true', help='leave out the online lobby between three pages')
    ap.add_argument('--no-pointer', action='store_true', help='leave out the level played with a mouse')
    args = ap.parse_args(argv)
    if not args.engine and not args.engine_cache:
        ap.error('--engine or --engine-cache is needed')
    work = args.work or tempfile.mkdtemp(prefix='ember-bricks-check-')
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
        stack = build_game(engine, work, args.timeout) if args.rebuild else GAME
        if not os.path.isfile(stack):
            raise CheckError('there is no %s' % stack)
        log('Deploying %s with %s' % (stack, engine))
        modules, libraries = suite_files(engine, args.extensions, work, args.timeout)
        data = deploy(engine, args.runtime, version, stack, work, args.timeout, modules, libraries)
        site = os.path.join(work, 'site')
        shutil.rmtree(site, ignore_errors=True)
        web_check.make_standalone(args.runtime, js, wasm, html, data, site, title='Ember Bricks')
        os.replace(os.path.join(site, web_check.STACK_NAME + '.html'), os.path.join(site, PAGE))
        server = web_check.make_server(site)
        url = 'http://127.0.0.1:%d/%s' % (server.server_address[1], PAGE)
        problems = []
        with sync_playwright() as p:
            for device in args.device or DEFAULT_DEVICES[args.browser]:
                log('%s, %s:' % (args.browser, device))
                problems += check_device(p, args.browser, device, url, args.timeout, args.shots,
                                         args.min_fps or DEFAULT_MIN_FPS[args.browser])
            if args.no_duel:
                log('(no duel: --no-duel)')
            elif args.browser not in DUEL_BROWSERS:
                log('(no duel in %s: a check can give no clipboard to its pages)' % args.browser)
            else:
                log('%s, a duel between a desktop\'s page and a %s:' % (args.browser, DUEL_GUEST))
                problems += check_duel(p, args.browser, url, args.timeout, args.shots)
            if args.no_lobby:
                log('(no lobby: --no-lobby)')
            elif args.browser not in DUEL_BROWSERS:
                log('(no lobby in %s: a check can give no clipboard to its pages)' % args.browser)
            else:
                import nostr_test_relay
                # (a relay that keeps for a while what it passes on, as
                # some public ones do: the game must take only what is new)
                relay = nostr_test_relay.serve(os.path.join(work, 'relay.txt'), ephemeral=LOBBY_RELAY_KEEPS)
                relay_url = 'ws://127.0.0.1:%d/' % relay.server_address[1]
                log('%s, the lobby between a desktop\'s page, a %s and an %s, on %s:'
                    % (args.browser, DUEL_GUEST, LOBBY_THIRD, relay_url))
                try:
                    problems += check_lobby(p, args.browser, url, args.timeout, args.shots, relay, relay_url)
                finally:
                    relay.shutdown()
            if args.no_pointer:
                log('(no level with a mouse: --no-pointer)')
            else:
                log('%s, a level with a mouse in a desktop\'s page:' % args.browser)
                problems += check_pointer(p, args.browser, url, args.timeout, args.shots)
        server.shutdown()
    except (CheckError, web_check.CheckError, subprocess.TimeoutExpired) as e:
        log('FAILED: %s' % e)
        return 1
    if problems:
        log('EMBER BRICKS CHECK FAILED')
        for problem in problems:
            log('  %s' % problem)
        return 1
    log('EMBER BRICKS CHECK OK')
    return 0


if __name__ == '__main__':
    sys.exit(main())
