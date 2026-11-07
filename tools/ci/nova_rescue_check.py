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

"""Play Nova Rescue on emulated phones.

  python3 tools/ci/nova_rescue_check.py --runtime DIR (--engine FILE | --engine-cache DIR)
      [--browser chromium|webkit] [--device NAME]... [--rebuild] [--work DIR]
      [--timeout SECONDS] [--shots DIR] [--min-fps N]

--runtime, --engine and --engine-cache are tools/ci/web_check.py's: the web
runtime, and the development engine that writes the standalone's startup
data (tools/ci/mobile-web-deploy.livecodescript, as the Phone Starter's
check deploys). The standalone's main stack is the committed
tools/web-player/stacks/Nova Rescue.oxtstack, or with --rebuild one that
tools/web-player/nova-rescue.livecodescript builds now; beside it go the
Mobile Web library and the check's own stack
(tools/ci/nova-rescue-check.livecodescript), which says how the game is
(its nrState) and hears of any script error in it.

Each device (Playwright's profiles: by default "Pixel 7" and "iPhone 13"
in Chromium, "iPhone 13" in WebKit) opens the page with a touch screen and
a phone's window, and:

  1. the game opens on its title, the play area the whole window, with
     its font, the browser's sound and the Mobile Web library
  2. a tap on Play shows how to play (the first time), and a tap on its
     button begins a run
  3. a finger dragged across the screen moves the ship with it
  4. an astronaut put on the ship is rescued: the crew and the score go up
  5. the Pause button pauses (the run's clock stops) and Resume goes on
  6. with things coming by themselves, the game keeps at least --min-fps
     frames a second (by default 20 in Chromium and 10 in WebKit, which
     draws without a graphics card on Linux; Chromium gave 55 to 60 where
     this check was written)
  7. the phone turns: the play area is a column in the middle of the
     window, the HUD beside it, the ship in it, and the run waits; a tap
     on Resume goes on
  8. no script error, in the game or the page

Playwright's WebKit on Linux makes no touch events, so there the taps and
the drag are the mouse's, which the game reads as it reads a finger. Ends
with "NOVA RESCUE CHECK OK" or a list of what failed, and exit status 1.
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

GAME = os.path.join(REPO, 'tools', 'web-player', 'stacks', 'Nova Rescue.oxtstack')
GAME_BUILDER = os.path.join(REPO, 'tools', 'web-player', 'nova-rescue.livecodescript')
CHECK_STACK = os.path.join(HERE, 'nova-rescue-check.livecodescript')
CHECK_NAME = 'NovaRescueCheck'
# the check stack's handlers that the page may call
HANDLERS = ['ncBegin', 'ncState', 'ncRect', 'ncPut', 'ncSpawning', 'ncErrors']
PAGE = 'NovaRescue.html'
DEFAULT_DEVICES = {'chromium': ['Pixel 7', 'iPhone 13'], 'webkit': ['iPhone 13']}
DEFAULT_MIN_FPS = {'chromium': 20, 'webkit': 10}

# A handler of the check stack, called from the page
CALL = ("(a) => { var h = document.liveCode && document.liveCode.findStackWithName('NovaRescueCheck');"
        " if (!h || !h[a[0]]) return ''; return String(h[a[0]].apply(h, a.slice(1))); }")


class CheckError(Exception):
    pass


def log(msg=''):
    print(msg, flush=True)


def build_game(engine, work, timeout):
    """A Nova Rescue built now by its builder."""
    out = os.path.join(work, 'Nova Rescue.oxtstack')
    env = dict(os.environ, OXT_NOVA_RESCUE=out)
    r = subprocess.run([engine, '-ui', GAME_BUILDER], env=env, stdout=subprocess.PIPE,
                       stderr=subprocess.STDOUT, timeout=timeout)
    text = r.stdout.decode('utf-8', 'replace')
    if r.returncode != 0 or 'BUILT' not in text:
        raise CheckError('building Nova Rescue failed: %s' % text.strip())
    return out


def deploy(engine, runtime, version, stack, work, timeout):
    output = os.path.join(work, '__startup.data')
    env = dict(os.environ, OXT_MW_STACK=stack, OXT_MW_LIBRARY=mobile_web_check.LIBRARY,
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
        raise CheckError('deploying Nova Rescue failed')
    return output


def call(page, *args):
    return str(page.evaluate(CALL, list(args)))


def parse_state(text):
    """nrState's lines, name:value, as a dict"""
    out = {}
    for line in (text or '').split('\n'):
        if ':' in line:
            key, value = line.split(':', 1)
            out[key] = value
    return out


def state(page):
    return parse_state(call(page, 'ncState'))


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
    r = rect(call(page, 'ncRect', name))
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
            keys = ('mode', 'score', 'rescued', 'shipx', 'shipy', 'column', 'bounds', 'now', 'fps', 'font',
                    'audio', 'library', 'hull')
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
        page.wait_for_function("() => { var h = document.liveCode && document.liveCode.findStackWithName('NovaRescueCheck');"
                               " return !!(h && h.ncState && String(h.ncState()).indexOf('mode:title') === 0); }",
                               timeout=timeout * 1000)
        call(page, 'ncBegin')
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

        # 1. the title, the whole window
        s = wait_for(page, lambda s: rect(s.get('column', '')) == [0, 0, width, height])
        time.sleep(0.5)
        shot('1-title')
        expect('the game opens on its title', s.get('mode') == 'title', s)
        expect('the play area is the whole window (%dx%d)' % (width, height),
               rect(s.get('column', '')) == [0, 0, width, height], s)
        expect('with its font', s.get('font') == 'true', s)
        expect('the browser\'s sound', s.get('audio') == 'web', s)
        expect('and the Mobile Web library', s.get('library') == 'true', s)

        # 2. Play: how to play, then a run
        tap('Play')
        s = wait_for(page, lambda s: s.get('mode') == 'howto', 3)
        shot('2-howto')
        expect('the first Play shows how to play', s.get('mode') == 'howto', s)
        tap('Howto Go')
        s = wait_for(page, lambda s: s.get('mode') == 'play', 3)
        expect('its button begins a run', s.get('mode') == 'play', s)
        call(page, 'ncSpawning', 'false')
        time.sleep(1.5)

        # 3. a finger moves the ship: a drag to the left and up
        s = state(page)
        x0, y0 = number(s, 'shipx', 0), number(s, 'shipy', 0)
        fingers.drag(width / 2 + 40, height - 140, width / 2 - 40, height - 180, steps=10, pause=0.04)
        time.sleep(0.4)
        s = state(page)
        shot('3-drag')
        expect('a finger dragged left moves the ship left', number(s, 'shipx', x0) <= x0 - 50, s)
        expect('and up', number(s, 'shipy', y0) <= y0 - 25, s)

        # 4. an astronaut on the ship is rescued
        call(page, 'ncPut', 'pod', s.get('shipx'), s.get('shipy'), '0')
        s = wait_for(page, lambda s: s.get('rescued') == '1', 3)
        expect('an astronaut on the ship is rescued', s.get('rescued') == '1', s)
        expect('for 250', s.get('score') == '250', s)

        # 5. Pause and Resume
        tap('Pause')
        s = wait_for(page, lambda s: s.get('mode') == 'pause', 3)
        shot('4-pause')
        expect('Pause pauses', s.get('mode') == 'pause', s)
        was = s.get('now')
        time.sleep(1)
        s = state(page)
        expect('the run waits', s.get('now') == was, s)
        tap('Resume')
        s = wait_for(page, lambda s: s.get('mode') == 'play', 3)
        expect('Resume goes on', s.get('mode') == 'play', s)

        # 6. the frame rate, with things coming
        call(page, 'ncSpawning', 'true')
        time.sleep(4)
        s = state(page)
        shot('5-play')
        if s.get('mode') == 'play':
            log('  (%s frames a second; the game\'s own work %s ms a frame, the drawing %s ms)'
                % (s.get('fps'), s.get('work'), s.get('draw')))
            expect('at least %d frames a second' % min_fps, number(s, 'fps', 0) >= min_fps, s)
        else:
            expect('the run is still playing', False, s)

        # 7. the phone turns
        page.set_viewport_size({'width': height, 'height': width})
        s = wait_for(page, lambda s: s.get('mode') == 'pause' and rect(s.get('column', '')) is not None
                     and rect(s.get('column', ''))[3] == width, 4)
        time.sleep(0.5)
        shot('6-turned')
        column = rect(s.get('column', '')) or [0, 0, 0, 0]
        bounds = rect(s.get('bounds', '')) or [0, 0, 0, 0]
        expect('turned, the play area is a column in the middle',
               column[1] == 0 and column[3] == width and 0 < column[0] and column[2] < height
               and abs(column[0] - (height - column[2])) <= 1, s)
        score = rect(call(page, 'ncRect', 'Score'))
        expect('the HUD beside it', score is not None and score[2] <= column[0], {'Score': score})
        expect('the ship in it', column[0] <= bounds[0] and bounds[2] <= column[2]
               and column[0] <= number(s, 'shipx', -1) <= column[2], s)
        expect('the run waits for the player', s.get('mode') == 'pause', s)
        if s.get('mode') == 'pause':
            tap('Resume')
            s = wait_for(page, lambda s: s.get('mode') == 'play', 3)
            expect('Resume goes on', s.get('mode') == 'play', s)
            time.sleep(1)

        # 8. no script error
        errors = call(page, 'ncErrors')
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
    ap.add_argument('--rebuild', action='store_true', help='build Nova Rescue now instead of the committed one')
    ap.add_argument('--work', help='the work folder (default: a temporary folder)')
    ap.add_argument('--timeout', type=int, default=120, help='seconds for the page to open (default 120)')
    ap.add_argument('--shots', help='a folder for screenshots of each device')
    ap.add_argument('--min-fps', type=int, help='the fewest frames a second (default: %s)' % DEFAULT_MIN_FPS)
    args = ap.parse_args(argv)
    if not args.engine and not args.engine_cache:
        ap.error('--engine or --engine-cache is needed')
    work = args.work or tempfile.mkdtemp(prefix='nova-rescue-check-')
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
        data = deploy(engine, args.runtime, version, stack, work, args.timeout)
        site = os.path.join(work, 'site')
        shutil.rmtree(site, ignore_errors=True)
        web_check.make_standalone(args.runtime, js, wasm, html, data, site, title='Nova Rescue')
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
        log('NOVA RESCUE CHECK FAILED')
        for problem in problems:
            log('  %s' % problem)
        return 1
    log('NOVA RESCUE CHECK OK')
    return 0


if __name__ == '__main__':
    sys.exit(main())
