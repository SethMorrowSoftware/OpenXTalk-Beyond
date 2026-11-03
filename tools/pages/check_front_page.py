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
"""Check in a browser the front page that tools/pages/build_pages.py made,
as a visitor to the GitHub Pages site meets it:

  python3 tools/pages/check_front_page.py --site DIR [--out DIR]
      [--browser chromium|firefox|webkit] [--timeout S]

It serves DIR (the whole site) over HTTP and opens its front page wide
and narrow (1280 and 390 pixels), in light and in dark, and checks that:
  - the page asks no other host for anything, and asks for no file the
    site lacks, and throws no error;
  - nothing is wider than the window (no sideways scrolling on a phone);
  - every link to the site's own folders answers with a page (HTTP 200),
    and every "#" link names an element of the page;
  - the stack in the header answers its button with "Hello from Beyond!";
  - at rest (its opening moves over, nothing pointed at), nothing larger
    than the header's logo is redrawn without end: an endless animation
    (of any property) or a moving SVG picture (SMIL) is no bigger than that
    logo;
  - at rest, at the top of the page and at its Downloads, the browser's
    processes use no more than REST_CPU of a core over REST_SECONDS, and
    their memory grows by no more than REST_GROWTH_MB (read from Linux's
    /proc; elsewhere these two are not measured, and it says so).

Screenshots go to --out (front-wide-light.png, front-wide-dark.png,
front-narrow-light.png, front-narrow-dark.png). Exit status 0 when every
check passes, 1 when one fails, 2 when the check cannot run. It needs
Playwright (pip install playwright, then playwright install chromium).
"""

import argparse
import functools
import http.server
import os
import sys
import threading
import time
import urllib.parse
import urllib.request

SIZES = (('wide', 1280, 800), ('narrow', 390, 844))
SCHEMES = ('light', 'dark')

# What the page keeps redrawing at rest, larger than the header's logo:
# endless animations, and moving SVG pictures (SMIL), where they are drawn.
# The cards' spinning rims and the first card's moving logo kept a browser
# without a GPU busy most of each second while the cards were on screen
# (tperry2x, openxtalk.org p=25971: Firefox's fans on a slow machine). An
# animation of opacity or transform was let through at first, as one the
# compositor moves without drawing; but without a GPU the compositor draws
# too, and the stars' twinkle (opacity, layers as big as the header and the
# Downloads) cost about half a core on its own, and the turning rays
# (transform) a third. Every property counts. The header's logo is the
# yardstick, as the biggest thing small enough to be let through.
RESTLESS = r"""async () => {
  const area = (el, pseudo) => {
    if (pseudo) {
      // a ::before or ::after has no box of its own to ask for: its used size
      const s = getComputedStyle(el, pseudo), w = parseFloat(s.width), h = parseFloat(s.height);
      if (w >= 0 && h >= 0) return [Math.round(w), Math.round(h)];
    }
    const r = el.getBoundingClientRect();
    return [Math.round(r.width), Math.round(r.height)];
  };
  const logo = document.querySelector('.hero-logo');
  if (!logo) return ['no logo in the header to measure by'];
  const [lw, lh] = area(logo), limit = lw * lh, big = [];
  const name = el => el.tagName.toLowerCase() + (el.className && typeof el.className === 'string' ? '.' + el.className.trim().split(/\s+/).join('.') : '');
  for (const a of document.getAnimations()) {
    const e = a.effect;
    if (!e || !e.target || a.playState !== 'running' || e.getComputedTiming().iterations !== Infinity) continue;
    const props = new Set();
    for (const k of e.getKeyframes()) for (const p of Object.keys(k)) props.add(p);
    for (const p of ['offset', 'computedOffset', 'easing', 'composite']) props.delete(p);
    const [w, h] = area(e.target, e.pseudoElement);
    if (w * h > limit)
      big.push((a.animationName || 'an animation') + ' of ' + ([...props].join(', ') || 'a custom property') + ' on ' + name(e.target) +
               (e.pseudoElement || '') + ', ' + w + 'x' + h);
  }
  for (const img of document.images) {
    if (!img.getClientRects().length || logo.contains(img)) continue;
    const [w, h] = area(img);
    if (w * h <= limit) continue;
    let text = '';
    try { text = await (await fetch(img.currentSrc)).text(); } catch (err) { continue; }
    if (/<animate/.test(text))
      big.push('the moving picture ' + img.getAttribute('src') + ', ' + w + 'x' + h);
  }
  return big.map(s => s + ' (the logo: ' + lw + 'x' + lh + ')');
}"""


# At rest: once every animation that ends has ended (the page's opening
# moves, such as the header's logo and the stars' first twinkles, at most
# REST_SETTLE seconds), the browser's processes over REST_SECONDS: the CPU
# they use, as a share of one core, and how much their memory grows (the
# sum of each process's proportional set size, Pss). The page before the
# stars, rays and logo were stilled (main at d94cf96bd, Chromium without a
# GPU on a Linux machine): 168% of a core at the top, 94% at Explore, 161%
# at the Downloads, its memory up 11 to 22 MB in 10 seconds; after: 0.1% to
# 0.8%, and its memory falling as the page's start is cleared away
# (tperry2x, openxtalk.org p=25971: "a noticable CPU and memory drain",
# Firefox's performance monitor on the Downloads)
REST_SETTLE = 20
REST_SECONDS = 10
REST_CPU = 0.10
REST_GROWTH_MB = 8.0
REST_PLACES = (('the top', ''), ('the Downloads', '#downloads'))
SETTLED = r"""() => !document.documentElement.classList.contains('opening') &&
  document.getAnimations().every(a => a.playState !== 'running' ||
    !a.effect || a.effect.getComputedTiming().iterations === Infinity)"""


def descendants(root, proc='/proc'):
    """Every process under root (the browser and its helpers, under the
    Playwright driver this process started)."""
    children = {}
    for name in os.listdir(proc):
        if not name.isdigit():
            continue
        try:
            with open(os.path.join(proc, name, 'stat')) as f:
                stat = f.read()
        except OSError:
            continue
        # (the name in brackets may hold spaces and brackets of its own)
        parent = int(stat[stat.rindex(')') + 2:].split()[1])
        children.setdefault(parent, []).append(int(name))
    found, todo = [], [root]
    while todo:
        for child in children.get(todo.pop(), []):
            found.append(child)
            todo.append(child)
    return found


def usage(pids, proc='/proc', tick=None, page=None):
    """The CPU seconds the processes have used, and their memory in MB (the
    sum of their Pss, or of their resident sets where Pss is not shown).
    tick (the clock's ticks a second) and page (the page size in bytes) are
    the system's own unless given: a test gives them, since Windows has no
    sysconf to ask."""
    if tick is None:
        tick = os.sysconf('SC_CLK_TCK')
    if page is None:
        page = os.sysconf('SC_PAGE_SIZE')
    ticks, kb = 0, 0
    for pid in pids:
        try:
            with open(os.path.join(proc, str(pid), 'stat')) as f:
                stat = f.read()
            fields = stat[stat.rindex(')') + 2:].split()
            ticks += int(fields[11]) + int(fields[12])
            pss = None
            try:
                with open(os.path.join(proc, str(pid), 'smaps_rollup')) as f:
                    for line in f:
                        if line.startswith('Pss:'):
                            pss = int(line.split()[1])
                            break
            except OSError:
                pass
            if pss is None:
                with open(os.path.join(proc, str(pid), 'statm')) as f:
                    pss = int(f.read().split()[1]) * page // 1024
            kb += pss
        except (OSError, ValueError, IndexError):
            # (a process that ended between the two reads)
            continue
    return ticks / tick, kb / 1024.0


def at_rest(before, after, seconds):
    """(the share of a core used, the memory grown in MB) between two
    readings of usage(), taken seconds apart."""
    return (after[0] - before[0]) / seconds, after[1] - before[1]


class Quiet(http.server.SimpleHTTPRequestHandler):
    def log_message(self, *args):
        pass


def serve(folder):
    server = http.server.ThreadingHTTPServer(('127.0.0.1', 0), functools.partial(Quiet, directory=folder))
    threading.Thread(target=server.serve_forever, daemon=True).start()
    return server


def run(site, out, browser_name, timeout):
    """The checks' results: a list of (name, passed, detail)."""
    from playwright.sync_api import sync_playwright, Error as PlaywrightError

    results = []

    def check(name, ok, detail=''):
        results.append((name, bool(ok), detail))
        print('%s  %s%s' % ('PASS' if ok else 'FAIL', name, (': ' + detail) if detail else ''))

    server = serve(site)
    base = 'http://127.0.0.1:%d/' % server.server_address[1]
    # (the proxy of a CI machine must not see the local server)
    opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
    try:
        with sync_playwright() as p:
            browser = getattr(p, browser_name).launch()
            for (size, width, height), scheme in [(s, c) for s in SIZES for c in SCHEMES]:
                where = '%s, %s' % (size, scheme)
                problems = []
                page = browser.new_page(viewport={'width': width, 'height': height}, color_scheme=scheme)
                page.set_default_timeout(timeout * 1000)
                page.on('pageerror', lambda e: problems.append('error: %s' % e))
                page.on('console', lambda m: problems.append('console %s: %s' % (m.type, m.text))
                        if m.type == 'error' else None)
                page.on('response', lambda r: problems.append('HTTP %d for %s' % (r.status, r.url))
                        if r.status >= 400 else None)
                page.on('requestfailed', lambda r: problems.append('no answer for %s' % r.url))
                page.on('request', lambda r: problems.append('asks another host: %s' % r.url)
                        if not r.url.startswith(base) and not r.url.startswith('data:') else None)
                try:
                    page.goto(base, wait_until='networkidle')
                    scroll = page.evaluate('() => [document.documentElement.scrollWidth, window.innerWidth]')
                    check('%s: nothing wider than the window' % where, scroll[0] <= scroll[1],
                          '%d px of content in %d' % tuple(scroll))
                    # before anything is clicked, so nothing is pointed at,
                    # and once the page's opening moves are over
                    page.wait_for_function(SETTLED, timeout=REST_SETTLE * 1000)
                    restless = page.evaluate(RESTLESS)
                    check('%s: at rest nothing big is redrawn without end' % where, not restless,
                          '; '.join(restless))
                    if out:
                        page.screenshot(path=os.path.join(out, 'front-%s-%s.png' % (size, scheme)), full_page=True)
                    if size == 'wide' and scheme == 'light':
                        hrefs = page.evaluate("() => [...document.querySelectorAll('a[href]')]"
                                              ".map(a => a.getAttribute('href'))")
                        local = sorted({h for h in hrefs if not h.startswith(('#', 'https://', 'http://'))})
                        bad = []
                        for href in local:
                            try:
                                with opener.open(urllib.parse.urljoin(base, href), timeout=timeout) as r:
                                    if r.status != 200:
                                        bad.append('%s: HTTP %d' % (href, r.status))
                            except OSError as e:
                                bad.append('%s: %s' % (href, e))
                        check('the links to the site\'s folders answer', local and not bad,
                              '; '.join(bad) or ', '.join(local))
                        anchors = [h for h in hrefs if h.startswith('#')]
                        missing = [h for h in anchors if not page.locator(h).count()]
                        check('every "#" link has its place', not missing, ', '.join(missing or anchors))
                        page.click('#hello')
                        page.wait_for_selector('#answer.shown')
                        said = page.inner_text('#answer-text')
                        check('the stack in the header answers', said == 'Hello from Beyond!', said)
                        page.click('#answer-ok')
                        page.wait_for_selector('#answer:not(.shown)', state='attached')
                except PlaywrightError as e:
                    check('%s: the page answers' % where, False, str(e).split('\n')[0])
                check('%s: no missing file, error or other host' % where, not problems, '; '.join(problems[:6]))
                page.close()
            rest(browser, base, timeout, check)
            browser.close()
    finally:
        server.shutdown()
    return results


def rest(browser, base, timeout, check):
    """The browser's CPU and memory while the page rests, wide and light,
    at each of REST_PLACES, alone in the browser."""
    from playwright.sync_api import Error as PlaywrightError
    if not os.path.isfile('/proc/self/stat'):
        print('NOTE  the CPU and memory at rest are measured on Linux only (from /proc)')
        return
    for place, anchor in REST_PLACES:
        page = browser.new_page(viewport={'width': 1280, 'height': 800}, color_scheme='light')
        page.set_default_timeout(timeout * 1000)
        try:
            page.goto(base + anchor, wait_until='networkidle')
            page.wait_for_function(SETTLED, timeout=REST_SETTLE * 1000)
            start, began = usage(descendants(os.getpid())), time.time()
            page.wait_for_timeout(REST_SECONDS * 1000)
            end = usage(descendants(os.getpid()))
            cpu, grown = at_rest(start, end, time.time() - began)
            check('at rest at %s: the browser uses little of a core' % place, cpu <= REST_CPU,
                  '%.1f%% of a core over %d seconds (at most %d%%)' % (100 * cpu, REST_SECONDS, 100 * REST_CPU))
            check('at rest at %s: the browser\'s memory does not grow' % place, grown <= REST_GROWTH_MB,
                  '%+.1f MB over %d seconds, %.0f MB in all (at most %+.0f MB)'
                  % (grown, REST_SECONDS, end[1], REST_GROWTH_MB))
        except PlaywrightError as e:
            check('at rest at %s: the page settles' % place, False, str(e).split('\n')[0])
        page.close()


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    ap.add_argument('--site', required=True, help='the site\'s folder (build_pages.py --out)')
    ap.add_argument('--out', help='where to put the screenshots')
    ap.add_argument('--browser', choices=('chromium', 'firefox', 'webkit'), default='chromium')
    ap.add_argument('--timeout', type=int, default=60, help='seconds for each step (default 60)')
    args = ap.parse_args(argv)
    site = os.path.abspath(args.site)
    if not os.path.isfile(os.path.join(site, 'index.html')):
        print('check_front_page.py: %s has no index.html' % site)
        return 2
    try:
        import playwright  # noqa: F401
    except ImportError:
        print('check_front_page.py: Playwright is not installed')
        return 2
    if args.out:
        os.makedirs(args.out, exist_ok=True)
    results = run(site, args.out, args.browser, args.timeout)
    failed = [r for r in results if not r[1]]
    print('%d check(s), %d failed' % (len(results), len(failed)))
    return 1 if failed else 0


if __name__ == '__main__':
    sys.exit(main())
