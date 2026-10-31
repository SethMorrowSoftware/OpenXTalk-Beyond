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

"""Check in a browser the Dictionary that tools/pages/build_dictionary.py
made, as a reader of the GitHub Pages site meets it (Help > Dictionary
Online in the IDE opens it):

  python3 tools/pages/check_dictionary.py --site DIR [--out DIR]
      [--browser chromium|firefox|webkit] [--timeout S]

It serves DIR (the Dictionary's folder) over HTTP, opens its page and
checks that:
  - the page is titled "OXT-Beyond Dictionary" and nothing calls it
    LiveCode's: its title, its API menu and the APIs' names;
  - the API menu offers xTalk Script and xTalk Builder, and each lists as
    many entries as built_api.js has for it;
  - a search for "answer" lists the answer entries, and the first one
    opens with its syntax;
  - the page asks for no file it does not have and throws no error.

Screenshots go to --out (dictionary-script.png, dictionary-builder.png).
Exit status 0 when every check passes, 1 when one fails, 2 when the check
cannot run. It needs Playwright (pip install playwright, then playwright
install chromium).
"""

import argparse
import functools
import http.server
import os
import sys
import threading

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import build_dictionary  # noqa: E402

SEARCH = 'answer'


class Quiet(http.server.SimpleHTTPRequestHandler):
    def log_message(self, *args):
        pass


def serve(folder):
    server = http.server.ThreadingHTTPServer(('127.0.0.1', 0), functools.partial(Quiet, directory=folder))
    threading.Thread(target=server.serve_forever, daemon=True).start()
    return server


def expected_counts(site):
    with open(os.path.join(site, 'built_api.js'), encoding='utf-8') as f:
        return build_dictionary.check_data(f.read())


def run(site, out, browser_name, timeout):
    """The checks' results: a list of (name, passed, detail)."""
    from playwright.sync_api import sync_playwright, Error as PlaywrightError

    counts = expected_counts(site)
    results = []

    def check(name, ok, detail=''):
        results.append((name, bool(ok), detail))
        print('%s  %s%s' % ('PASS' if ok else 'FAIL', name, (': ' + detail) if detail else ''))

    server = serve(site)
    url = 'http://127.0.0.1:%d/index.html' % server.server_address[1]
    problems = []
    try:
        with sync_playwright() as p:
            browser = getattr(p, browser_name).launch()
            page = browser.new_page(viewport={'width': 1280, 'height': 800})
            page.set_default_timeout(timeout * 1000)
            page.on('pageerror', lambda e: problems.append('error: %s' % e))
            page.on('console', lambda m: problems.append('console %s: %s' % (m.type, m.text))
                    if m.type == 'error' else None)
            page.on('response', lambda r: problems.append('HTTP %d for %s' % (r.status, r.url))
                    if r.status >= 400 else None)
            page.on('requestfailed', lambda r: problems.append('no answer for %s' % r.url))
            try:
                page.goto(url)
                page.wait_for_function("() => document.querySelectorAll('#table_list tr').length > 0")
                title = page.title()
                check('the title', title.startswith(build_dictionary.TITLE), title)
                chooser = page.inner_text('#lcdoc_library_chooser_text').strip()
                menu = [a.strip() for a in page.locator('#lcdoc_library_chooser_list a').all_inner_texts()]
                check('the API menu', menu == [t for t, _ in build_dictionary.APIS] and chooser == 'xTalk Script',
                      'shows %r, offers %r' % (chooser, menu))
                said = ' '.join([title, chooser] + menu)
                check('nothing calls it LiveCode\'s', 'livecode' not in said.lower(), said)
                rows = page.locator('#table_list tr').count()
                check('xTalk Script lists its entries', rows == counts['xTalk Script'],
                      '%d rows, %d entries' % (rows, counts['xTalk Script']))
                if out:
                    page.screenshot(path=os.path.join(out, 'dictionary-script.png'))

                # (the list follows the box as a key is let go)
                page.fill('#ui_filer', SEARCH)
                page.press('#ui_filer', 'Enter')
                page.wait_for_function("(n) => { const r = document.querySelectorAll('#table_list tr');"
                                       " return r.length > 0 && r.length < n; }", arg=rows)
                names = [t.split('\t')[0].strip() for t in page.locator('#table_list tr').all_inner_texts()]
                check('a search for "%s"' % SEARCH, names and names[0] == SEARCH and
                      all(SEARCH in n.lower() for n in names), ', '.join(names[:8]))
                page.locator('#table_list tr').first.click()
                page.wait_for_function("() => document.querySelector('#api_entry') &&"
                                       " document.querySelector('#api_entry').innerText.indexOf('Syntax') >= 0")
                entry = page.inner_text('#api_entry')
                check('the "%s" entry opens' % SEARCH,
                      entry.strip().split('\n')[0].strip() == SEARCH and 'Syntax' in entry,
                      entry.strip().split('\n')[0][:60])

                page.fill('#ui_filer', '')
                page.press('#ui_filer', 'Enter')
                page.click('#dropdownMenu1')
                page.locator('#lcdoc_library_chooser_list a', has_text='xTalk Builder').click()
                page.wait_for_function("() => document.querySelector('#lcdoc_library_chooser_text')"
                                       ".innerText.trim() == 'xTalk Builder'")
                page.wait_for_function("(n) => document.querySelectorAll('#table_list tr').length == n",
                                       arg=counts['xTalk Builder'])
                check('xTalk Builder lists its entries', True,
                      '%d entries' % counts['xTalk Builder'])
                if out:
                    page.screenshot(path=os.path.join(out, 'dictionary-builder.png'))
            except PlaywrightError as e:
                check('the page answers', False, str(e).split('\n')[0])
            check('no missing file or error', not problems, '; '.join(problems[:6]))
            browser.close()
    finally:
        server.shutdown()
    return results


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    ap.add_argument('--site', required=True, help='the Dictionary\'s folder (build_dictionary.py --out)')
    ap.add_argument('--out', help='where to put the screenshots')
    ap.add_argument('--browser', choices=('chromium', 'firefox', 'webkit'), default='chromium')
    ap.add_argument('--timeout', type=int, default=60, help='seconds for each step (default 60)')
    args = ap.parse_args(argv)
    site = os.path.abspath(args.site)
    if not os.path.isfile(os.path.join(site, 'index.html')):
        print('check_dictionary.py: %s has no index.html' % site)
        return 2
    try:
        import playwright  # noqa: F401
    except ImportError:
        print('check_dictionary.py: Playwright is not installed')
        return 2
    if args.out:
        os.makedirs(args.out, exist_ok=True)
    try:
        results = run(site, args.out, args.browser, args.timeout)
    except build_dictionary.DictionaryError as e:
        print('check_dictionary.py: %s' % e)
        return 1
    failed = [r for r in results if not r[1]]
    print('%d check(s), %d failed' % (len(results), len(failed)))
    return 1 if failed else 0


if __name__ == '__main__':
    sys.exit(main())
