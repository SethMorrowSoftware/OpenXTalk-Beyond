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

"""The OpenXTalk family bar (tools/pages/family.py): the one strip of links
across the top of this site, the xTalk Suite's extensions page and the
community stacks gallery.

It goes on the pages that are read and on no page that is played or is a
release's own; it links a part of this site only when the site has it,
relatively, and the other sites at their addresses; it asks no host for
anything; a page's skip link stays the first thing Tab reaches; and a
page that has it already is not given a second.

  python3 -m unittest discover -s tools/ci/tests -p test_pages_family.py
"""

import os
import re
import shutil
import sys
import tempfile
import unittest
from html.parser import HTMLParser

CI = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REPO = os.path.dirname(os.path.dirname(CI))
PAGES = os.path.join(REPO, 'tools', 'pages')
sys.path.insert(0, PAGES)

import family  # noqa: E402

PAGE = '<!doctype html><html><head><title>t</title></head><body class="x">\n%s<main>hi</main></body></html>'
SKIP = '<a class="skip" href="#main">Skip to the page</a>'


class Bar(HTMLParser):
    """The bar's links, in order, with which is marked current."""

    def __init__(self):
        super().__init__()
        self.links, self.current, self.depth, self.home = [], None, 0, None
        self.srcs = []

    def handle_starttag(self, tag, attrs):
        a = dict(attrs)
        if 'src' in a:
            self.srcs.append(a['src'])
        if tag == 'nav' and a.get('class') == 'oxt-family':
            self.depth = 1
        elif self.depth and tag == 'a':
            if a.get('class') == 'oxt-family-home':
                self.home = a['href']
            else:
                self.links.append(a['href'])
                if a.get('aria-current') == 'page':
                    self.current = a['href']

    def handle_endtag(self, tag):
        if tag == 'nav':
            self.depth = 0


def bar_of(text):
    p = Bar()
    p.feed(text)
    return p


class TheBar(unittest.TestCase):

    def test_the_family_is_the_same_six_in_order(self):
        self.assertEqual([k for k, _, _ in family.FAMILY],
                         ['beyond', 'ide', 'lessons', 'extensions', 'stacks', 'forum'])
        for _, _, href in family.FAMILY:
            self.assertTrue(href.startswith('https://'), href)

    def test_another_sites_copy_links_every_site_at_its_address(self):
        text = family.family_bar('stacks')
        p = bar_of(text)
        self.assertEqual(p.links, [href for _, _, href in family.FAMILY])
        self.assertEqual(p.current, family.GALLERY)
        self.assertEqual(p.home, family.OPENXTALK)

    def test_it_asks_no_host_for_anything(self):
        text = family.family_bar('beyond')
        self.assertEqual(bar_of(text).srcs, [])
        self.assertNotRegex(text, r'url\(\s*["\']?(https?:)?//')
        self.assertNotIn('@import', text)

    def test_every_rule_is_the_bars_own(self):
        css = re.sub(r'@media[^{]*\{', '', family.FAMILY_CSS)
        for selector in re.findall(r'([^{}]+)\{', css):
            for one in selector.split(','):
                self.assertTrue(one.strip().startswith('.oxt-family'), one)

    def test_a_focused_skip_link_shows_over_it(self):
        # a page's skip link (position absolute, z-index 10) appears over
        # the top of the page when Tab reaches it: the bar, positioned for
        # its script, must not stack above it
        first = family.FAMILY_CSS[:family.FAMILY_CSS.index('}')]
        self.assertIn('position:relative', first)
        self.assertNotIn('z-index', first)

    def test_a_key_given_none_is_left_out(self):
        p = bar_of(family.family_bar('beyond', {'ide': None}))
        self.assertNotIn(family.BEYOND + 'ide/', p.links)
        self.assertEqual(len(p.links), len(family.FAMILY) - 1)

    def test_words_are_escaped(self):
        self.assertIn('href="a?b=1&amp;c=&quot;"', family.family_bar(None, {'beyond': 'a?b=1&c="'}))


class Insert(unittest.TestCase):

    def test_after_the_skip_link(self):
        page = family.insert(PAGE % SKIP, family.family_bar('beyond'))
        self.assertLess(page.index(SKIP), page.index('class="oxt-family"'))
        self.assertLess(page.index('class="oxt-family"'), page.index('<main>'))

    def test_at_the_top_of_the_body_without_one(self):
        page = family.insert(PAGE % '', family.family_bar('beyond'))
        self.assertRegex(page, r'<body class="x">\n<style>\.oxt-family')

    def test_never_twice(self):
        once = family.insert(PAGE % SKIP, family.family_bar('beyond'))
        self.assertEqual(family.insert(once, family.family_bar('beyond')), once)

    def test_a_page_with_no_body_is_an_error(self):
        with self.assertRaises(ValueError):
            family.insert('<p>no body</p>', family.family_bar())


class Finish(unittest.TestCase):

    def setUp(self):
        self.site = tempfile.mkdtemp(prefix='test-pages-family-')
        self.addCleanup(shutil.rmtree, self.site)

    def page(self, *path, skip=True):
        target = os.path.join(self.site, *path)
        os.makedirs(os.path.dirname(target), exist_ok=True)
        with open(target, 'w', encoding='utf-8') as f:
            f.write(PAGE % (SKIP if skip else ''))
        return target

    def read(self, *path):
        with open(os.path.join(self.site, *path), encoding='utf-8') as f:
            return f.read()

    def test_read_pages_get_it_played_ones_do_not(self):
        given = ['index.html', 'extensions/index.html', 'games/index.html', 'games/2048/index.html',
                 'lessons/index.html', 'lessons/arrays/index.html', 'welcome/index.html', 'welcome/guide.html']
        left = ['ide/index.html', 'player/index.html', 'play/index.html', 'try/index.html', 'try/box/index.html',
                'map/index.html', 'dictionary/index.html', 'games/nova-rescue/index.html',
                'games/wobble-forts/index.html', 'games/puzzle-almanac/index.html', 'games/pixel-maker/index.html']
        for p in given + left:
            self.page(*p.split('/'))
        done = family.finish(self.site)
        self.assertEqual(sorted(os.path.relpath(p, self.site).replace(os.sep, '/') for p in done), sorted(given))
        for p in given:
            self.assertEqual(self.read(*p.split('/')).count('class="oxt-family"'), 1, p)
        for p in left:
            self.assertNotIn('oxt-family', self.read(*p.split('/')), p)
        # a second run changes nothing
        before = {p: self.read(*p.split('/')) for p in given}
        family.finish(self.site)
        self.assertEqual({p: self.read(*p.split('/')) for p in given}, before)

    def test_own_parts_are_relative_and_only_when_there(self):
        self.page('index.html')
        self.page('lessons', 'arrays', 'index.html')
        self.page('extensions', 'index.html')
        family.finish(self.site)
        front = bar_of(self.read('index.html'))
        self.assertEqual(front.links, ['./', 'lessons/', 'extensions/', family.GALLERY, family.FORUM])
        self.assertEqual(front.current, './')
        lesson = bar_of(self.read('lessons', 'arrays', 'index.html'))
        self.assertEqual(lesson.links, ['../../', '../../lessons/', '../../extensions/', family.GALLERY,
                                        family.FORUM])
        self.assertEqual(lesson.current, '../../lessons/')
        self.assertEqual(bar_of(self.read('extensions', 'index.html')).current, '../extensions/')

    def test_the_web_ide_when_the_site_has_it(self):
        self.page('index.html')
        os.makedirs(os.path.join(self.site, 'ide'))
        family.finish(self.site)
        self.assertIn('ide/', bar_of(self.read('index.html')).links)


class TheBuiltSite(unittest.TestCase):
    """build_pages.py puts it on, before the sitemap reads the pages."""

    def test_build_pages_runs_it_before_the_sitemap(self):
        with open(os.path.join(PAGES, 'build_pages.py'), encoding='utf-8') as f:
            text = f.read()
        self.assertIn('family.finish(out)', text)
        self.assertLess(text.index('family.finish(out)'), text.index('seo.finish(out)'))


if __name__ == '__main__':
    unittest.main()
