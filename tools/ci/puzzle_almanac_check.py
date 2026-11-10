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

"""Play Puzzle Almanac on emulated phones.

  python3 tools/ci/puzzle_almanac_check.py --runtime DIR (--engine FILE | --engine-cache DIR)
      [--browser chromium|webkit] [--device NAME]... [--rebuild] [--work DIR]
      [--timeout SECONDS] [--shots DIR]

--runtime, --engine and --engine-cache are tools/ci/web_check.py's: the web
runtime, and the development engine that writes the standalone's startup
data (tools/ci/mobile-web-deploy.livecodescript, as the Phone Starter's
check deploys). The standalone's main stack is the committed
tools/web-player/stacks/Puzzle Almanac.oxtstack, or with --rebuild one
that tools/web-player/puzzle-almanac.livecodescript builds now; beside it
go the Mobile Web library and the check's own stack
(tools/ci/puzzle-almanac-check.livecodescript), which says how the game
is (its paState) and hears of any script error in it.

Each device (Playwright's profiles: by default "Pixel 7" and "iPhone 13"
in Chromium, "iPhone 13" in WebKit) opens the page with a touch screen and
a phone's window, in a browser of its own (so its storage is empty: a
first visit), and:

  1. the game opens on Home, with How to play shown (the first time),
     its font, the browser's sound and the Mobile Web library; a tap on
     Done closes How to play
  2. a tap on Number Place opens today's; a tap on an empty square and
     on its number writes the number in
  3. every square but one filled in (as taps would, by the game's own
     paPress), a tap on the last and its number solves the board: the
     Done panel shows with the day's sticker, and Home goes home
  4. a tap on Hidden Word opens today's; today's word typed by taps on
     the keyboard and Enter turns the tiles one by one, all of them gold,
     and the Done panel shows the next sticker
  5. the sticker book opens on a tap
  6. the page loaded again (the game's save is in the browser's storage):
     How to play is not shown again, and the stickers and both of the
     day's puzzles are kept
  7. the phone turns on its side: Home, Number Place and Hidden Word are
     laid out side by side, everything on the window
  8. no script error, in the game or the page

Playwright's WebKit on Linux makes no touch events, so there the taps are
the mouse's, which the game reads as it reads a finger. Ends with
"PUZZLE ALMANAC CHECK OK" or a list of what failed, and exit status 1.
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

GAME = os.path.join(REPO, 'tools', 'web-player', 'stacks', 'Puzzle Almanac.oxtstack')
GAME_BUILDER = os.path.join(REPO, 'tools', 'web-player', 'puzzle-almanac.livecodescript')
CHECK_STACK = os.path.join(HERE, 'puzzle-almanac-check.livecodescript')
CHECK_NAME = 'PuzzleAlmanacCheck'
# the check stack's handlers that the page may call
HANDLERS = ['pcBegin', 'pcState', 'pcRect', 'pcFillAllButOne', 'pcErrors']
PAGE = 'PuzzleAlmanac.html'
DEFAULT_DEVICES = {'chromium': ['Pixel 7', 'iPhone 13'], 'webkit': ['iPhone 13']}

# A handler of the check stack, called from the page
CALL = ("(a) => { var h = document.liveCode && document.liveCode.findStackWithName('PuzzleAlmanacCheck');"
        " if (!h || !h[a[0]]) return ''; return String(h[a[0]].apply(h, a.slice(1))); }")
# True once the game is on Home
OPEN = ("() => { var h = document.liveCode && document.liveCode.findStackWithName('PuzzleAlmanacCheck');"
        " return !!(h && h.pcState && String(h.pcState()).indexOf('screen:home') === 0); }")


class CheckError(Exception):
    pass


def log(msg=''):
    print(msg, flush=True)


def build_game(engine, work, timeout):
    """A Puzzle Almanac built now by its builder."""
    out = os.path.join(work, 'Puzzle Almanac.oxtstack')
    env = dict(os.environ, OXT_PUZZLE_ALMANAC=out)
    r = subprocess.run([engine, '-ui', GAME_BUILDER], env=env, stdout=subprocess.PIPE,
                       stderr=subprocess.STDOUT, timeout=timeout)
    text = r.stdout.decode('utf-8', 'replace')
    if r.returncode != 0 or 'BUILT' not in text:
        raise CheckError('building Puzzle Almanac failed: %s' % text.strip())
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
        raise CheckError('deploying Puzzle Almanac failed')
    return output


def call(page, *args):
    return str(page.evaluate(CALL, list(args)))


def parse_state(text):
    """paState's lines, name:value, as a dict"""
    out = {}
    for line in (text or '').split('\n'):
        if ':' in line:
            key, value = line.split(':', 1)
            out[key] = value
    return out


def state(page):
    return parse_state(call(page, 'pcState'))


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
    r = rect(call(page, 'pcRect', name))
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


def check_device(playwright, browser_name, device, url, timeout, shots):
    problems = []
    page_errors = []

    def expect(what, ok, s):
        if ok:
            log('  ok: %s' % what)
        else:
            problems.append('%s, %s: %s' % (browser_name, device, what))
            keys = ('screen', 'panel', 'today', 'size', 'length', 'howto', 'stickers', 'award', 'nlast', 'wlast',
                    'n', 'ndaily', 'chosen', 'board', 'solved', 'len', 'wdaily', 'rows', 'scores', 'typed', 'over',
                    'turning', 'message', 'side', 'compact', 'font', 'audio', 'library')
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
        page.wait_for_function(OPEN, timeout=timeout * 1000)
        call(page, 'pcBegin')
        width, height = profile['viewport']['width'], profile['viewport']['height']
        fingers = mobile_web_check.Fingers(page, context, browser_name)
        if not fingers.touches:
            log('  (this browser makes no touch events: the taps are the mouse\'s)')

        def shot(name):
            if shots:
                page.screenshot(path=os.path.join(shots, '%s-%s-%s.png' % (browser_name, device.replace(' ', '-'), name)))

        def tap(name):
            x, y = middle(page, name)
            fingers.tap(x, y)
            time.sleep(0.1)

        def inside(name, w, h):
            r = rect(call(page, 'pcRect', name))
            return r is not None and r[0] >= 0 and r[1] >= 0 and r[2] <= w and r[3] <= h

        def all_inside(names, w, h):
            return {name: call(page, 'pcRect', name) for name in names if not inside(name, w, h)}

        # 1. Home, How to play on the first visit
        time.sleep(0.5)
        s = state(page)
        shot('1-howto')
        expect('the game opens on Home', s.get('screen') == 'home', s)
        expect('How to play shows the first time', s.get('panel') == 'howto', s)
        expect('with its font', s.get('font') == 'true', s)
        expect('the browser\'s sound', s.get('audio') == 'web', s)
        expect('and the Mobile Web library', s.get('library') == 'true', s)
        today = s.get('today')
        tap('Howto Done')
        s = wait_for(page, lambda s: s.get('panel') == '', 3)
        shot('2-home')
        expect('Done closes How to play', s.get('panel') == '' and s.get('howto') == 'true', s)
        missing = all_inside(['Numbers Card', 'Words Card', 'Stickers Open', 'Practice Open', 'Howto Open',
                              'Settings Open'], width, height)
        expect('Home on the window', not missing, missing)

        # 2. today's Number Place, a square and its number
        tap('Numbers Card')
        s = wait_for(page, lambda s: s.get('screen') == 'numbers', 3)
        expect('a tap on Number Place opens today\'s',
               s.get('screen') == 'numbers' and s.get('ndaily') == 'true' and s.get('n') == '6', s)
        board, answer = s.get('board', ''), s.get('answer', '')
        cell = board.find('0') + 1
        if cell > 0 and len(answer) == len(board):
            tap('N Cell %d' % cell)
            tap('N Key %s' % answer[cell - 1])
            s = wait_for(page, lambda s: s.get('board', '')[cell - 1:cell] == answer[cell - 1], 3)
            shot('3-numbers')
            expect('a tap on an empty square and its number writes it in',
                   s.get('chosen') == str(cell) and s.get('board', '')[cell - 1:cell] == answer[cell - 1], s)
        else:
            expect('today\'s Number Place has an empty square', False, s)
        missing = all_inside(['N Board', 'N Key 1', 'N Key 6', 'N Notes', 'N Hint', 'Back'], width, height)
        expect('Number Place on the window', not missing, missing)

        # 3. every square but one, then the last by taps: solved
        last = call(page, 'pcFillAllButOne').split(',')
        if len(last) == 2:
            tap('N Cell %s' % last[0])
            tap('N Key %s' % last[1])
        s = wait_for(page, lambda s: s.get('panel') == 'done', 4)
        time.sleep(0.6)
        shot('4-numbers-done')
        expect('the last square solves the board, and Done shows',
               s.get('solved') == 'true' and s.get('panel') == 'done' and s.get('nlast') == today, s)
        expect('with the day\'s sticker', s.get('stickers') == '1' and s.get('award') == 'owl'
               and rect(call(page, 'pcRect', 'Done Sticker')) is not None, s)
        tap('Done Home')
        s = wait_for(page, lambda s: s.get('screen') == 'home' and s.get('panel') == '', 3)
        expect('Home goes home', s.get('screen') == 'home' and s.get('panel') == '', s)

        # 4. today's Hidden Word, typed on the keyboard
        tap('Words Card')
        s = wait_for(page, lambda s: s.get('screen') == 'words', 3)
        word = s.get('word', '')
        expect('a tap on Hidden Word opens today\'s',
               s.get('screen') == 'words' and s.get('wdaily') == 'true' and len(word) == 5, s)
        missing = all_inside(['W Slot 1', 'W Slot %d' % (6 * len(word)), 'W Key Q', 'W Key P', 'W Key Enter',
                              'W Key Back', 'Back'], width, height)
        expect('Hidden Word on the window', not missing, missing)
        for letter in word:
            tap('W Key %s' % letter.upper())
        s = state(page)
        expect('the keys type the word', s.get('typed') == word, s)
        tap('W Key Enter')
        s = wait_for(page, lambda s: s.get('turning') == 'true', 2)
        shot('5-turning')
        expect('Enter turns the tiles one by one', s.get('turning') == 'true', s)
        s = wait_for(page, lambda s: s.get('panel') == 'done', 8)
        time.sleep(0.6)
        shot('6-words-done')
        expect('all gold: the word is found, and Done shows',
               s.get('over') == 'won' and s.get('scores') == 'g' * len(word) and s.get('panel') == 'done', s)
        expect('with the next sticker', s.get('stickers') == '2' and s.get('award') == 'rabbit', s)
        tap('Done Home')
        s = wait_for(page, lambda s: s.get('screen') == 'home' and s.get('panel') == '', 3)

        # 5. the sticker book
        tap('Stickers Open')
        s = wait_for(page, lambda s: s.get('screen') == 'stickers', 3)
        shot('7-stickers')
        expect('the sticker book opens', s.get('screen') == 'stickers'
               and rect(call(page, 'pcRect', 'S Slot 2')) is not None, s)
        tap('Back')
        s = wait_for(page, lambda s: s.get('screen') == 'home', 3)

        # 6. the page again: the save was kept
        errors = call(page, 'pcErrors')
        time.sleep(1.5)
        page.reload()
        page.wait_for_function(OPEN, timeout=timeout * 1000)
        call(page, 'pcBegin')
        time.sleep(0.5)
        s = state(page)
        shot('8-again')
        expect('the page again: How to play is not shown again', s.get('panel') == '' and s.get('howto') == 'true', s)
        expect('the stickers are kept', s.get('stickers') == '2', s)
        expect('and both of the day\'s puzzles', s.get('nlast') == today and s.get('wlast') == today, s)

        # 7. the phone on its side
        page.set_viewport_size({'width': height, 'height': width})
        s = wait_for(page, lambda s: s.get('side') == 'true', 4)
        time.sleep(0.5)
        shot('9-side-home')
        expect('on its side, the game is laid out side by side', s.get('side') == 'true', s)
        missing = all_inside(['Numbers Card', 'Words Card', 'Stickers Open', 'Settings Open'], height, width)
        expect('Home on the window', not missing, missing)
        tap('Numbers Card')
        s = wait_for(page, lambda s: s.get('screen') == 'numbers', 3)
        time.sleep(0.3)
        shot('10-side-numbers')
        expect('today\'s Number Place, solved', s.get('solved') == 'true', s)
        missing = all_inside(['N Board', 'N Key 1', 'N Key 6', 'N Hint', 'Back'], height, width)
        expect('Number Place on the window', not missing, missing)
        tap('Back')
        s = wait_for(page, lambda s: s.get('screen') == 'home', 3)
        tap('Words Card')
        s = wait_for(page, lambda s: s.get('screen') == 'words', 3)
        time.sleep(0.3)
        shot('11-side-words')
        expect('today\'s Hidden Word, found', s.get('over') == 'won', s)
        missing = all_inside(['W Slot 1', 'W Slot %d' % (6 * len(word)), 'W Key Q', 'W Key P', 'W Key Enter',
                              'Back'], height, width)
        expect('Hidden Word on the window', not missing, missing)

        # 8. no script error
        errors = (errors + call(page, 'pcErrors')).strip()
        expect('no script error in the game', errors == '', {'errors': errors[:400]})
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
    ap.add_argument('--rebuild', action='store_true', help='build Puzzle Almanac now instead of the committed one')
    ap.add_argument('--work', help='the work folder (default: a temporary folder)')
    ap.add_argument('--timeout', type=int, default=120, help='seconds for the page to open (default 120)')
    ap.add_argument('--shots', help='a folder for screenshots of each device')
    args = ap.parse_args(argv)
    if not args.engine and not args.engine_cache:
        ap.error('--engine or --engine-cache is needed')
    work = args.work or tempfile.mkdtemp(prefix='puzzle-almanac-check-')
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
        web_check.make_standalone(args.runtime, js, wasm, html, data, site, title='Puzzle Almanac')
        os.replace(os.path.join(site, web_check.STACK_NAME + '.html'), os.path.join(site, PAGE))
        server = web_check.make_server(site)
        url = 'http://127.0.0.1:%d/%s' % (server.server_address[1], PAGE)
        problems = []
        with sync_playwright() as p:
            for device in args.device or DEFAULT_DEVICES[args.browser]:
                log('%s, %s:' % (args.browser, device))
                problems += check_device(p, args.browser, device, url, args.timeout, args.shots)
        server.shutdown()
    except (CheckError, web_check.CheckError, subprocess.TimeoutExpired) as e:
        log('FAILED: %s' % e)
        return 1
    if problems:
        log('PUZZLE ALMANAC CHECK FAILED')
        for problem in problems:
            log('  %s' % problem)
        return 1
    log('PUZZLE ALMANAC CHECK OK')
    return 0


if __name__ == '__main__':
    sys.exit(main())
