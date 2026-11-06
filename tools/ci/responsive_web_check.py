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

"""Check the Responsive Starter on a phone, a tablet and a desktop.

  python3 tools/ci/responsive_web_check.py --runtime DIR (--engine FILE | --engine-cache DIR)
      [--browser chromium|webkit] [--device NAME]... [--rebuild] [--work DIR]
      [--timeout SECONDS] [--shots DIR]

--runtime, --engine and --engine-cache are tools/ci/web_check.py's, as
for tools/ci/mobile_web_check.py, whose deploy script
(mobile-web-deploy.livecodescript) this check uses too. The standalone's
main stack is the committed tools/web-player/stacks/Responsive
Starter.oxtstack, or with --rebuild a stack that
tools/web-player/responsive-starter.livecodescript builds now; beside it
go the Mobile Web library (extensions/script-libraries/mobileweb) and the
check's own stack (tools/ci/responsive-web-check.livecodescript), which
reports what the Responsive Starter shows. Without --rebuild, the committed
stack's script must be responsive-starter-stack.livecodescript's.

One standalone, three screens (Playwright's profiles; by default "iPhone
13" and "iPad Mini" with a touch screen, and "Desktop Chrome" with a
mouse, in Chromium; in WebKit the same three):

  phone     the stack fills the window and is laid out as a phone's: the
            tabs at the bottom, the places in one column, the search and
            the badge in a second row of the bar; a tap on a place opens
            its details as a sheet over everything, and Close closes it;
            saved, it is on the Saved card; a swipe changes tab (where the
            browser makes touch events); given a notch and a home bar
            (rcInsets), the bars' backgrounds reach the screen's edges
            while their contents stay out of them; turned, it is a
            tablet's layout: a rail, two columns, the details in a pane
  tablet    a rail, two columns and a pane; turned (1024 wide), a
            desktop's: a sidebar, three columns
  desktop   a sidebar with the app's name, three columns, the pane;
            hovering lights a place up; the keys 2 and / go to Saved and
            to the search; typing in the search leaves the places that
            match, in the first places of the grid; made 500 wide, the
            stack is laid out as a phone's at once, and back again; in
            the dark (the browser's colour scheme), the stack is dark

Each screen's screenshots go in --shots (phone, tablet and desktop, each
layout). Ends with "RESPONSIVE WEB CHECK OK" or a list of what failed, and
exit status 1.
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
from mobile_web_check import CheckError, Fingers, launch_options, log, rect  # noqa: E402

STARTER = os.path.join(REPO, 'tools', 'web-player', 'stacks', 'Responsive Starter.oxtstack')
STARTER_BUILDER = os.path.join(REPO, 'tools', 'web-player', 'responsive-starter.livecodescript')
STARTER_SCRIPT = os.path.join(REPO, 'tools', 'web-player', 'responsive-starter-stack.livecodescript')
CHECK_STACK = os.path.join(HERE, 'responsive-web-check.livecodescript')
CHECK_NAME = 'ResponsiveCheck'
HANDLERS = ['rcState', 'rcInsets', 'rcStarterScript']
PAGE = 'ResponsiveStarter.html'
DEFAULT_DEVICES = ['iPhone 13', 'iPad Mini', 'Desktop Chrome']
# the bars, as the starter's rules have them
TAB_BAR = 64
RAIL = 88
SIDEBAR = 232
PANE = 340
# a notch and a home bar, as an iPhone 13 reports them upright
NOTCH, HOME_BAR = 47, 34


def build_starter(engine, work, timeout):
    """A Responsive Starter built now by its builder."""
    out = os.path.join(work, 'Responsive Starter.oxtstack')
    env = dict(os.environ, OXT_RESPONSIVE_STARTER=out)
    r = subprocess.run([engine, '-ui', STARTER_BUILDER], env=env, stdout=subprocess.PIPE,
                       stderr=subprocess.STDOUT, timeout=timeout)
    text = r.stdout.decode('utf-8', 'replace')
    if r.returncode != 0 or 'BUILT' not in text:
        raise CheckError('building the Responsive Starter failed: %s' % text.strip())
    return out


def deploy(engine, runtime, version, stack, work, timeout):
    output = os.path.join(work, '__startup.data')
    env = dict(os.environ, OXT_MW_STACK=stack, OXT_MW_LIBRARY=mobile_web_check.LIBRARY, OXT_MW_CHECK=CHECK_STACK,
               OXT_MW_CHECK_NAME=CHECK_NAME, OXT_MW_HANDLERS=','.join(HANDLERS),
               OXT_MW_OUTPUT=output, OXT_MW_VERSION=version,
               OXT_MW_TEMPLATE=os.path.join(runtime, 'emscripten-startup-template.livecodescript'))
    r = subprocess.run([engine, '-ui', mobile_web_check.DEPLOY_SCRIPT], cwd=work, env=env,
                       stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=timeout)
    text = r.stdout.decode('utf-8', 'replace')
    for line in text.splitlines():
        if line.strip():
            log('  deploy: %s' % line)
    if r.returncode != 0 or 'DEPLOY OK' not in text:
        raise CheckError('deploying the Responsive Starter failed')
    return output


def call(page, handler, *args):
    return page.evaluate("([h, a]) => { var s = document.liveCode.findStackWithName('%s');"
                         " return String(s[h].apply(s, a)); }" % CHECK_NAME, [handler, list(args)])


def state(page):
    text = page.evaluate("() => { var h = document.liveCode && document.liveCode.findStackWithName('%s');"
                         " return h && h.rcState ? String(h.rcState()) : ''; }" % CHECK_NAME)
    out = {}
    for line in (text or '').split('\n'):
        if '=' in line:
            key, value = line.split('=', 1)
            out[key] = value
    return out


def wait_for(page, test, seconds=6.0):
    end = time.time() + seconds
    while True:
        s = state(page)
        if test(s) or time.time() > end:
            return s
        time.sleep(0.2)


def tiles(text):
    """The places that show, in a grid: {number: [l, t, r, b]}"""
    out = {}
    for part in (text or '').split(';'):
        if ':' in part:
            number, value = part.split(':', 1)
            r = rect(value)
            if r and len(r) == 4:
                out[int(number)] = r
    return out


def columns(text):
    """How many columns the places are in: the distinct lefts"""
    return len({r[0] for r in tiles(text).values()})


def centre(r):
    return (r[0] + r[2]) / 2, (r[1] + r[3]) / 2


class Screen:
    """One device's page, with what it checks"""

    def __init__(self, playwright, browser_name, device, url, timeout, shots, dark=False):
        self.browser_name = browser_name
        self.device = device
        self.shots = shots
        self.problems = []
        profile = dict(playwright.devices[device])
        profile.pop('default_browser_type', None)
        self.touch = profile.get('has_touch', False)
        self.browser = getattr(playwright, browser_name).launch(**launch_options(browser_name))
        self.context = self.browser.new_context(color_scheme='dark' if dark else 'light', **profile)
        self.page = self.context.new_page()
        self.page.on('pageerror', lambda e: log('  page error: %s' % e))
        self.page.on('console', lambda m: log('  console.%s: %s' % (m.type, m.text)) if m.type == 'error' else None)
        self.page.goto(url)
        self.page.wait_for_function(
            "() => { var h = document.liveCode && document.liveCode.findStackWithName('%s');"
            " return !!(h && h.rcState && String(h.rcState()).indexOf('card=') === 0); }" % CHECK_NAME,
            timeout=timeout * 1000)
        self.width, self.height = profile['viewport']['width'], profile['viewport']['height']
        if self.touch:
            self.fingers = Fingers(self.page, self.context, browser_name)
        else:
            self.fingers = None

    def close(self):
        self.browser.close()

    def expect(self, what, ok, s):
        if ok:
            log('  ok: %s' % what)
        else:
            self.problems.append('%s: %s' % (self.device, what))
            log('  FAILED: %s (%s)' % (what, ', '.join('%s=%s' % kv for kv in sorted(s.items()))))

    def shot(self, name):
        if self.shots:
            self.page.screenshot(path=os.path.join(
                self.shots, '%s-%s-%s.png' % (self.browser_name, self.device.replace(' ', '-'), name)))

    def tap(self, x, y):
        if self.fingers:
            self.fingers.tap(x, y)
        else:
            self.page.mouse.click(x, y)
        time.sleep(0.3)

    def resize(self, width, height):
        self.page.set_viewport_size({'width': width, 'height': height})
        self.width, self.height = width, height
        return wait_for(self.page, lambda s: rect(s.get('rect', '')) == [0, 0, width, height])

    def on_card(self, name):
        s = wait_for(self.page, lambda s: s.get('card') == name)
        time.sleep(0.6)
        return s

    def fills(self, s):
        self.expect('the stack fills the window (%dx%d)' % (self.width, self.height),
                    rect(s.get('rect', '')) == [0, 0, self.width, self.height], s)

    def lines_centred(self, s, layout):
        """The badge's line in the middle of its pill, and the search's
        hint in the middle of its box, within a pixel or two"""
        for key, what in (('badgeline', 'the badge'), ('hintline', 'the search\'s hint')):
            parts = [rect(p) for p in s.get(key, '').split(';')]
            ok = len(parts) == 2 and all(parts) and parts[1][3] > parts[1][1]
            if ok:
                box, line = parts
                ok = abs((box[1] + box[3]) / 2 - (line[1] + line[3]) / 2) <= 2
            self.expect('%s: %s is in the middle of its box' % (layout, what), ok, s)

    def phone_layout(self, s):
        self.lines_centred(s, 'phone')
        nav = rect(s.get('nav', ''))
        self.expect('phone: the class is phone', s.get('class') == 'phone', s)
        self.expect('phone: the badge says so', s.get('badge', '').startswith('phone'), s)
        self.expect('phone: the tabs are a bar at the bottom',
                    nav == [0, self.height - TAB_BAR, self.width, self.height], s)
        self.expect('phone: the places are in one column', columns(s.get('tiles')) == 1, s)
        self.expect('phone: the details are not shown', s.get('detailshown') == 'false', s)
        self.expect('phone: no sidebar name', s.get('brand') == 'false', s)

    def tablet_layout(self, s):
        self.lines_centred(s, 'tablet')
        nav = rect(s.get('nav', ''))
        detail = rect(s.get('detail', ''))
        grid = rect(s.get('grid', ''))
        self.expect('tablet: the class is tablet', s.get('class') == 'tablet', s)
        self.expect('tablet: the tabs are a rail at the left', nav == [0, 0, RAIL, self.height], s)
        self.expect('tablet: the rail says "Guide"', s.get('navguide', '').endswith(';Guide'), s)
        self.expect('tablet: the places are in two columns', columns(s.get('tiles')) == 2, s)
        self.expect('tablet: the details are a pane at the right',
                    s.get('detailshown') == 'true' and detail and detail[2] == self.width
                    and grid and grid[2] <= detail[0], s)
        self.expect('tablet: no Close in the pane', s.get('close', '').startswith('false'), s)

    def desktop_layout(self, s):
        self.lines_centred(s, 'desktop')
        nav = rect(s.get('nav', ''))
        detail = rect(s.get('detail', ''))
        self.expect('desktop: the class is desktop', s.get('class') == 'desktop', s)
        self.expect('desktop: the tabs are a sidebar', nav == [0, 0, SIDEBAR, self.height], s)
        self.expect('desktop: the sidebar has the app\'s name', s.get('brand') == 'true', s)
        self.expect('desktop: the places are in three columns', columns(s.get('tiles')) == 3, s)
        self.expect('desktop: the details are a pane %d wide' % PANE,
                    s.get('detailshown') == 'true' and detail == [self.width - PANE, detail[1], self.width,
                                                                  self.height], s)

    def tile_centre(self, s, number, saved=False):
        r = tiles(s.get('saved' if saved else 'tiles')).get(number)
        if not r:
            raise CheckError('place %d is not in the grid' % number)
        return centre(r)

    def script_is_built(self):
        with open(STARTER_SCRIPT, encoding='utf-8') as f:
            want = f.read().split('\n', 1)[1]
        got = call(self.page, 'rcStarterScript')
        self.expect('the stack is built from responsive-starter-stack.livecodescript (build it again)',
                    got.rstrip('\n') == want.rstrip('\n'), {'script': '%d characters' % len(got)})


def check_phone(screen):
    s = wait_for(screen.page, lambda s: rect(s.get('rect', '')) == [0, 0, screen.width, screen.height]
                 and s.get('class') == 'phone')
    screen.shot('1-phone')
    screen.fills(s)
    screen.phone_layout(s)
    if screen.touch and screen.fingers and screen.fingers.touches:
        screen.expect('phone: the badge says touch', s.get('badge', '').endswith('touch'), s)

    # a place opens as a sheet over everything; Close closes it
    x, y = screen.tile_centre(s, 1)
    screen.tap(x, y)
    s = wait_for(screen.page, lambda s: s.get('detailshown') == 'true')
    screen.shot('2-phone-sheet')
    detail = rect(s.get('detail', ''))
    screen.expect('phone: a tap on a place opens it as a sheet over everything',
                  s.get('detailshown') == 'true' and detail == [0, 0, screen.width, screen.height]
                  and s.get('place') == 'Kyoto' and s.get('placeshown') == 'true', s)
    screen.expect('phone: the sheet has Close', s.get('close', '').startswith('true'), s)
    save = rect(s.get('save', '').split(';')[-1])
    if save:
        screen.tap(*centre(save))
        s = wait_for(screen.page, lambda s: s.get('save', '').startswith('Saved'))
        screen.expect('phone: "Save this place" saves it', s.get('save', '').startswith('Saved;'), s)
    close = rect(s.get('close', '').split(';')[-1])
    screen.tap(*centre(close))
    s = wait_for(screen.page, lambda s: s.get('detailshown') == 'false')
    screen.expect('phone: Close closes the sheet', s.get('detailshown') == 'false', s)

    # the Saved tab has it; a swipe changes tab where there are touches
    screen.tap(screen.width / 2, screen.height - TAB_BAR / 2)
    s = screen.on_card('Saved')
    screen.shot('3-phone-saved')
    screen.expect('phone: the Saved tab has the place saved', list(tiles(s.get('saved'))) == [1], s)
    if screen.fingers and screen.fingers.touches:
        screen.fingers.drag(screen.width * 0.8, screen.height * 0.6, screen.width * 0.2, screen.height * 0.6, steps=6)
        s = screen.on_card('Guide')
        screen.expect('phone: a swipe left goes to the next tab', s.get('card') == 'Guide', s)
        screen.shot('4-phone-guide')
        screen.fingers.drag(screen.width * 0.2, screen.height * 0.4, screen.width * 0.8, screen.height * 0.4, steps=6)
        s = screen.on_card('Saved')
        screen.expect('phone: a swipe right goes back', s.get('card') == 'Saved', s)
    screen.tap(screen.width / 6, screen.height - TAB_BAR / 2)
    s = screen.on_card('Explore')

    # a notch and a home bar: the bars' backgrounds reach the edges, their
    # contents stay out of them
    call(screen.page, 'rcInsets', NOTCH, 0, HOME_BAR, 0)
    s = wait_for(screen.page, lambda s: (rect(s.get('titlerect', '')) or [0, 0])[1] >= NOTCH)
    screen.shot('5-phone-notch')
    top_back, title = rect(s.get('topback', '')), rect(s.get('titlerect', ''))
    nav_back, explore = rect(s.get('navback', '')), rect(s.get('navexplore', ''))
    screen.expect('notch: the top bar reaches the top of the screen', top_back and top_back[1] == 0, s)
    screen.expect('notch: the title is below the notch', title and title[1] >= NOTCH, s)
    screen.expect('notch: the tab bar reaches the bottom of the screen',
                  nav_back and nav_back[3] == screen.height, s)
    screen.expect('notch: the tabs are above the home bar', explore and explore[3] <= screen.height - HOME_BAR, s)
    # the last place, below the window: laid out within all of itself
    # (its back the whole place, its blurb in it), with a notch and without
    for _ in range(2):
        parts = [rect(p) for p in s.get('lasttile', '').split(';')]
        whole = len(parts) == 3 and all(parts) and parts[0][1] > screen.height
        screen.expect('the last place, below the window: its back is all of it',
                      whole and parts[1] == parts[0], s)
        screen.expect('the last place, below the window: its blurb is in it',
                      whole and parts[2][3] - parts[2][1] > 0 and parts[0][1] < parts[2][1] < parts[2][3] <= parts[0][3], s)
        call(screen.page, 'rcInsets', 0, 0, 0, 0)
        s = wait_for(screen.page, lambda s: (rect(s.get('titlerect', '')) or [0, NOTCH])[1] < NOTCH)
    # (the insets are 0 again)

    # turned: a tablet's layout (a phone on its side is 600 or wider)
    s = screen.resize(screen.height, screen.width)
    s = wait_for(screen.page, lambda s: s.get('class') == 'tablet')
    screen.shot('6-phone-landscape')
    screen.fills(s)
    screen.tablet_layout(s)
    screen.expect('turned: the place still open is in the pane', s.get('place') == 'Kyoto', s)
    # turned, with the notch at a side and the home bar below (as an
    # iPhone on its side reports them): the look button and the rail's
    # tabs stay out of both sides' strips
    call(screen.page, 'rcInsets', 0, NOTCH, 21, NOTCH)
    s = wait_for(screen.page, lambda s: (rect(s.get('theme', '')) or [0, 0, 1e9])[2] <= screen.width - NOTCH)
    screen.shot('7-phone-landscape-notch')
    theme, explore = rect(s.get('theme', '')), rect(s.get('navexplore', ''))
    screen.expect('turned, notch at the side: the look button is clear of the notch',
                  theme and theme[2] <= screen.width - NOTCH, s)
    screen.expect('turned, notch at the side: the rail\'s tabs are clear of the notch',
                  explore and explore[0] >= NOTCH, s)
    call(screen.page, 'rcInsets', 0, 0, 0, 0)
    s = wait_for(screen.page, lambda s: (rect(s.get('theme', '')) or [0, 0, 0])[2] > screen.width - NOTCH)
    s = screen.resize(screen.height, screen.width)
    s = wait_for(screen.page, lambda s: s.get('class') == 'phone')
    screen.expect('turned back: a phone\'s layout again', s.get('class') == 'phone'
                  and s.get('detailshown') == 'false', s)


def check_tablet(screen):
    s = wait_for(screen.page, lambda s: rect(s.get('rect', '')) == [0, 0, screen.width, screen.height]
                 and s.get('class') == 'tablet')
    screen.fills(s)
    screen.tablet_layout(s)
    x, y = screen.tile_centre(s, 3)
    screen.tap(x, y)
    s = wait_for(screen.page, lambda s: s.get('place') == 'Lisbon' and s.get('placeshown') == 'true')
    screen.shot('1-tablet')
    screen.expect('tablet: a tap on a place shows it in the pane',
                  s.get('place') == 'Lisbon' and s.get('placeshown') == 'true'
                  and s.get('detailshown') == 'true', s)
    # turned: 1024 wide, a desktop's layout
    s = screen.resize(screen.height, screen.width)
    s = wait_for(screen.page, lambda s: s.get('class') == 'desktop')
    screen.shot('2-tablet-landscape')
    screen.fills(s)
    screen.desktop_layout(s)


def check_desktop(screen, dark=False):
    page = screen.page
    s = wait_for(page, lambda s: rect(s.get('rect', '')) == [0, 0, screen.width, screen.height]
                 and s.get('class') == 'desktop')
    screen.fills(s)
    if dark:
        screen.shot('1-desktop-dark')
        screen.expect('in the dark: the stack is dark', s.get('look', '').upper() == '#0F1220', s)
        return
    screen.desktop_layout(s)
    screen.expect('desktop: the badge says mouse', s.get('badge', '').endswith('mouse'), s)
    screen.expect('in the light: the stack is light', s.get('look', '').upper() == '#F4F5FB', s)
    # hovering lights a place up
    before = s.get('tile1back', '').split(';')[0]
    x, y = screen.tile_centre(s, 1)
    page.mouse.move(x, y)
    s = wait_for(page, lambda s: s.get('tile1back', '').split(';')[0] != before)
    screen.expect('desktop: hovering lights a place up', s.get('tile1back', '').split(';')[0] != before, s)
    page.mouse.click(x, y)
    s = wait_for(page, lambda s: s.get('place') == 'Kyoto')
    screen.shot('1-desktop')
    screen.expect('desktop: a click shows the place in the pane', s.get('place') == 'Kyoto', s)
    # two places saved, one after the other (the second was once joined
    # to the first, as a place "13" that is not there)
    for number, name in ((1, 'Kyoto'), (3, 'Lisbon')):
        if number != 1:
            page.mouse.click(*screen.tile_centre(s, number))
            s = wait_for(page, lambda s: s.get('place') == name)
        save = rect(s.get('save', '').split(';')[-1])
        if save:
            page.mouse.click(*centre(save))
            s = wait_for(page, lambda s: s.get('save', '').startswith('Saved;'))
        screen.expect('desktop: %s is saved' % name, s.get('save', '').startswith('Saved;'), s)
    # the keys: 2 goes to Saved, / to the search
    page.mouse.move(screen.width - 10, screen.height - 10)
    page.keyboard.press('2')
    s = screen.on_card('Saved')
    screen.expect('desktop: the key 2 goes to Saved', s.get('card') == 'Saved', s)
    screen.expect('desktop: the Saved tab has both places', list(tiles(s.get('saved'))) == [1, 3], s)
    page.keyboard.press('1')
    s = screen.on_card('Explore')
    page.keyboard.press('/')
    page.keyboard.type('lis')
    s = wait_for(page, lambda s: list(tiles(s.get('tiles'))) == [3])
    screen.expect('desktop: the key / goes to the search', s.get('searchtext') == 'lis', s)
    screen.shot('2-desktop-search')
    found = tiles(s.get('tiles'))
    grid = rect(s.get('grid', ''))
    screen.expect('desktop: the search leaves Lisbon, first in the grid',
                  list(found) == [3] and grid and found[3][1] < grid[1] + 40, s)
    for _ in range(3):
        page.keyboard.press('Backspace')
    s = wait_for(page, lambda s: len(tiles(s.get('tiles'))) == 8)
    screen.expect('desktop: an empty search shows every place', len(tiles(s.get('tiles'))) == 8, s)
    # the guide, live
    page.mouse.click(SIDEBAR / 2, centre(rect(s.get('navguide', '').split(';')[0]))[1])
    s = screen.on_card('Guide')
    screen.shot('3-desktop-guide')
    screen.expect('desktop: the guide shows the rules followed now',
                  'Layout: desktop' in s.get('live', '') and 'Nav: left 0, top 0, bottom 0, width 232' in s.get('live', ''), s)
    screen.expect('desktop: in a browser, no buttons to resize the window', s.get('try') == 'false', s)
    screen.expect('desktop: the sidebar keeps its name on every card', s.get('brandtext') == 'Places', s)
    # a narrow window is a phone's layout at once, and back
    s = screen.resize(500, 800)
    s = wait_for(page, lambda s: s.get('class') == 'phone')
    screen.shot('4-desktop-narrow')
    screen.phone_layout(s)
    screen.expect('narrow: the guide says so', 'Layout: phone' in s.get('live', ''), s)
    s = screen.resize(1280, 720)
    s = wait_for(page, lambda s: s.get('class') == 'desktop')
    screen.desktop_layout(s)


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    ap.add_argument('--runtime', required=True, help='the web runtime folder')
    ap.add_argument('--engine', help='a development engine (LiveCode-Community)')
    ap.add_argument('--engine-cache', help='download the pinned development engine into this folder')
    ap.add_argument('--browser', choices=('chromium', 'webkit'), default='chromium')
    ap.add_argument('--device', action='append', help='a Playwright device profile (default: %s)' % DEFAULT_DEVICES)
    ap.add_argument('--rebuild', action='store_true', help='build the Responsive Starter now instead of the committed one')
    ap.add_argument('--work', help='the work folder (default: a temporary folder)')
    ap.add_argument('--timeout', type=int, default=120, help='seconds for each step (default 120)')
    ap.add_argument('--shots', help='a folder for screenshots of each layout')
    args = ap.parse_args(argv)
    if not args.engine and not args.engine_cache:
        ap.error('--engine or --engine-cache is needed')
    work = args.work or tempfile.mkdtemp(prefix='responsive-web-check-')
    os.makedirs(work, exist_ok=True)
    if args.shots:
        os.makedirs(args.shots, exist_ok=True)
    try:
        from playwright.sync_api import sync_playwright
    except ImportError:
        log('FAILED: the Python package playwright is missing')
        return 1
    problems = []
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
        web_check.make_standalone(args.runtime, js, wasm, html, data, site, title='Responsive Starter')
        os.replace(os.path.join(site, web_check.STACK_NAME + '.html'), os.path.join(site, PAGE))
        server = web_check.make_server(site)
        url = 'http://127.0.0.1:%d/%s' % (server.server_address[1], PAGE)
        with sync_playwright() as p:
            for i, device in enumerate(args.device or DEFAULT_DEVICES):
                log('%s, %s:' % (args.browser, device))
                screen = Screen(p, args.browser, device, url, args.timeout, args.shots)
                try:
                    if i == 0 and not args.rebuild:
                        screen.script_is_built()
                    if screen.width < 600:
                        check_phone(screen)
                    elif screen.width < 1024:
                        check_tablet(screen)
                    else:
                        check_desktop(screen)
                finally:
                    screen.close()
                problems += screen.problems
                if screen.width >= 1024 and not screen.touch:
                    log('%s, %s, in the dark:' % (args.browser, device))
                    screen = Screen(p, args.browser, device, url, args.timeout, args.shots, dark=True)
                    try:
                        check_desktop(screen, dark=True)
                    finally:
                        screen.close()
                    problems += screen.problems
        server.shutdown()
    except (CheckError, web_check.CheckError, subprocess.TimeoutExpired) as e:
        log('FAILED: %s' % e)
        return 1
    if problems:
        log('RESPONSIVE WEB CHECK FAILED')
        for problem in problems:
            log('  %s' % problem)
        return 1
    log('RESPONSIVE WEB CHECK OK')
    return 0


if __name__ == '__main__':
    sys.exit(main())
