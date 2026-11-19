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

"""The forum's "Try it in the browser" (seth, 2026-11-19): build_pages.py
puts tools/pages/forum/index.html at <site>/try/ and a boxed copy of the
bare player at <site>/try/box/ (forum_player). What keeps a forum stack in
its box is held here:

  - the frame's sandbox never has allow-same-origin or allow-top-navigation;
  - the box's page goes back to try/ unless it is in such a frame (its
    guard is the first thing in its <head>);
  - the box takes stacks from the forum's stack files alone, and the bare
    player at play/ keeps its own rule (this site's files);
  - the try page builds the frame's address from a number and a file name
    it has checked, and writes nothing of the address into the page as HTML;
  - neither page is listed for search engines, and a bare player that has
    changed so that the box cannot be put on it is refused.

The rules are run under Node (the box's sameSite, the try page's script
against stand-ins), and the guard in Chromium through Node's Playwright
over a local server; those skip without node or its playwright.

  python3 -m unittest discover -s tools/ci/tests
"""

import functools
import http.server
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import threading
import types
import unittest

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
PAGES = os.path.join(REPO, 'tools', 'pages')
PLAYER = os.path.join(REPO, 'tools', 'web-player')
sys.path.insert(0, PAGES)
sys.path.insert(0, PLAYER)

import build_pages  # noqa: E402
import build_player  # noqa: E402

ENGINE = 'standalone-community-9.7.1-BeyondEngine.js'
NODE = shutil.which('node')
FILES = build_pages.FORUM_FILES


def read(path):
    with open(path, encoding='utf-8') as f:
        return f.read()


def node_path():
    root = subprocess.run(['npm', 'root', '-g'], capture_output=True, text=True).stdout.strip() if shutil.which('npm') else ''
    return os.pathsep.join(p for p in (os.environ.get('NODE_PATH', ''), root) if p)


def has_playwright():
    if not NODE:
        return False
    return subprocess.run([NODE, '-e', 'require("playwright")'], capture_output=True,
                          env=dict(os.environ, NODE_PATH=node_path())).returncode == 0


def run_node(script, *args):
    done = subprocess.run([NODE, '-e', script] + list(args), capture_output=True, text=True, timeout=120,
                          env=dict(os.environ, NODE_PATH=node_path()))
    if done.returncode != 0:
        raise AssertionError(done.stderr)
    return json.loads(done.stdout.strip().splitlines()[-1])


class Site(unittest.TestCase):

    @classmethod
    def setUpClass(cls):
        cls.work = tempfile.mkdtemp(prefix='test-forum-player-')
        cls.out = cls.build(cls.work)
        cls.try_page = read(os.path.join(cls.out, 'try', 'index.html'))
        cls.box = read(os.path.join(cls.out, 'try', 'box', 'index.html'))
        cls.bare = read(os.path.join(cls.out, 'play', 'index.html'))

    @classmethod
    def tearDownClass(cls):
        shutil.rmtree(cls.work, ignore_errors=True)

    @staticmethod
    def build(work, change=None):
        site = os.path.join(work, 'StackPlayer')
        os.makedirs(site)
        for name in (ENGINE, ENGINE[:-3] + '.wasm', 'standalone.zip'):
            with open(os.path.join(site, name), 'wb') as f:
                f.write(name.encode())
        build_player.put_page(site)
        if change:
            path = os.path.join(site, 'play', 'index.html')
            text = change(read(path))
            with open(path, 'w', encoding='utf-8') as f:
                f.write(text)
        zip_path = os.path.join(work, 'OXT-Beyond-test-web-player.zip')
        build_player.make_zip(site, zip_path)
        out = os.path.join(work, 'out')
        args = types.SimpleNamespace(out=out, ide=None, ide_version=None, player=zip_path,
                                     player_version='test', map=None, map_version=None)
        build_pages.build(args)
        return out

    # the frame and its box

    def test_the_frame_is_boxed(self):
        frames = re.findall(r'<iframe[^>]*>', self.try_page)
        self.assertEqual(len(frames), 1)
        sandbox = re.search(r'sandbox="([^"]*)"', frames[0]).group(1).split()
        self.assertIn('allow-scripts', sandbox)
        for never in ('allow-same-origin', 'allow-top-navigation', 'allow-top-navigation-by-user-activation',
                      'allow-forms', 'allow-modals'):
            self.assertNotIn(never, sandbox)
        # the frame has no address until the page has checked its own
        self.assertNotIn(' src=', frames[0])
        self.assertNotRegex(self.try_page, r'@[A-Z_]+@')

    def test_the_box_plays_only_in_a_box(self):
        head = self.box[self.box.index('<head>') + len('<head>'):self.box.index('</head>')]
        self.assertTrue(head.lstrip().startswith(build_pages.FORUM_GUARD), head[:200])
        self.assertEqual(self.box.count(build_pages.FORUM_GUARD), 1)
        self.assertIn('<meta name="referrer" content="no-referrer">', head)
        self.assertIn('<meta name="oxt-player-base" content="../../player/">', self.box)

    def test_the_box_takes_the_forums_stacks_alone(self):
        self.assertNotIn(build_pages.SAME_SITE, self.box)
        self.assertEqual(self.box.count(build_pages.FORUM_ONLY), 1)
        at = self.box.index('function fetchStack')
        self.assertLess(self.box.index('sameSite(path)', at), self.box.index('fetch(url.href)', at))

    def test_the_bare_player_is_as_it_was(self):
        self.assertEqual(self.bare.count(build_pages.SAME_SITE), 1)
        self.assertNotIn(build_pages.FORUM_GUARD, self.bare)
        self.assertNotIn(FILES, self.bare)
        self.assertIn('<meta name="oxt-player-base" content="../player/">', self.bare)

    def test_not_for_search_engines(self):
        for page in (self.try_page, self.box):
            self.assertIn('<meta name="robots" content="noindex">', page[:page.index('</head>')])
        sitemap = read(os.path.join(self.out, 'sitemap.xml'))
        self.assertNotIn('/try/', sitemap)
        self.assertNotIn('rel="canonical"', self.box)

    def test_a_changed_bare_player_is_refused(self):
        for change in (lambda t: t.replace(build_pages.SAME_SITE, 'if (!url) return null;'),
                       lambda t: t.replace('<head>', '<head><head>'),
                       lambda t: t.replace(build_pages.BARE_BASE, '')):
            work = tempfile.mkdtemp(prefix='test-forum-player-changed-')
            try:
                with self.assertRaises(build_pages.BuildError):
                    self.build(work, change)
            finally:
                shutil.rmtree(work, ignore_errors=True)

    # the rules, run

    @unittest.skipUnless(NODE, 'needs node')
    def test_which_stacks_the_box_takes(self):
        text = self.box[self.box.index('function sameSite'):]
        text = text[:text.index('\n  }\n') + 4]
        script = (text + '''
var location = {href: 'https://sethmorrowsoftware.github.io/OpenXTalk-Beyond/try/box/index.html?stack=x',
                origin: 'https://sethmorrowsoftware.github.io'};
console.log(JSON.stringify(JSON.parse(process.argv[1]).map(function (u) { return !!sameSite(u); })));
''')
        cases = [
            (FILES + '123/demo.livecode', True),
            (FILES + '123/My%20Stack.oxtstack', True),
            ('https://openxtalk.org/forum/download/file.php?id=123', False),
            (FILES + '123/demo.livecode?x=1', False),
            (FILES + '123/demo.livecode#x', False),
            (FILES + '../../../ucp.php', False),
            (FILES + '%2e%2e/%2e%2e/ucp.php', False),
            ('http://openxtalk.org/forum/app.php/oxtstack/file/123/demo.livecode', False),
            ('https://openxtalk.org.evil.example/forum/app.php/oxtstack/file/1/a.livecode', False),
            ('https://user@openxtalk.org/forum/app.php/oxtstack/file/1/a.livecode', False),
            ('../../player/samples/beat.livecode', False),
            ('/OpenXTalk-Beyond/player/samples/beat.livecode', False),
            ('javascript:alert(1)', False),
            ('data:text/plain,x', False),
        ]
        got = run_node(script, json.dumps([u for u, _ in cases]))
        for (url, want), took in zip(cases, got):
            self.assertEqual(took, want, url)

    @unittest.skipUnless(NODE, 'needs node')
    def test_what_the_try_page_makes_of_its_address(self):
        text = self.try_page[self.try_page.index('<script>') + len('<script>'):self.try_page.index('</script>')]
        script = r'''
var page = %s;
var out = [];
JSON.parse(process.argv[1]).forEach(function (search) {
  var els = {};
  ['back', 'name', 'full', 'note', 'stack', 'refused'].forEach(function (id) {
    els[id] = {id: id, hidden: id == 'stack' || id == 'refused', textContent: '', href: 'https://openxtalk.org/forum/',
               title: '', src: '', addEventListener: function () {}, requestFullscreen: function () {}};
  });
  var document = {getElementById: function (id) { return els[id]; }, title: ''};
  var location = {search: search};
  new Function('document', 'location', 'URLSearchParams', page)(document, location, URLSearchParams);
  out.push({src: els.stack.src, shown: !els.stack.hidden, refused: !els.refused.hidden,
            name: els.name.textContent, back: els.back.href});
});
console.log(JSON.stringify(out));
''' % json.dumps(text)
        cases = ['?id=42&name=demo.livecode&t=2300', '?id=42&name=My%20Game.oxtstack',
                 '?id=42&name=a%2Fb.livecode', '?id=x42&name=demo.livecode', '?id=42&name=demo.exe',
                 '?id=42&name=%3Cimg%20src%3Dx%3E.livecode', '', '?id=42&name=demo.livecode&t=2300%27',
                 '?id=1234567890&name=demo.livecode']
        ok, spaced, slash, badid, exe, angled, empty, badtopic, longid = run_node(script, json.dumps(cases))
        self.assertTrue(ok['shown'])
        self.assertFalse(ok['refused'])
        self.assertEqual(ok['src'], 'box/index.html?stack=' + _quote(FILES + '42/demo.livecode'))
        self.assertEqual(ok['back'], 'https://openxtalk.org/forum/viewtopic.php?t=2300')
        self.assertEqual(spaced['src'], 'box/index.html?stack=' + _quote(FILES + '42/My%20Game.oxtstack'))
        self.assertEqual(spaced['name'], 'My Game.oxtstack')
        for refused in (slash, badid, exe, empty, longid):
            self.assertTrue(refused['refused'])
            self.assertFalse(refused['shown'])
            self.assertEqual(refused['src'], '')
        # a name with markup in it is only ever text
        self.assertEqual(angled['name'], '<img src=x>.livecode')
        self.assertNotIn('innerHTML', text)
        self.assertNotIn('document.write', text)
        self.assertEqual(badtopic['back'], 'https://openxtalk.org/forum/')

    @unittest.skipUnless(has_playwright(), 'needs node and its playwright')
    def test_the_guard_in_a_browser(self):
        handler = functools.partial(_Quiet, directory=self.out)
        server = http.server.ThreadingHTTPServer(('127.0.0.1', 0), handler)
        threading.Thread(target=server.serve_forever, daemon=True).start()
        base = 'http://127.0.0.1:%d/' % server.server_address[1]
        try:
            got = run_node(r'''
const { chromium } = require('playwright');
(async () => {
  const base = process.argv[1];
  const browser = await chromium.launch();
  const page = await browser.newPage();
  await page.route('https://openxtalk.org/**', r => r.fulfill({status: 404, body: ''}));
  const out = {};
  // the box on its own: back to try/
  await page.goto(base + 'try/box/index.html?stack=' + encodeURIComponent(process.argv[2]));
  await page.waitForURL(u => !String(u).includes('/box/'), {timeout: 10000});
  out.alone = page.url();
  // in a frame that is not boxed: back to try/ in the frame
  await page.setContent('<iframe src="' + base + 'try/box/index.html"></iframe>');
  await page.waitForFunction(() => true);
  await page.waitForTimeout(800);
  out.unboxed = page.frames()[1].url();
  // in the try page's frame: it stays, and it is a stranger
  await page.goto(base + 'try/?id=42&name=demo.livecode');
  await page.waitForTimeout(800);
  const box = page.frames()[1];
  out.boxed = box.url();
  out.origin = await box.evaluate(() => self.origin);
  out.storage = await box.evaluate(() => { try { localStorage.length; return 'readable'; } catch (e) { return 'refused'; } });
  out.cookie = await box.evaluate(() => { try { return document.cookie; } catch (e) { return 'refused'; } });
  await browser.close();
  console.log(JSON.stringify(out));
})().catch(e => { console.error(e); process.exit(1); });
''', base, FILES + '1/a.livecode')
        finally:
            server.shutdown()
        self.assertEqual(got['alone'], base + 'try/')
        self.assertEqual(got['unboxed'], base + 'try/')
        self.assertTrue(got['boxed'].startswith(base + 'try/box/index.html?stack='), got['boxed'])
        self.assertEqual(got['origin'], 'null')
        self.assertEqual(got['storage'], 'refused')
        self.assertEqual(got['cookie'], 'refused')


class _Quiet(http.server.SimpleHTTPRequestHandler):
    def log_message(self, *args):
        pass


def _quote(text):
    # encodeURIComponent
    import urllib.parse
    return urllib.parse.quote(text, safe="-_.!~*'()")


if __name__ == '__main__':
    unittest.main()
