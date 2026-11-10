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
"""Play Wobble Forts on its page of the web stacks gallery
(tools/pages/games/wobble-forts/), as a visitor to the site does:

  python3 tools/pages/check_wobble_forts_page.py --player DIR|ZIP
      [--work DIR] [--shots DIR] [--timeout S]

--player is a Stack Player that tools/web-player/build_player.py built:
its folder, or its zip (OXT-Beyond-<version>-web-player.zip). Its site is
made in --work as tools/pages/build_pages.py makes the web site's player,
bare player and gallery (bare_player and games), and served there. The
page plays the player's sample in the bare player (play/?play=Wobble%20Forts),
so a player without the sample has no page to check: that is a failure.
build_player.py --check runs the same checks (check_player) on the player
it has just built.

In headless Chromium:

  on a computer, the window 1440 by 900 and 1280 by 720:
    1. the game opens in the page's frame of a phone on its side: the
       cover goes, and the game is on its title, at its own size (960 by
       540), with Box2D, its font, the browser's sound and the Mobile Web
       library
    2. the frame is in the window, whole, as the page opens (it is first
       on the page), and the bare player in it has no scroll bars
    3. the keys play it at once, nothing clicked first: Space shows how to
       play, Space again the map, Space again the first fort; then the
       mouse, dragged back in the frame and let go, sends a Bloop flying
  on a phone (Playwright's iPhone 13 on its side, and Pixel 7):
    4. the page loads no engine (no .wasm is asked for) and its frame
       stays empty
    5. a tap on the game's picture opens the bare player with the sample,
       and the game fills the window, on its title, with the Mobile Web
       library
  and on both, no error in the page.

The game says how it is through wfState, one of the stack's
cJavascriptHandlers (tools/web-player/wobble-forts.livecodescript). Ends
with "WOBBLE FORTS PAGE CHECK OK", or the checks that failed and exit
status 1. It needs Playwright (pip install playwright, then playwright
install chromium).
"""

import argparse
import functools
import http.server
import json
import os
import shutil
import sys
import tempfile
import threading
import time
import zipfile

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import build_pages  # noqa: E402

TITLE = 'Wobble Forts'
FOLDER = build_pages.OWN_PAGES[TITLE]
# The stack's own size: the page's frame shows it at that size
STACK = (960, 540)
DESKTOPS = ((1440, 900), (1280, 720))
PHONES = ('iPhone 13 landscape', 'Pixel 7')

# wfState of the game in the page's frame, or in the bare player's page
FRAME_STATE = ("() => { var f = document.getElementById('game'); var d = f && f.contentDocument;"
               " var h = d && d.liveCode && d.liveCode.findStackWithName('Wobble Forts');"
               " return h && h.wfState ? String(h.wfState()) : ''; }")
PAGE_STATE = ("() => { var h = document.liveCode && document.liveCode.findStackWithName('Wobble Forts');"
              " return h && h.wfState ? String(h.wfState()) : ''; }")


def parse_state(text):
    """wfState's lines, name:value, as a dict"""
    out = {}
    for line in (text or '').split('\n'):
        if ':' in line:
            key, value = line.split(':', 1)
            out[key] = value
    return out


def rect(text):
    try:
        r = [int(float(x)) for x in str(text).split(',')]
    except ValueError:
        return None
    return r if len(r) == 4 else None


def make_site(player, site):
    """The web site's player, bare player and gallery, from a built
    player's folder or zip, as build_pages.py makes them. False when the
    player has no bare player."""
    if os.path.exists(site):
        shutil.rmtree(site)
    os.makedirs(site)
    if zipfile.is_zipfile(player):
        build_pages.unpack(player, os.path.join(site, 'player'))
    else:
        shutil.copytree(player, os.path.join(site, 'player'))
    bare = build_pages.bare_player(site)
    build_pages.games(os.path.join(HERE, 'games'), os.path.join(site, 'games'), os.path.join(site, 'player'), bare)
    return bare


class Quiet(http.server.SimpleHTTPRequestHandler):
    extensions_map = dict(http.server.SimpleHTTPRequestHandler.extensions_map, **{'.wasm': 'application/wasm'})

    def log_message(self, *args):
        pass


def serve(folder):
    server = http.server.ThreadingHTTPServer(('127.0.0.1', 0), functools.partial(Quiet, directory=folder))
    threading.Thread(target=server.serve_forever, daemon=True).start()
    return server


def wait_state(page, script, test, seconds):
    """The game's state once test(state) is true, or the last one."""
    end = time.time() + seconds
    while True:
        s = parse_state(page.evaluate(script))
        if test(s) or time.time() > end:
            return s
        page.wait_for_timeout(150)


def brief(s):
    keys = ('mode', 'level', 'window', 'physics', 'font', 'audio', 'library')
    return ', '.join('%s=%s' % (k, s[k]) for k in keys if k in s) or 'no state'


def check_desktop(browser, url, size, shots, expect, timeout):
    width, height = size
    where = '%dx%d' % size
    context = browser.new_context(viewport={'width': width, 'height': height})
    page = context.new_page()
    errors = []
    page.on('pageerror', lambda e: errors.append(str(e)))
    page.goto(url)
    try:
        page.wait_for_function("() => document.getElementById('cover').classList.contains('gone')",
                               timeout=timeout * 1000)
        gone = True
    except Exception:
        gone = False
    s = wait_state(page, FRAME_STATE, lambda s: s.get('mode') == 'title', 10)
    if shots:
        page.screenshot(path=os.path.join(shots, 'wobble-page-%s.png' % where))
    expect('wobble-page-%s-opens' % where,
           gone and s.get('mode') == 'title' and s.get('window') == '%d,%d' % STACK and s.get('physics') == 'true'
           and s.get('font') == 'true' and s.get('audio') == 'web' and s.get('library') == 'true',
           'cover gone %s; %s' % (gone, brief(s)))
    box = json.loads(page.evaluate("JSON.stringify(document.getElementById('device').getBoundingClientRect())"))
    inner = page.evaluate("(() => { var d = document.getElementById('game').contentDocument;"
                          " return [d.documentElement.scrollWidth, d.documentElement.scrollHeight]; })()")
    expect('wobble-page-%s-fits' % where,
           box['y'] >= 0 and box['y'] + box['height'] <= height and box['width'] <= width
           and inner[0] <= STACK[0] and inner[1] <= STACK[1],
           'frame %dx%d in %s; the bare player %dx%d' % (box['width'], box['height'], where, inner[0], inner[1]))
    modes = []
    for want in ('howto', 'map', 'aim'):
        page.keyboard.press('Space')
        modes.append(wait_state(page, FRAME_STATE, lambda s, want=want: s.get('mode') == want, 5).get('mode'))
    # the Bloop hops into the launcher, then the mouse pulls it back in
    # the frame (the stack's points times the frame's scale) and lets go
    page.wait_for_timeout(800)
    frame = json.loads(page.evaluate("JSON.stringify(document.getElementById('game').getBoundingClientRect())"))
    scale = frame['width'] / STACK[0]

    def at(x, y):
        return frame['x'] + x * scale, frame['y'] + y * scale
    page.mouse.move(*at(300, 300))
    page.mouse.down()
    for k in range(1, 11):
        page.mouse.move(*at(300 - 12 * k, 300 + 6 * k))
        page.wait_for_timeout(30)
    page.mouse.up()
    s = wait_state(page, FRAME_STATE, lambda s: s.get('mode') == 'fly' or s.get('shots') not in (None, '', '0'), 3)
    expect('wobble-page-%s-keys' % where, modes == ['howto', 'map', 'aim'] and s.get('shots') == '1',
           'Space, Space, Space: %s; a drag: %s, shots %s' % (', '.join(map(str, modes)), s.get('mode'), s.get('shots')))
    expect('wobble-page-%s-no-errors' % where, not errors, ' | '.join(errors[:3]))
    context.close()


def check_phone(playwright, browser, url, device, shots, expect, timeout):
    where = device.replace(' ', '-').lower()
    profile = dict(playwright.devices[device])
    profile.pop('default_browser_type', None)
    context = browser.new_context(**profile)
    page = context.new_page()
    errors, asked = [], []
    page.on('pageerror', lambda e: errors.append(str(e)))
    page.on('request', lambda r: asked.append(r.url))
    page.goto(url)
    page.wait_for_load_state('load')
    page.wait_for_timeout(1500)
    phone = page.evaluate("document.documentElement.classList.contains('phone')")
    src = page.evaluate("document.getElementById('game').getAttribute('src')")
    wasm = [u for u in asked if u.split('?')[0].endswith('.wasm')]
    if shots:
        page.screenshot(path=os.path.join(shots, 'wobble-page-%s.png' % where))
    expect('wobble-page-%s-waits' % where, phone and not src and not wasm,
           'phone %s, frame %r, engine asked for %s' % (phone, src, wasm[:1] or 'no'))
    page.tap('#cover', timeout=10000)
    try:
        page.wait_for_url('**/play/?play=Wobble%20Forts*', timeout=20000)
    except Exception:
        pass
    viewport = profile['viewport']
    window = '%d,%d' % (viewport['width'], viewport['height'])
    s = wait_state(page, PAGE_STATE, lambda s: s.get('mode') == 'title' and s.get('window') == window, timeout)
    if shots:
        page.screenshot(path=os.path.join(shots, 'wobble-page-%s-play.png' % where))
    expect('wobble-page-%s-plays' % where,
           '/play/?play=Wobble%20Forts' in page.url and s.get('mode') == 'title'
           and s.get('window') == window and s.get('library') == 'true',
           '%s; %s (the window %s)' % (page.url.split('/', 3)[-1], brief(s), window))
    expect('wobble-page-%s-no-errors' % where, not errors, ' | '.join(errors[:3]))
    context.close()


def check_site(playwright, browser, site, shots, expect, timeout=120):
    """The checks on a site with the player, the bare player and the
    gallery (make_site)."""
    page = os.path.join(site, 'games', FOLDER, 'index.html')
    expect('wobble-page-made', os.path.isfile(page), 'games/%s/index.html' % FOLDER)
    if not os.path.isfile(page):
        return
    server = serve(site)
    try:
        url = 'http://127.0.0.1:%d/games/%s/' % (server.server_address[1], FOLDER)
        # (a step that cannot be taken, such as a tap on a cover that is
        # not there, fails its window's checks, and the others go on)
        for size in DESKTOPS:
            try:
                check_desktop(browser, url, size, shots, expect, timeout)
            except Exception as e:  # noqa: BLE001 (Playwright's errors and our own)
                expect('wobble-page-%dx%d' % size, False, str(e).split('\n')[0])
        for device in PHONES:
            try:
                check_phone(playwright, browser, url, device, shots, expect, timeout)
            except Exception as e:  # noqa: BLE001
                expect('wobble-page-%s' % device.replace(' ', '-').lower(), False, str(e).split('\n')[0])
    finally:
        server.shutdown()


def check_player(playwright, browser, player, work, shots, expect, timeout=120):
    """build_player.py --check's call: the page made from the player it
    has just built (its folder), in work."""
    site = os.path.join(work, 'site')
    bare = make_site(player, site)
    expect('wobble-page-bare-player', bare, 'the player has %s' % ('play/' if bare else 'no play/'))
    check_site(playwright, browser, site, shots, expect, timeout)


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    ap.add_argument('--player', required=True, help='a built Stack Player: its folder or its zip')
    ap.add_argument('--work', help='the work folder (default: a temporary folder)')
    ap.add_argument('--shots', help='a folder for screenshots')
    ap.add_argument('--timeout', type=int, default=120, help='seconds for the game to open (default 120)')
    args = ap.parse_args(argv)
    try:
        from playwright.sync_api import sync_playwright
    except ImportError:
        print('FAILED: the Python package playwright is missing')
        return 2
    work = args.work or tempfile.mkdtemp(prefix='wobble-forts-page-')
    os.makedirs(work, exist_ok=True)
    if args.shots:
        os.makedirs(args.shots, exist_ok=True)
    problems = []

    def expect(name, ok, detail=''):
        print('%s  %s%s' % ('PASS' if ok else 'FAIL', name, (': ' + detail) if detail else ''), flush=True)
        if not ok:
            problems.append(name)

    try:
        with sync_playwright() as p:
            browser = p.chromium.launch()
            try:
                check_player(p, browser, args.player, work, args.shots, expect, args.timeout)
            finally:
                browser.close()
    except (build_pages.BuildError, OSError, zipfile.BadZipFile) as e:
        print('FAILED: %s' % e)
        return 1
    if problems:
        print('WOBBLE FORTS PAGE CHECK FAILED: %s' % ', '.join(problems))
        return 1
    print('WOBBLE FORTS PAGE CHECK OK')
    return 0


if __name__ == '__main__':
    sys.exit(main())
