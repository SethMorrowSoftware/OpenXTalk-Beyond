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
"""Check in a browser that the site's other pages rest as its front page
does (tools/pages/check_front_page.py): the web stacks gallery, the
extensions page, the Stack Player's home and the codebase map, those of
them the site has:

  python3 tools/pages/check_site_rest.py --site DIR [--out DIR]
      [--browser chromium|firefox|webkit] [--timeout S]

Each page is opened wide and light, alone in the browser, and once its
opening moves are over (an animation that ends has ended, the header's
logo is still, the map's sparks have landed: at most REST_SETTLE seconds)
it checks that:
  - nothing bigger than BIG_AREA is redrawn without end: no endless
    animation of any property, and no moving SVG picture (SMIL);
  - the page asks for no animation frame (requestAnimationFrame) over
    REST_SECONDS, but for at most REST_FRAMES: the map drew every frame for
    as long as it was open, whether its sparks flowed or not;
  - the browser's processes use no more than REST_CPU of a core over
    REST_SECONDS, and their memory grows by no more than REST_GROWTH_MB
    (from Linux's /proc; elsewhere these are not measured, and it says so);
  - it throws no error.

Measured before this check (rc.6.14's site, Chromium without a GPU, Linux):
the gallery 233% of a core at rest, the Stack Player's home 233% and the
map 56%; the front page, which check_front_page.py already held, 0.2%.

A screenshot of each page at rest goes to --out (rest-<page>.png). Exit
status 0 when every check passes, 1 when one fails, 2 when the check
cannot run. It needs Playwright (pip install playwright, then playwright
install chromium).
"""

import argparse
import os
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

from check_front_page import at_rest, descendants, serve, usage  # noqa: E402

# (name, the page's folder in the site, its file name for the screenshot)
PAGES = (
    ('the web stacks gallery', 'games/', 'gallery'),
    ('the extensions page', 'extensions/', 'extensions'),
    ('the Stack Player', 'player/', 'player'),
    ('the codebase map', 'map/', 'map'),
)

# The map's sparks flow for 12 seconds and land within about 4 more; the
# gallery's logo moves for 6 and the flames flow for 12
REST_SETTLE = 40
REST_SECONDS = 10
REST_CPU = 0.10
REST_GROWTH_MB = 8.0
# A page at rest asks for no frame; a stray one (a layout settling, a font
# arriving) is let through
REST_FRAMES = 2
# Bigger than the biggest logo that moves while pointed at (the gallery's,
# 190 by 190, turned 6 degrees: 209 by 209), smaller than any card or sky
BIG_AREA = 220 * 220

# Counts the frames the page asks for, from its first script on
COUNT_FRAMES = r"""(() => {
  window.__restFrames = 0;
  const ask = window.requestAnimationFrame.bind(window);
  window.requestAnimationFrame = function (f) { window.__restFrames++; return ask(f); };
})();"""

# At rest: no animation that ends is running, the logo's opening is over,
# and no frame has been asked for in the last two seconds
SETTLED = r"""() => {
  const busy = !document.documentElement.classList.contains('opening') &&
    document.getAnimations().every(a => a.playState !== 'running' ||
      !a.effect || a.effect.getComputedTiming().iterations === Infinity);
  const now = performance.now(), n = window.__restFrames;
  if (window.__restLast === undefined || n !== window.__restLast) { window.__restLast = n; window.__restSince = now; }
  return busy && now - window.__restSince >= 2000;
}"""

# Everything redrawn without end that is bigger than BIG_AREA
RESTLESS = r"""async (limit) => {
  const area = (el, pseudo) => {
    if (pseudo) {
      const s = getComputedStyle(el, pseudo), w = parseFloat(s.width), h = parseFloat(s.height);
      if (w >= 0 && h >= 0) return [Math.round(w), Math.round(h)];
    }
    const r = el.getBoundingClientRect();
    return [Math.round(r.width), Math.round(r.height)];
  };
  const name = el => el.tagName.toLowerCase() + (el.className && typeof el.className === 'string' ? '.' + el.className.trim().split(/\s+/).join('.') : '');
  const big = [];
  for (const a of document.getAnimations()) {
    const e = a.effect;
    if (!e || !e.target || a.playState !== 'running' || e.getComputedTiming().iterations !== Infinity) continue;
    const [w, h] = area(e.target, e.pseudoElement);
    if (w * h > limit) big.push((a.animationName || 'an animation') + ' on ' + name(e.target) + (e.pseudoElement || '') + ', ' + w + 'x' + h);
  }
  for (const img of document.images) {
    if (!img.getClientRects().length) continue;
    const [w, h] = area(img);
    if (w * h <= limit) continue;
    let text = '';
    try { text = await (await fetch(img.currentSrc)).text(); } catch (err) { continue; }
    if (/<animate/.test(text)) big.push('the moving picture ' + img.getAttribute('src') + ', ' + w + 'x' + h);
  }
  return big;
}"""


def run(site, out, browser_name, timeout):
    """The checks' results: a list of (name, passed, detail)."""
    from playwright.sync_api import sync_playwright, Error as PlaywrightError

    results = []

    def check(name, ok, detail=''):
        results.append((name, bool(ok), detail))
        print('%s  %s%s' % ('PASS' if ok else 'FAIL', name, (': ' + detail) if detail else ''))

    pages = [p for p in PAGES if os.path.isfile(os.path.join(site, p[1], 'index.html'))]
    for name, folder, _ in PAGES:
        if (name, folder, _) not in pages:
            print('NOTE  the site has no %s (%s)' % (name, folder))
    if not pages:
        check('the site has a page to check', False, ', '.join(p[1] for p in PAGES))
        return results
    measure = os.path.isfile('/proc/self/stat')
    if not measure:
        print('NOTE  the CPU and memory at rest are measured on Linux only (from /proc)')

    server = serve(site)
    base = 'http://127.0.0.1:%d/' % server.server_address[1]
    try:
        with sync_playwright() as p:
            browser = getattr(p, browser_name).launch()
            for name, folder, shot in pages:
                errors = []
                page = browser.new_page(viewport={'width': 1280, 'height': 800}, color_scheme='light')
                page.set_default_timeout(timeout * 1000)
                page.add_init_script(COUNT_FRAMES)
                page.on('pageerror', lambda e: errors.append(str(e)))
                try:
                    page.goto(base + folder, wait_until='load')
                    page.wait_for_function(SETTLED, polling=250, timeout=REST_SETTLE * 1000)
                    restless = page.evaluate(RESTLESS, BIG_AREA)
                    check('%s: at rest nothing big is redrawn without end' % name, not restless, '; '.join(restless))
                    frames = page.evaluate('() => window.__restFrames')
                    start, began = usage(descendants(os.getpid())) if measure else None, time.time()
                    page.wait_for_timeout(REST_SECONDS * 1000)
                    end = usage(descendants(os.getpid())) if measure else None
                    frames = page.evaluate('() => window.__restFrames') - frames
                    check('%s: at rest it asks for no frames' % name, frames <= REST_FRAMES,
                          '%d over %d seconds (at most %d)' % (frames, REST_SECONDS, REST_FRAMES))
                    if measure:
                        cpu, grown = at_rest(start, end, time.time() - began)
                        check('%s: at rest the browser uses little of a core' % name, cpu <= REST_CPU,
                              '%.1f%% of a core over %d seconds (at most %d%%)' % (100 * cpu, REST_SECONDS, 100 * REST_CPU))
                        check('%s: at rest the browser\'s memory does not grow' % name, grown <= REST_GROWTH_MB,
                              '%+.1f MB over %d seconds, %.0f MB in all (at most %+.0f MB)'
                              % (grown, REST_SECONDS, end[1], REST_GROWTH_MB))
                    if out:
                        page.screenshot(path=os.path.join(out, 'rest-%s.png' % shot))
                except PlaywrightError as e:
                    check('%s: the page settles' % name, False, str(e).split('\n')[0])
                check('%s: no error' % name, not errors, '; '.join(errors[:4]))
                page.close()
            browser.close()
    finally:
        server.shutdown()
    return results


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    ap.add_argument('--site', required=True, help='the site\'s folder (build_pages.py --out)')
    ap.add_argument('--out', help='where to put the screenshots')
    ap.add_argument('--browser', choices=('chromium', 'firefox', 'webkit'), default='chromium')
    ap.add_argument('--timeout', type=int, default=90, help='seconds for each step (default 90)')
    args = ap.parse_args(argv)
    site = os.path.abspath(args.site)
    if not os.path.isdir(site):
        print('check_site_rest.py: %s is not a folder' % site)
        return 2
    try:
        import playwright  # noqa: F401
    except ImportError:
        print('check_site_rest.py: Playwright is not installed')
        return 2
    if args.out:
        os.makedirs(args.out, exist_ok=True)
    results = run(site, args.out, args.browser, args.timeout)
    failed = [r for r in results if not r[1]]
    print('%d check(s), %d failed' % (len(results), len(failed)))
    return 1 if failed else 0


if __name__ == '__main__':
    sys.exit(main())
