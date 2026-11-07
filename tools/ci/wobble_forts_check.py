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

"""Play Wobble Forts on emulated phones.

  python3 tools/ci/wobble_forts_check.py --runtime DIR (--engine FILE | --engine-cache DIR)
      [--browser chromium|webkit] [--device NAME]... [--rebuild] [--work DIR]
      [--timeout SECONDS] [--shots DIR] [--min-fps N] [--extensions DIR]

--runtime, --engine and --engine-cache are tools/ci/web_check.py's: the web
runtime (its engine is the one with the xTalk Suite's libraries, so Box2D's
library is in it), and the development engine that writes the standalone's startup
data (tools/ci/mobile-web-deploy.livecodescript, as the Phone Starter's
check deploys). The standalone's main stack is the committed
tools/web-player/stacks/Wobble Forts.oxtstack, or with --rebuild one that
tools/web-player/wobble-forts.livecodescript builds now; beside it go the
Mobile Web library and the check's own stack
(tools/ci/wobble-forts-check.livecodescript), which says how the game is
(its wfState) and hears of any script error in it, and Box2Dxt's LCB
module, from --extensions or built now from the member that
tools/oxt/xtalk-extensions.json pins (tools/oxt/xtalk_extensions.py build,
which fetches it once into its cache).

Each device (Playwright's profiles: by default "Pixel 7 landscape" and
"iPhone 13 landscape" in Chromium, "iPhone 13 landscape" in WebKit) opens
the page with a touch screen and a phone's window, held on its side as the
game asks, and:

  1. the game opens on its title, with Box2D, its font, the browser's
     sound and the Mobile Web library
  2. a tap on Play shows how to play (the first time), its button the
     map, and a tap on the first level plays it
  3. a finger put down and pulled back shows the aim's dots; let go, the
     Bloop flies, and the game keeps at least --min-fps frames a second
     while the fort falls (by default 20 in Chromium and 10 in WebKit,
     which draws without a graphics card on Linux)
  4. the shot ends and the next Bloop comes, or the fort is down
  5. the Pause button pauses (the game's clock stops) and Resume goes on
  6. every Grump popped: the fort is down, with stars, and Next plays
     the next level
  7. the phone turns upright: the world is drawn smaller in the window,
     the launcher and the HUD on it
  8. no script error, in the game or the page

Playwright's WebKit on Linux makes no touch events, so there the taps and
the pull are the mouse's, which the game reads as it reads a finger. Ends
with "WOBBLE FORTS CHECK OK" or a list of what failed, and exit status 1.
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

GAME = os.path.join(REPO, 'tools', 'web-player', 'stacks', 'Wobble Forts.oxtstack')
GAME_BUILDER = os.path.join(REPO, 'tools', 'web-player', 'wobble-forts.livecodescript')
CHECK_STACK = os.path.join(HERE, 'wobble-forts-check.livecodescript')
CHECK_NAME = 'WobbleFortsCheck'
# the check stack's handlers that the page may call
HANDLERS = ['wcBegin', 'wcState', 'wcRect', 'wcPopGrumps', 'wcErrors']
PAGE = 'WobbleForts.html'
XTALK_EXTENSIONS = os.path.join(REPO, 'tools', 'oxt', 'xtalk_extensions.py')
BOX2DXT = 'org.openxtalk.box2dxt'
DEFAULT_DEVICES = {'chromium': ['Pixel 7 landscape', 'iPhone 13 landscape'], 'webkit': ['iPhone 13 landscape']}
DEFAULT_MIN_FPS = {'chromium': 20, 'webkit': 10}

# A handler of the check stack, called from the page
CALL = ("(a) => { var h = document.liveCode && document.liveCode.findStackWithName('WobbleFortsCheck');"
        " if (!h || !h[a[0]]) return ''; return String(h[a[0]].apply(h, a.slice(1))); }")


class CheckError(Exception):
    pass


def log(msg=''):
    print(msg, flush=True)


def build_game(engine, work, timeout):
    """A Wobble Forts built now by its builder."""
    out = os.path.join(work, 'Wobble Forts.oxtstack')
    env = dict(os.environ, OXT_WOBBLE_FORTS=out)
    r = subprocess.run([engine, '-ui', GAME_BUILDER], env=env, stdout=subprocess.PIPE,
                       stderr=subprocess.STDOUT, timeout=timeout)
    text = r.stdout.decode('utf-8', 'replace')
    if r.returncode != 0 or 'BUILT' not in text:
        raise CheckError('building Wobble Forts failed: %s' % text.strip())
    return out


def box2dxt_module(engine, extensions, work, timeout):
    """Box2Dxt's module.lcm: from --extensions (a folder that
    tools/oxt/xtalk_extensions.py build wrote, or an install's Extensions),
    or built now from the pinned member with the engine's lc-compile.
    The web engine has Box2D's library built in; the standalone needs the
    module that binds to it."""
    if not extensions:
        extensions = os.path.join(work, 'extensions')
        if not os.path.isfile(os.path.join(extensions, BOX2DXT, 'module.lcm')):
            r = subprocess.run([sys.executable, XTALK_EXTENSIONS, 'build', '--bin', os.path.dirname(engine),
                                '--out', extensions, '--platforms', 'x86_64-linux'],
                               stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=timeout * 5)
            if r.returncode != 0:
                raise CheckError('building the xTalk Suite extensions failed: %s'
                                 % r.stdout.decode('utf-8', 'replace').strip()[-2000:])
    module = os.path.join(extensions, BOX2DXT, 'module.lcm')
    if not os.path.isfile(module):
        raise CheckError('there is no %s' % module)
    return module


def deploy(engine, runtime, version, stack, work, timeout, modules=()):
    output = os.path.join(work, '__startup.data')
    env = dict(os.environ, OXT_MW_STACK=stack, OXT_MW_LIBRARY=mobile_web_check.LIBRARY,
               OXT_MW_MODULES='\n'.join(modules),
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
        raise CheckError('deploying Wobble Forts failed')
    return output


def call(page, *args):
    return str(page.evaluate(CALL, list(args)))


def parse_state(text):
    """wfState's lines, name:value, as a dict"""
    out = {}
    for line in (text or '').split('\n'):
        if ':' in line:
            key, value = line.split(':', 1)
            out[key] = value
    return out


def state(page):
    return parse_state(call(page, 'wcState'))


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


def middle(page, name):
    """The middle of a control of the game, where a finger taps it"""
    r = rect(call(page, 'wcRect', name))
    if not r:
        raise CheckError('the game has no %s to tap' % name)
    return (r[0] + r[2]) / 2, (r[1] + r[3]) / 2


def wait_for(page, test, seconds=6.0):
    """The state once test(state) is true, or the last one."""
    end = time.time() + seconds
    while True:
        s = state(page)
        if test(s) or time.time() > end:
            return s
        time.sleep(0.15)


def check_device(playwright, browser_name, device, url, timeout, shots, min_fps):
    problems = []
    page_errors = []

    def expect(what, ok, s):
        if ok:
            log('  ok: %s' % what)
        else:
            problems.append('%s, %s: %s' % (browser_name, device, what))
            keys = ('mode', 'level', 'score', 'grumps', 'shots', 'loaded', 'bloops', 'now', 'fps', 'font',
                    'audio', 'library', 'physics', 'view', 'levelstars')
            log('  FAILED: %s (%s)' % (what, ', '.join('%s=%s' % (k, s[k]) for k in keys if k in s) or s))

    profile = dict(playwright.devices[device])
    profile.pop('default_browser_type', None)
    browser = getattr(playwright, browser_name).launch(**mobile_web_check.launch_options(browser_name))
    try:
        context = browser.new_context(**profile)
        page = context.new_page()
        page.on('pageerror', lambda e: page_errors.append(str(e)))
        page.on('console', lambda m: log('  console.%s: %s' % (m.type, m.text)) if m.type == 'error' else None)
        page.goto(url)
        page.wait_for_function("() => { var h = document.liveCode && document.liveCode.findStackWithName('WobbleFortsCheck');"
                               " return !!(h && h.wcState && String(h.wcState()).indexOf('mode:title') === 0); }",
                               timeout=timeout * 1000)
        call(page, 'wcBegin')
        width, height = profile['viewport']['width'], profile['viewport']['height']
        fingers = mobile_web_check.Fingers(page, context, browser_name)
        if not fingers.touches:
            log('  (this browser makes no touch events: the taps and the pull are the mouse\'s)')

        def shot(name):
            if shots:
                page.screenshot(path=os.path.join(shots, '%s-%s-%s.png' % (browser_name, device.replace(' ', '-'), name)))

        def tap(name):
            x, y = middle(page, name)
            fingers.tap(x, y)

        def inside(name, w, h):
            r = rect(call(page, 'wcRect', name))
            return r is not None and r[0] >= 0 and r[1] >= 0 and r[2] <= w and r[3] <= h

        # 1. the title
        time.sleep(0.5)
        s = state(page)
        shot('1-title')
        expect('the game opens on its title', s.get('mode') == 'title', s)
        expect('with Box2D', s.get('physics') == 'true', s)
        expect('with its font', s.get('font') == 'true', s)
        expect('the browser\'s sound', s.get('audio') == 'web', s)
        expect('and the Mobile Web library', s.get('library') == 'true', s)

        # 2. Play: how to play, the map, the first level
        tap('Play')
        s = wait_for(page, lambda s: s.get('mode') == 'howto', 3)
        shot('2-howto')
        expect('the first Play shows how to play', s.get('mode') == 'howto', s)
        tap('Howto Go')
        s = wait_for(page, lambda s: s.get('mode') == 'map', 3)
        shot('3-map')
        expect('its button shows the map', s.get('mode') == 'map', s)
        tap('Tile 1')
        s = wait_for(page, lambda s: s.get('mode') == 'aim', 3)
        expect('the first level plays', s.get('mode') == 'aim' and s.get('level') == '1', s)
        time.sleep(1)

        # 3. a pull, from the middle of the screen back to the left, and
        # let go
        x0, y0 = width * 0.55, height * 0.45
        x1, y1 = x0 - width * 0.14, y0 + width * 0.05
        fingers._send('touchStart', [(x0, y0)])
        for i in range(1, 11):
            fingers._send('touchMove', [(x0 + (x1 - x0) * i / 10, y0 + (y1 - y0) * i / 10)])
            time.sleep(0.04)
        time.sleep(0.3)
        shot('4-aim')
        aim = call(page, 'wcRect', 'Aim 2')
        expect('pulled back, the aim\'s dots show', rect(aim) is not None, {'Aim 2': aim})
        fingers._send('touchEnd', [])
        s = wait_for(page, lambda s: s.get('shots') == '1', 2)
        expect('let go, the Bloop flies', s.get('shots') == '1' and s.get('mode') in ('fly', 'aim', 'clear'), s)
        time.sleep(1.2)
        s = state(page)
        shot('5-fly')
        if s.get('mode') == 'fly':
            log('  (%s frames a second; the game\'s own work %s ms a frame, of it the physics %s ms; the drawing %s ms)'
                % (s.get('fps'), s.get('work'), s.get('step'), s.get('draw')))
            expect('at least %d frames a second' % min_fps, number(s, 'fps', 0) >= min_fps, s)

        # 4. the shot ends: the next Bloop, or the fort is down
        s = wait_for(page, lambda s: s.get('mode') in ('aim', 'clear', 'fail') and s.get('loaded') != '', 20)
        shot('6-after')
        expect('the shot ends: the next Bloop comes, or the fort is down',
               (s.get('mode') == 'aim' and s.get('loaded') == 'yellow') or s.get('mode') == 'clear', s)

        # 5. Pause and Resume (a level of its own if that one was won)
        if s.get('mode') != 'aim':
            tap('Clear Replay')
            s = wait_for(page, lambda s: s.get('mode') == 'aim', 3)
        tap('Pause')
        s = wait_for(page, lambda s: s.get('mode') == 'pause', 3)
        shot('7-pause')
        expect('Pause pauses', s.get('mode') == 'pause', s)
        was = s.get('now')
        time.sleep(1)
        s = state(page)
        expect('the game waits', s.get('now') == was, s)
        tap('Resume')
        s = wait_for(page, lambda s: s.get('mode') == 'aim', 3)
        expect('Resume goes on', s.get('mode') == 'aim', s)

        # 6. every Grump popped: the fort is down
        call(page, 'wcPopGrumps')
        s = wait_for(page, lambda s: s.get('mode') == 'clear', 5)
        time.sleep(2.5)
        s = state(page)
        shot('8-clear')
        expect('every Grump popped: the fort is down', s.get('mode') == 'clear', s)
        expect('with stars', number(s, 'levelstars', 0) >= 1, s)
        tap('Clear Next')
        s = wait_for(page, lambda s: s.get('mode') == 'aim' and s.get('level') == '2', 3)
        expect('Next plays the next level', s.get('mode') == 'aim' and s.get('level') == '2', s)

        # 7. the phone turns upright
        view = number(s, 'view', 0)
        page.set_viewport_size({'width': height, 'height': width})
        s = wait_for(page, lambda s: number(s, 'view', 0) != view, 4)
        time.sleep(1)
        shot('9-upright')
        expect('upright, the world is drawn smaller', 0 < number(s, 'view', 0) < view, s)
        expect('the launcher on the window', inside('Post', height, width) and inside('Loaded', height, width),
               {'Post': call(page, 'wcRect', 'Post'), 'Loaded': call(page, 'wcRect', 'Loaded')})
        expect('the HUD too', inside('Pause', height, width) and inside('Score', height, width),
               {'Pause': call(page, 'wcRect', 'Pause'), 'Score': call(page, 'wcRect', 'Score')})

        # 8. no script error
        errors = call(page, 'wcErrors')
        expect('no script error in the game', errors.strip() == '', {'errors': errors.strip()[:400]})
        expect('none in the page', not page_errors, {'page errors': page_errors[:3]})
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
    ap.add_argument('--rebuild', action='store_true', help='build Wobble Forts now instead of the committed one')
    ap.add_argument('--extensions', help='a folder of the xTalk Suite extensions with %s in it '
                    '(default: built now into the work folder by tools/oxt/xtalk_extensions.py)' % BOX2DXT)
    ap.add_argument('--work', help='the work folder (default: a temporary folder)')
    ap.add_argument('--timeout', type=int, default=120, help='seconds for the page to open (default 120)')
    ap.add_argument('--shots', help='a folder for screenshots of each device')
    ap.add_argument('--min-fps', type=int, help='the fewest frames a second (default: %s)' % DEFAULT_MIN_FPS)
    args = ap.parse_args(argv)
    if not args.engine and not args.engine_cache:
        ap.error('--engine or --engine-cache is needed')
    work = args.work or tempfile.mkdtemp(prefix='wobble-forts-check-')
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
        module = box2dxt_module(engine, args.extensions, work, args.timeout)
        data = deploy(engine, args.runtime, version, stack, work, args.timeout, [module])
        site = os.path.join(work, 'site')
        shutil.rmtree(site, ignore_errors=True)
        web_check.make_standalone(args.runtime, js, wasm, html, data, site, title='Wobble Forts')
        os.replace(os.path.join(site, web_check.STACK_NAME + '.html'), os.path.join(site, PAGE))
        server = web_check.make_server(site)
        url = 'http://127.0.0.1:%d/%s' % (server.server_address[1], PAGE)
        problems = []
        with sync_playwright() as p:
            for device in args.device or DEFAULT_DEVICES[args.browser]:
                log('%s, %s:' % (args.browser, device))
                problems += check_device(p, args.browser, device, url, args.timeout, args.shots,
                                         args.min_fps or DEFAULT_MIN_FPS[args.browser])
        server.shutdown()
    except (CheckError, web_check.CheckError, subprocess.TimeoutExpired) as e:
        log('FAILED: %s' % e)
        return 1
    if problems:
        log('WOBBLE FORTS CHECK FAILED')
        for problem in problems:
            log('  %s' % problem)
        return 1
    log('WOBBLE FORTS CHECK OK')
    return 0


if __name__ == '__main__':
    sys.exit(main())
