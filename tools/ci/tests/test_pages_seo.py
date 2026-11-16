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

"""What search engines read on the GitHub Pages site (tools/pages/seo.py):
every page written here names its one address once, the release's files
(web IDE, Stack Player, bare player, codebase map) are left byte for byte
as built and listed by their front pages only, a noindex page is left out,
and the sitemap lists exactly the pages it should. A whole build
(build_pages.build) ends with it.

  python3 -m unittest discover -s tools/ci/tests
"""

import os
import re
import shutil
import sys
import tempfile
import types
import unittest
import xml.etree.ElementTree as ET

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
PAGES = os.path.join(REPO, 'tools', 'pages')
PLAYER = os.path.join(REPO, 'tools', 'web-player')
sys.path.insert(0, PAGES)
sys.path.insert(0, PLAYER)

import build_pages  # noqa: E402
import build_player  # noqa: E402
import seo  # noqa: E402

BASE = seo.BASE
PAGE = '<!DOCTYPE html>\n<html lang="en">\n<head>\n<title>%s</title>\n%s</head>\n<body>x</body>\n</html>\n'
OG = '<meta property="og:title" content="t">\n'


def write(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, 'w', encoding='utf-8') as f:
        f.write(text)


def read(path):
    with open(path, encoding='utf-8') as f:
        return f.read()


def sitemap(site):
    ns = {'s': 'http://www.sitemaps.org/schemas/sitemap/0.9'}
    return [e.text for e in ET.parse(os.path.join(site, 'sitemap.xml')).getroot().findall('s:url/s:loc', ns)]


class TheSite(unittest.TestCase):

    def setUp(self):
        self.site = tempfile.mkdtemp(prefix='test-pages-seo-')
        s = self.site
        write(os.path.join(s, 'index.html'), PAGE % ('Front', OG))
        write(os.path.join(s, 'lessons', 'index.html'), PAGE % ('Lessons', ''))
        write(os.path.join(s, 'lessons', '04-variables.html'), PAGE % ('Variables', OG))
        write(os.path.join(s, 'games', 'wobble-forts', 'index.html'), PAGE % ('Wobble', ''))
        write(os.path.join(s, 'games', 'stack-page.html'), PAGE % ('Hidden', '<meta name="robots" content="noindex">\n'))
        write(os.path.join(s, 'extensions', 'index.html'),
              PAGE % ('Ext', '<link rel="canonical" href="https://example.org/ext/">\n'))
        write(os.path.join(s, 'lessons', 'fragment.html'), '<p>no head</p>')
        self.built = {}
        for rel in ('ide/index.html', 'ide/other.html', 'player/index.html', 'play/index.html',
                    'map/index.html', 'map/stack-scripts/a.html'):
            text = PAGE % (rel, OG)
            write(os.path.join(s, rel), text)
            self.built[rel] = text

    def tearDown(self):
        shutil.rmtree(self.site, ignore_errors=True)

    def test_the_addresses(self):
        self.assertEqual(seo.address(BASE, 'index.html'), BASE)
        self.assertEqual(seo.address(BASE, 'lessons/index.html'), BASE + 'lessons/')
        self.assertEqual(seo.address(BASE, 'lessons/04-variables.html'), BASE + 'lessons/04-variables.html')

    def test_the_sitemap(self):
        listed = seo.finish(self.site)
        self.assertEqual(sitemap(self.site), listed)
        self.assertEqual(sorted(listed), sorted([
            BASE, BASE + 'extensions/', BASE + 'games/wobble-forts/', BASE + 'ide/', BASE + 'lessons/',
            BASE + 'lessons/04-variables.html', BASE + 'map/', BASE + 'play/', BASE + 'player/']))

    def test_each_page_of_ours_names_its_address_once(self):
        seo.finish(self.site)
        front = read(os.path.join(self.site, 'index.html'))
        self.assertEqual(front.count('rel="canonical"'), 1)
        self.assertIn('<link rel="canonical" href="%s">' % BASE, front)
        self.assertIn('<meta property="og:url" content="%s">' % BASE, front)
        lessons = read(os.path.join(self.site, 'lessons', 'index.html'))
        self.assertIn('href="%slessons/"' % BASE, lessons)
        self.assertNotIn('og:url', lessons)   # no preview tags, none added
        self.assertLess(lessons.index('rel="canonical"'), lessons.index('</head>'))

    def test_what_is_left_alone(self):
        seo.finish(self.site)
        for rel, text in self.built.items():
            self.assertEqual(read(os.path.join(self.site, rel)), text, rel)
        ext = read(os.path.join(self.site, 'extensions', 'index.html'))
        self.assertEqual(ext.count('rel="canonical"'), 1)   # a page's own stays
        self.assertNotIn('rel="canonical"', read(os.path.join(self.site, 'games', 'stack-page.html')))
        self.assertEqual(read(os.path.join(self.site, 'lessons', 'fragment.html')), '<p>no head</p>')

    def test_twice_is_once(self):
        seo.finish(self.site)
        first = {rel: read(os.path.join(self.site, rel)) for rel, _ in seo.pages(self.site)}
        seo.finish(self.site)
        for rel, text in first.items():
            self.assertEqual(read(os.path.join(self.site, rel)), text, rel)


class TheBuild(unittest.TestCase):

    def setUp(self):
        self.work = tempfile.mkdtemp(prefix='test-pages-seo-build-')

    def tearDown(self):
        shutil.rmtree(self.work, ignore_errors=True)

    def test_a_whole_build_ends_with_it(self):
        player = os.path.join(self.work, 'StackPlayer')
        os.makedirs(player)
        write(os.path.join(player, 'index.html'), '<html><head><title>Player</title></head><body></body></html>')
        zip_path = os.path.join(self.work, 'OXT-Beyond-test-web-player.zip')
        build_player.make_zip(player, zip_path)
        out = os.path.join(self.work, 'out')
        build_pages.build(types.SimpleNamespace(out=out, ide=None, ide_version=None, player=zip_path,
                                                player_version='test', map=None, map_version=None))
        listed = sitemap(out)
        self.assertIn(BASE, listed)
        self.assertIn(BASE + 'lessons/', listed)
        self.assertIn(BASE + 'extensions/', listed)
        self.assertIn(BASE + 'player/', listed)
        self.assertTrue(any(re.match(re.escape(BASE) + r'lessons/[a-z0-9-]+/$', u) for u in listed))
        self.assertEqual(len(listed), len(set(listed)))
        for url in listed:
            rel = url[len(BASE):]
            path = os.path.join(out, rel, 'index.html') if rel == '' or rel.endswith('/') else os.path.join(out, rel)
            self.assertTrue(os.path.isfile(path), url)
            if not rel.startswith(seo.AS_BUILT):
                self.assertEqual(read(path).count('rel="canonical"'), 1, url)
        # the player is as its zip had it
        self.assertNotIn('canonical', read(os.path.join(out, 'player', 'index.html')))


if __name__ == '__main__':
    unittest.main()
