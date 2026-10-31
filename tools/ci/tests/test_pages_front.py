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
anchors and to the project on GitHub; it leaves no marker or placeholder
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

FOLDERS = {'IDE': 'ide/', 'DICTIONARY': 'dictionary/', 'PLAYER': 'player/', 'MAP': 'map/'}
# The links the page may make to other hosts
EXTERNAL = {
    'https://github.com/SethMorrowSoftware/OpenXTalk-Beyond',
    'https://github.com/SethMorrowSoftware/OpenXTalk-Beyond/releases',
}
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
        page = parse(self.text)
        self.assertEqual(page.loads, [])
        self.assertNotRegex(self.text, r'url\(\s*["\']?(https?:)?//')
        self.assertNotRegex(self.text, r'@import')


class TheBuiltPage(unittest.TestCase):

    def setUp(self):
        self.work = tempfile.mkdtemp(prefix='test-pages-front-')

    def tearDown(self):
        shutil.rmtree(self.work, ignore_errors=True)

    def build(self, parts):
        out = os.path.join(self.work, '-'.join(sorted(parts)) or 'none')
        os.makedirs(out)
        for key in parts:
            os.makedirs(os.path.join(out, FOLDERS[key]))
        build_pages.front_page(out, parts)
        with open(os.path.join(out, 'index.html'), encoding='utf-8') as f:
            return out, f.read()

    def check(self, parts):
        out, text = self.build(parts)
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
            elif href.startswith('https://'):
                self.assertIn(href, EXTERNAL, where)
            elif href == './':
                pass
            else:
                self.assertIn(href, [FOLDERS[k] for k in parts], '%s: %s' % (where, href))
                self.assertTrue(os.path.isdir(os.path.join(out, href)), href)
        for key, folder in FOLDERS.items():
            self.assertEqual(('href="%s"' % folder) in text, key in parts, '%s: %s' % (where, key))
        return text

    def test_every_set_of_parts(self):
        keys = list(FOLDERS)
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
        self.assertNotIn('Launch the Web IDE', text)


if __name__ == '__main__':
    unittest.main()
