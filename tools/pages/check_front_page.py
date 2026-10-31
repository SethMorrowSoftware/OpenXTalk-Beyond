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
  - the stack in the header answers its button with "Hello from Beyond!".

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
import urllib.parse
import urllib.request

SIZES = (('wide', 1280, 800), ('narrow', 390, 844))
SCHEMES = ('light', 'dark')


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
            browser.close()
    finally:
        server.shutdown()
    return results


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
