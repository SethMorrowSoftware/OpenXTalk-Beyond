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

"""The front page of the GitHub Pages site (tools/pages/index.html, filled
in by tools/pages/build_pages.py). Whatever parts a run puts on the site,
the page it writes links only to folders that are there, to its own
anchors, to the project on GitHub and to the files its release has (the
Downloads section); it leaves no marker or placeholder
behind; and it asks no other host for anything (no script, style, font or
image from elsewhere). tools/pages/check_front_page.py reads the same page
in a browser.

  python3 -m unittest discover -s tools/ci/tests
"""

import html.parser
import io
import itertools
import os
import re
import shutil
import sys
import tempfile
import unittest
from contextlib import redirect_stdout

CI = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REPO = os.path.dirname(os.path.dirname(CI))
PAGES = os.path.join(REPO, 'tools', 'pages')
sys.path.insert(0, PAGES)

import build_pages  # noqa: E402

FOLDERS = {'GAMES': 'games/', 'IDE': 'ide/', 'DICTIONARY': 'dictionary/', 'PLAYER': 'player/', 'MAP': 'map/'}
# The links the page may make to other hosts
EXTERNAL = {
    'https://github.com/SethMorrowSoftware/OpenXTalk-Beyond',
    'https://github.com/SethMorrowSoftware/OpenXTalk-Beyond/releases',
    'https://github.com/SethMorrowSoftware/OpenXTalk-Beyond/issues/new?template=bug_report.yml',
}
TAG = 'v0.2.7-rc.6.11'
# rc.6.11's files, as gh release view lists them
ASSETS = ['OXT-Beyond-0.2.7-rc.6.11-%s' % s for s in (
    'linux-arm64-binaries.tar.xz', 'linux-arm64-symbols.tar.xz', 'linux-arm64.tar.xz',
    'linux-x86_64-binaries.tar.xz', 'linux-x86_64-symbols.tar.xz', 'linux-x86_64.tar.xz',
    'mac-universal-binaries.tar.xz', 'mac-universal-symbols.zip', 'mac-universal.dmg', 'mac-universal.zip',
    'mcp-bridge-plugin.lce', 'web-ide.zip', 'web-player.zip', 'win-x86_64-binaries.zip',
    'win-x86_64-portable.zip', 'win-x86_64-setup.exe', 'win-x86_64-symbols.zip',
    'xtalk-assistant-plugin.lce', 'xtalk-sources.zip')] + ['SHA256SUMS']
RELEASE = 'https://github.com/SethMorrowSoftware/OpenXTalk-Beyond/releases/'
# Elements that void HTML does not close
VOID = {'meta', 'link', 'br', 'img', 'input', 'hr', 'source', 'path', 'circle', 'rect'}


class Page(html.parser.HTMLParser):
    """The page's links, ids and loaded resources, and its tags balanced."""

    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.links, self.ids, self.loads, self.stack, self.errors = [], set(), [], [], []

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if 'id' in attrs:
            if attrs['id'] in self.ids:
                self.errors.append('id %r twice' % attrs['id'])
            self.ids.add(attrs['id'])
        if tag == 'a':
            self.links.append(attrs.get('href'))
        elif tag in ('script', 'img', 'iframe', 'source', 'video', 'audio') and attrs.get('src'):
            self.loads.append(attrs['src'])
        elif tag == 'link' and attrs.get('rel') != 'icon':
            self.loads.append(attrs.get('href'))
        if tag not in VOID:
            self.stack.append(tag)

    def handle_startendtag(self, tag, attrs):
        self.handle_starttag(tag, attrs)
        if tag not in VOID:
            self.stack.pop()

    def handle_endtag(self, tag):
        if tag in VOID:
            return
        if not self.stack or self.stack[-1] != tag:
            self.errors.append('</%s> closes <%s>' % (tag, self.stack[-1] if self.stack else 'nothing'))
            return
        self.stack.pop()


def parse(text):
    page = Page()
    page.feed(text)
    page.close()
    if page.stack:
        page.errors.append('left open: %s' % ', '.join(page.stack))
    return page


class TheTemplate(unittest.TestCase):

    def setUp(self):
        with open(os.path.join(PAGES, 'index.html'), encoding='utf-8') as f:
            self.text = f.read()

    def test_markers_pair_up(self):
        for key in build_pages.PARTS:
            starts = [m.start() for m in re.finditer(re.escape('<!-- @%s@ -->' % key), self.text)]
            ends = [m.start() for m in re.finditer(re.escape('<!-- /@%s@ -->' % key), self.text)]
            self.assertTrue(starts, key)
            self.assertEqual(len(starts), len(ends), key)
            for s, e in zip(starts, ends):
                self.assertLess(s, e, key)
            # (no block inside another block of the same part)
            for s, e in zip(starts[1:], ends):
                self.assertGreater(s, e, key)

    def test_each_folder_is_linked_only_inside_its_part(self):
        # Removing a part must remove every link to its folder
        for key, folder in FOLDERS.items():
            outside = self.text
            start, end = '<!-- @%s@ -->' % key, '<!-- /@%s@ -->' % key
            while start in outside:
                at = outside.index(start)
                outside = outside[:at] + outside[outside.index(end, at) + len(end):]
            self.assertNotIn('href="%s"' % folder, outside, key)

    def test_nothing_from_another_host(self):
        # The one thing the page loads is its own logo, from brand/ beside it
        page = parse(self.text)
        self.assertEqual(sorted(set(page.loads)), ['brand/icon.svg', 'brand/logo-animated.svg'])
        for name in page.loads:
            self.assertIn(name[len('brand/'):], build_pages.BRAND)
        self.assertNotRegex(self.text, r'url\(\s*["\']?(https?:)?//')
        self.assertNotRegex(self.text, r'@import')


    def test_the_logo(self):
        # The moving logo in the hero, the still one for less motion, the
        # small one as the favicon, and the banner for link previews: each
        # a file the site has
        self.assertIn('<source srcset="brand/logo.svg" media="(prefers-reduced-motion: reduce)">', self.text)
        self.assertIn('<img src="brand/logo-animated.svg"', self.text)
        self.assertIn('<link rel="icon" type="image/svg+xml" href="brand/icon.svg">', self.text)
        # It lies over the stack window's corner, so clicks go through it
        # to the stack (its answer's OK button is under it on a narrow page)
        css = re.search(r'\.hero-logo \{([^}]*)\}', self.text).group(1)
        self.assertIn('pointer-events: none', css)
        preview = re.search(r'<meta property="og:image" content="([^"]+)">', self.text).group(1)
        self.assertEqual(preview, 'https://sethmorrowsoftware.github.io/OpenXTalk-Beyond/brand/social.png')
        for name in build_pages.BRAND:
            self.assertTrue(os.path.isfile(os.path.join(PAGES, 'brand', name)), name)

    def test_the_web_stacks(self):
        # "Web Games" became "Web Stacks" (SVG Lab is no game); the folder
        # stays games/, so every link to it keeps working
        self.assertIn('<h3>Web Stacks</h3>', self.text)
        self.assertNotIn('Web Games', self.text)
        self.assertIn('href="games/"', self.text)
        with open(os.path.join(PAGES, 'games', 'index.html'), encoding='utf-8') as f:
            games = f.read()
        self.assertIn('<title>Web stacks · OXT-Beyond</title>', games)
        self.assertNotIn('Web games', games)
        self.assertIn('href="pixel-maker/"', games)
        self.assertIn('href="svg-lab/"', games)


class TheBuiltPage(unittest.TestCase):

    def setUp(self):
        self.work = tempfile.mkdtemp(prefix='test-pages-front-')

    def tearDown(self):
        shutil.rmtree(self.work, ignore_errors=True)

    def build(self, parts, assets=ASSETS):
        out = os.path.join(self.work, '-'.join(sorted(parts)) or 'none')
        os.makedirs(out)
        for key in parts:
            if key in FOLDERS:
                os.makedirs(os.path.join(out, FOLDERS[key]))
        if 'DOWNLOADS' in parts:
            parts = dict(parts, DOWNLOADS=TAG, DOWNLOADS_LIST=build_pages.downloads_html(TAG, set(assets)))
        build_pages.front_page(out, parts)
        with open(os.path.join(out, 'index.html'), encoding='utf-8') as f:
            return out, f.read()

    def check(self, parts, assets=ASSETS):
        out, text = self.build(parts, assets)
        where = 'parts %s' % sorted(parts)
        self.assertNotIn('<!-- @', text, where)
        self.assertNotIn('<!-- /@', text, where)
        self.assertNotRegex(text, r'@[A-Z]+(_VERSION)?@', where)
        page = parse(text)
        self.assertEqual(page.errors, [], where)
        for href in page.links:
            self.assertTrue(href, where)
            if href.startswith('#'):
                self.assertIn(href[1:], page.ids, '%s: %s' % (where, href))
            elif href.startswith(RELEASE + 'download/'):
                self.assertIn('DOWNLOADS', parts, where)
                tag, name = href[len(RELEASE + 'download/'):].split('/')
                self.assertEqual(tag, TAG, where)
                self.assertIn(name, assets, where)
            elif href.startswith(RELEASE + 'tag/'):
                self.assertEqual(href, RELEASE + 'tag/' + TAG, where)
            elif href.startswith('https://'):
                self.assertIn(href, EXTERNAL, where)
            elif href == './':
                pass
            elif href == '#downloads':
                pass
            else:
                self.assertIn(href, [FOLDERS[k] for k in parts if k in FOLDERS], '%s: %s' % (where, href))
                self.assertTrue(os.path.isdir(os.path.join(out, href)), href)
        for key, folder in FOLDERS.items():
            self.assertEqual(('href="%s"' % folder) in text, key in parts, '%s: %s' % (where, key))
        self.assertEqual('href="#downloads"' in text, 'DOWNLOADS' in parts, where)
        self.assertEqual('id="downloads"' in text, 'DOWNLOADS' in parts, where)
        return text

    def test_games_go_up_with_the_players_engine(self):
        source = os.path.join(self.work, 'games-source', 'one')
        os.makedirs(source)
        with open(os.path.join(source, 'index.html'), 'w', encoding='utf-8') as f:
            f.write('<script src="../../player/@ENGINE_JS@"></script>')
        player = os.path.join(self.work, 'games-player')
        os.makedirs(player)
        target = os.path.join(self.work, 'games-out')
        self.assertFalse(build_pages.games(os.path.dirname(source), target, player))
        self.assertFalse(os.path.exists(target))
        open(os.path.join(player, 'standalone-community-9.js'), 'w').close()
        self.assertTrue(build_pages.games(os.path.dirname(source), target, player))
        with open(os.path.join(target, 'one', 'index.html'), encoding='utf-8') as f:
            self.assertIn('../../player/standalone-community-9.js', f.read())

    def test_every_set_of_parts(self):
        keys = list(FOLDERS) + ['DOWNLOADS']
        for n in range(len(keys) + 1):
            for combo in itertools.combinations(keys, n):
                self.check({k: '1.%d' % i for i, k in enumerate(combo)})

    def test_the_versions_are_shown_and_escaped(self):
        text = self.check({'IDE': '0.2.7 <b>', 'MAP': 'main @ abc, 2026-10-31'})
        self.assertIn('<p class="version">0.2.7 &lt;b&gt;</p>', text)
        self.assertIn('<p class="version">main @ abc, 2026-10-31</p>', text)

    def test_the_buttons_say_where_they_go(self):
        text = self.check({k: '9' for k in FOLDERS})
        for label, folder in (('Open the Web IDE', 'ide/'), ('Open the Dictionary', 'dictionary/'),
                              ('Open the Stack Player', 'player/'), ('Open the codebase map', 'map/')):
            self.assertIn('<a class="button" href="%s">%s</a>' % (folder, label), text)

    def test_the_downloads(self):
        text = self.check({'IDE': '9', 'DOWNLOADS': TAG})
        for name in ('win-x86_64-setup.exe', 'win-x86_64-portable.zip', 'mac-universal.dmg', 'mac-universal.zip',
                     'linux-x86_64.tar.xz', 'linux-arm64.tar.xz', 'web-ide.zip', 'web-player.zip',
                     'xtalk-assistant-plugin.lce', 'mcp-bridge-plugin.lce'):
            self.assertIn('href="%sdownload/%s/OXT-Beyond-0.2.7-rc.6.11-%s"' % (RELEASE, TAG, name), text)
        # (debug symbols and build output are for the release page)
        self.assertNotIn('symbols', text)
        self.assertIn('href="%stag/%s"' % (RELEASE, TAG), text)
        self.assertIn('<span class="release">%s</span>' % TAG, text)

    def test_only_the_files_the_release_has(self):
        assets = [a for a in ASSETS if 'mac-' not in a and not a.endswith('-portable.zip')]
        text = self.check({'DOWNLOADS': TAG}, assets)
        self.assertNotIn('<h3>macOS</h3>', text)
        self.assertNotIn('portable', text)
        self.assertIn('<h3>Windows</h3>', text)

    def test_a_release_with_none_of_them(self):
        self.assertEqual(build_pages.downloads_html(TAG, {'SHA256SUMS'}), '')
        self.assertEqual(build_pages.downloads_html('v1.0', set(ASSETS)), '')

    def test_a_tag_that_is_not_one(self):
        for tag in ('0.2.7', 'v0.2.7"><script>', 'run 123 (not released)', ''):
            with self.assertRaises(build_pages.BuildError):
                build_pages.downloads_html(tag, set(ASSETS))

    def test_a_part_with_more_than_one_block(self):
        # every block of a missing part goes, not just the first
        page = os.path.join(self.work, 'tpl')
        os.makedirs(page)
        tpl = ''.join('<!-- @%s@ -->%s<!-- /@%s@ -->' % (k, k.lower(), k) * 2 for k in build_pages.PARTS)
        here = build_pages.HERE
        try:
            build_pages.HERE = page
            with open(os.path.join(page, 'index.html'), 'w', encoding='utf-8') as f:
                f.write(tpl)
            out = os.path.join(self.work, 'out')
            os.makedirs(out)
            build_pages.front_page(out, {'PLAYER': '1'})
            with open(os.path.join(out, 'index.html'), encoding='utf-8') as f:
                self.assertEqual(f.read(), 'playerplayer')
            with open(os.path.join(page, 'index.html'), 'w', encoding='utf-8') as f:
                f.write(tpl + '<!-- @IDE@ -->dangling')
            with self.assertRaisesRegex(build_pages.BuildError, 'no <!-- /@IDE@ -->'):
                build_pages.front_page(out, {'PLAYER': '1'})
        finally:
            build_pages.HERE = here

    def test_the_whole_build(self):
        # through build(), as pages.yml runs it, with a Stack Player zip
        import zipfile
        player = os.path.join(self.work, 'OXT-Beyond-9.9.9-web-player.zip')
        with zipfile.ZipFile(player, 'w') as z:
            z.writestr('StackPlayer/index.html', '<!DOCTYPE html><title>Player</title>')
        out = os.path.join(self.work, 'site')
        args = build_pages.argparse.Namespace(out=out, ide=None, ide_version=None, player=player,
                                              player_version='9.9.9', map=None, map_version=None)
        with redirect_stdout(io.StringIO()):
            build_pages.build(args)
        with open(os.path.join(out, 'index.html'), encoding='utf-8') as f:
            text = f.read()
        self.assertIn('href="player/"', text)
        self.assertNotIn('href="ide/"', text)
        # the logo goes up beside the page, as the brand folder has it
        for name in build_pages.BRAND:
            with open(os.path.join(out, 'brand', name), 'rb') as f, \
                    open(os.path.join(PAGES, 'brand', name), 'rb') as g:
                self.assertEqual(f.read(), g.read(), name)
        self.assertNotIn('Launch the Web IDE', text)
        self.assertNotIn('id="downloads"', text)

        # and with a release, as pages.yml gives it
        listing = os.path.join(self.work, 'assets.txt')
        with open(listing, 'w', encoding='utf-8') as f:
            f.write('\n'.join(ASSETS) + '\n')
        shutil.rmtree(out)
        args.release, args.release_assets = TAG, listing
        with redirect_stdout(io.StringIO()):
            build_pages.build(args)
        with open(os.path.join(out, 'index.html'), encoding='utf-8') as f:
            text = f.read()
        self.assertIn('id="downloads"', text)
        self.assertIn('OXT-Beyond-0.2.7-rc.6.11-win-x86_64-setup.exe', text)
        shutil.rmtree(out)
        args.release_assets = None
        with self.assertRaisesRegex(build_pages.BuildError, 'release-assets'):
            build_pages.build(args)


if __name__ == '__main__':
    unittest.main()
