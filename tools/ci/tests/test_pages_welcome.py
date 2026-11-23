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

"""The welcome section of the GitHub Pages site (tools/pages/welcome): four
pages for people coming from LiveCode, written by its src/build.py and
copied to the site's welcome/ by tools/pages/build_pages.py.

Its pages are what the builder writes; every file they name is there; they
ask no other host for anything; each has the tags a link preview reads
(Open Graph and X's), naming its own address and a picture 1200 by 630 that
is there and small enough for every app that shows one; tools/pages/seo.py
finds their addresses and adds none; nothing moves without end at rest; the
site gets the section without its builder, tests and README; git keeps
every file of it; the stack checker passes its tests (with Node, when
there is one); and its report names the releases the downloads offer.

  python3 -m unittest discover -s tools/ci/tests
"""

import html.parser
import os
import re
import shutil
import struct
import subprocess
import sys
import tempfile
import unittest

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
PAGES = os.path.join(REPO, 'tools', 'pages')
WELCOME = os.path.join(PAGES, 'welcome')
sys.path.insert(0, PAGES)

import build_pages  # noqa: E402
import seo  # noqa: E402

NAMES = ('index.html', 'guide.html', 'in-house.html', 'check.html')
BASE = seo.BASE + 'welcome/'
# Facebook, LinkedIn, X, Mastodon, Discord and Slack show a picture of
# this shape large; WhatsApp shows none over about 300 KB
SHARE_SIZE = (1200, 630)
SHARE_BYTES = 300 * 1024
# What a page names that a browser fetches as it loads the page
FETCHED = {('script', 'src'), ('img', 'src'), ('img', 'srcset'), ('source', 'src'), ('source', 'srcset'),
           ('video', 'src'), ('video', 'poster'), ('audio', 'src'), ('iframe', 'src'), ('embed', 'src'),
           ('object', 'data'), ('input', 'src')}
FETCHED_LINKS = ('stylesheet', 'preload', 'modulepreload', 'icon', 'manifest', 'prefetch')


class Page(html.parser.HTMLParser):
    """The addresses a page names, its link-preview tags and its links."""

    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.refs = []      # (tag, attribute, address)
        self.meta = {}      # property or name: [content, ...]
        self.links = []     # (rel, href)

    def handle_starttag(self, tag, attrs):
        a = dict(attrs)
        for key in ('href', 'src', 'poster', 'data'):
            if a.get(key):
                self.refs.append((tag, key, a[key]))
        if a.get('srcset'):
            for part in a['srcset'].split(','):
                self.refs.append((tag, 'srcset', part.strip().split(' ')[0]))
        if tag == 'meta' and (a.get('property') or a.get('name')):
            self.meta.setdefault(a.get('property') or a.get('name'), []).append(a.get('content', ''))
        if tag == 'link':
            self.links.append((a.get('rel', ''), a.get('href', '')))


def read(*path):
    with open(os.path.join(*path), encoding='utf-8') as f:
        return f.read()


def parse(name):
    page = Page()
    page.feed(read(WELCOME, name))
    return page


def local(address):
    """address as a path in the section, or None for another host, an
    anchor, data or a link to write to someone."""
    if address.startswith(('#', '//')) or re.match(r'[a-z][a-z0-9+.-]*:', address, re.I):
        return None
    return address.split('#')[0].split('?')[0] or None


def jpeg_size(path):
    """A JPEG's (width, height), from its frame header."""
    with open(path, 'rb') as f:
        data = f.read()
    if data[:2] != b'\xff\xd8':
        raise ValueError('%s is not a JPEG' % path)
    at = 2
    while at + 4 <= len(data):
        if data[at] != 0xFF:
            raise ValueError('%s: no marker at %d' % (path, at))
        marker = data[at + 1]
        if marker == 0x01 or 0xD0 <= marker <= 0xD7:
            at += 2
            continue
        length = struct.unpack('>H', data[at + 2:at + 4])[0]
        if marker in (0xC0, 0xC1, 0xC2, 0xC3, 0xC5, 0xC6, 0xC7, 0xC9, 0xCA, 0xCB, 0xCD, 0xCE, 0xCF):
            height, width = struct.unpack('>HH', data[at + 5:at + 9])
            return width, height
        at += 2 + length
    raise ValueError('%s has no frame header' % path)


def without_data(css):
    """css without its data: addresses (a picture written into the sheet
    may name its own parts, as url(#n), which are not files)."""
    return re.sub(r'url\(\s*(?:"data:[^"]*"|\'data:[^\']*\'|data:[^)]*)\s*\)', 'url()', css)


def css_rules(css):
    """Each innermost rule of a style sheet, as (selector, body), comments
    left out (a rule inside @media is read with its own selector)."""
    css = re.sub(r'/\*.*?\*/', '', css, flags=re.S)
    return [(m.group(1).strip(), m.group(2)) for m in re.finditer(r'([^{}]+)\{([^{}]*)\}', css)]


class ThePages(unittest.TestCase):

    def test_they_are_what_the_builder_writes(self):
        run = subprocess.run([sys.executable, '-I', os.path.join(WELCOME, 'src', 'build.py'), '--check'],
                             stdout=subprocess.PIPE, stderr=subprocess.STDOUT, universal_newlines=True)
        self.assertEqual(run.returncode, 0, run.stdout)

    def test_every_file_they_name_is_there(self):
        for name in NAMES:
            for tag, key, address in parse(name).refs:
                path = local(address)
                if path:
                    self.assertTrue(os.path.isfile(os.path.normpath(os.path.join(WELCOME, path))),
                                    '%s: <%s %s="%s"> is not there' % (name, tag, key, address))
        for found in re.finditer(r'url\(\s*["\']?([^"\')]+)', without_data(read(WELCOME, 'assets', 'site.css'))):
            path = local(found.group(1))
            if path:
                self.assertTrue(os.path.isfile(os.path.join(WELCOME, 'assets', path)), 'site.css: ' + path)

    def test_the_logo_is_the_sites(self):
        # ../brand/ is the site's brand/, which build_pages.brand() writes
        for name in NAMES:
            for _, _, address in parse(name).refs:
                if address.startswith('../'):
                    self.assertRegex(address, r'^\.\./brand/[^/]+$', name)
                    self.assertIn(address[len('../brand/'):], build_pages.BRAND, name)

    def test_they_ask_no_other_host(self):
        for name in NAMES:
            page = parse(name)
            for tag, key, address in page.refs:
                if (tag, key) in FETCHED:
                    self.assertTrue(local(address) or address.startswith('data:'),
                                    '%s: <%s %s="%s"> asks another host' % (name, tag, key, address))
            for rel, href in page.links:
                if set(rel.split()) & set(FETCHED_LINKS):
                    self.assertTrue(local(href), '%s: <link rel="%s" href="%s"> asks another host' % (name, rel, href))
        css = without_data(read(WELCOME, 'assets', 'site.css'))
        self.assertNotIn('@import', css)
        self.assertNotRegex(css, r'url\(\s*["\']?(https?:)?//')
        for script in sorted(os.listdir(os.path.join(WELCOME, 'assets'))):
            if script.endswith('.js'):
                text = read(WELCOME, 'assets', script)
                self.assertNotRegex(text, r'\bfetch\s*\(|XMLHttpRequest|WebSocket|importScripts|sendBeacon|\bimport\s*\(',
                                    script + ' asks for something')


class TheLinkPreviews(unittest.TestCase):
    """What a chat app or a social site reads to draw a page's card when
    someone shares its address."""

    def test_each_page_has_its_card(self):
        pictures = []
        for name in NAMES:
            meta = parse(name).meta
            address = BASE if name == 'index.html' else BASE + name
            one = {}
            for key, values in meta.items():
                self.assertEqual(len(values), 1, '%s: %s more than once' % (name, key))
                one[key] = values[0]
            self.assertEqual(one.get('og:url'), address, name)
            self.assertEqual(one.get('og:type'), 'website', name)
            self.assertEqual(one.get('og:site_name'), 'OXT-Beyond', name)
            self.assertEqual(one.get('twitter:card'), 'summary_large_image', name)
            for what in ('title', 'description', 'image', 'image:alt'):
                self.assertTrue(one.get('og:' + what), '%s: no og:%s' % (name, what))
                self.assertEqual(one.get('twitter:' + what), one['og:' + what], '%s: twitter:%s' % (name, what))
            self.assertLessEqual(len(one['og:title']), 70, name)
            self.assertLessEqual(len(one['og:description']), 200, name)
            self.assertTrue(one.get('description'), name)
            image = one['og:image']
            self.assertTrue(image.startswith(BASE + 'share/') and image.endswith('.jpg'), image)
            path = os.path.join(WELCOME, image[len(BASE):])
            self.assertTrue(os.path.isfile(path), image)
            self.assertEqual(jpeg_size(path), SHARE_SIZE, image)
            self.assertEqual((one.get('og:image:width'), one.get('og:image:height')),
                             tuple(str(n) for n in SHARE_SIZE), name)
            self.assertEqual(one.get('og:image:type'), 'image/jpeg', name)
            self.assertLessEqual(os.path.getsize(path), SHARE_BYTES, image)
            pictures.append(image)
        self.assertEqual(len(set(pictures)), len(NAMES), 'each page has a picture of its own')

    def test_each_page_names_its_one_address(self):
        for name in NAMES:
            canonical = [href for rel, href in parse(name).links if rel == 'canonical']
            self.assertEqual(canonical, [BASE if name == 'index.html' else BASE + name], name)

    def test_seo_finds_them_and_adds_nothing(self):
        site = tempfile.mkdtemp(prefix='test-pages-welcome-seo-')
        try:
            target = os.path.join(site, 'welcome')
            build_pages.welcome(WELCOME, target)
            before = {n: read(target, n) for n in NAMES}
            listed = seo.finish(site)
            for name in NAMES:
                self.assertEqual(read(target, name), before[name], name)
                self.assertIn(BASE if name == 'index.html' else BASE + name, listed)
        finally:
            shutil.rmtree(site, ignore_errors=True)

    def test_the_cards_are_drawn_from_the_pages_words(self):
        # src/share.html draws each card (src/share.js saves them): one
        # for each page's picture, its headline the page's own
        cards = read(WELCOME, 'src', 'share.html')
        for name in NAMES:
            image = parse(name).meta['og:image'][0]
            card = os.path.splitext(os.path.basename(image))[0]
            self.assertIn('<section class="card" id="%s">' % card, cards)
            headline = re.search(r'<h1>(.*?)</h1>', read(WELCOME, 'src', 'pages', name), re.S).group(1)
            section = cards[cards.index('id="%s"' % card):]
            self.assertIn(re.sub(r'<[^>]+>', '', headline), re.sub(r'<[^>]+>', '', section[:section.index('</h1>')]),
                          '%s: the card says something else' % card)


class AtRest(unittest.TestCase):
    """The site's rule (test_pages_front.py, StillAtRest; tools/pages/
    check_site_rest.py measures it in a browser): nothing moves without end
    unless it is pointed at or has the keyboard's focus. The checker's
    spinner turns only while a file is read (.busy.on)."""

    def test_nothing_moves_without_end_at_rest(self):
        endless = [(selector, body) for selector, body in css_rules(read(WELCOME, 'assets', 'site.css'))
                   if re.search(r'animation:[^;]*\binfinite\b', body)]
        self.assertTrue(endless)
        for selector, body in endless:
            for part in selector.split(','):
                self.assertRegex(part, r':hover|:focus-within|:has\(:focus-visible\)|\.busy\.on\b',
                                 'moves without end at rest: %s { %s }' % (selector, body.strip()))

    def test_the_spinner_starts_still(self):
        self.assertRegex(read(WELCOME, 'check.html'), r'<span class="busy" id="busy"')

    def test_the_clips_wait_to_be_asked(self):
        for name in NAMES:
            for video in re.findall(r'<video\b[^>]*>', read(WELCOME, name)):
                self.assertNotIn('autoplay', video, name)
                self.assertIn('preload="none"', video, name)


class TheSite(unittest.TestCase):

    def test_the_site_gets_the_pages_and_not_the_tools(self):
        site = tempfile.mkdtemp(prefix='test-pages-welcome-')
        try:
            target = os.path.join(site, 'welcome')
            self.assertEqual(build_pages.welcome(WELCOME, target), sorted(NAMES))
            for left in build_pages.WELCOME_LEFT_OUT:
                # (there in the section, so that a name changed in one
                # place and not the other can't leave nothing to leave out)
                self.assertTrue(os.path.exists(os.path.join(WELCOME, left)), left)
                self.assertFalse(os.path.exists(os.path.join(target, left)), left)
            for name in NAMES:
                for tag, key, address in parse(name).refs:
                    path = local(address)
                    if path and not path.startswith('../'):
                        self.assertTrue(os.path.isfile(os.path.join(target, path)),
                                        '%s: %s is not on the site' % (name, address))
        finally:
            shutil.rmtree(site, ignore_errors=True)

    def test_git_keeps_every_file_of_it(self):
        # The repository's .gitignore leaves out every folder named build/
        # and every .zip, so a file of the section could be there to test
        # here and never reach a commit: the builder did, in a build/
        # folder, before it moved to src/. A .zip of tests/files is kept
        # with git add -f, as the games' standalone.zip files are.
        git = shutil.which('git')
        if not git or not os.path.exists(os.path.join(REPO, '.git')):
            self.skipTest('not a git checkout')
        # (the folder as git names it, which reads the same on Windows)
        run = subprocess.run([git, 'ls-files', '--others', '--ignored', '--exclude-standard', '--',
                              'tools/pages/welcome/'],
                             cwd=REPO, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, universal_newlines=True)
        self.assertEqual(run.returncode, 0, run.stdout)
        ignored = [p for p in run.stdout.splitlines() if '__pycache__/' not in p and not p.endswith('.DS_Store')]
        self.assertEqual(ignored, [], 'git ignores these, so no commit would take them')


class TheChecker(unittest.TestCase):

    def test_it_passes_its_tests(self):
        node = shutil.which('node')
        if not node:
            self.skipTest('no Node to run tools/pages/welcome/tests/run.js')
        run = subprocess.run([node, os.path.join(WELCOME, 'tests', 'run.js')], cwd=os.path.join(WELCOME, 'tests'),
                             stdout=subprocess.PIPE, stderr=subprocess.STDOUT, universal_newlines=True)
        self.assertEqual(run.returncode, 0, run.stdout)
        self.assertIn('All passed', run.stdout)

    def test_its_report_names_the_releases_the_downloads_offer(self):
        # (the report's first line, pasted into forum posts, names both)
        with open(os.path.join(WELCOME, 'assets', 'stackcheck.js'), encoding='utf-8') as f:
            script = f.read()
        with open(os.path.join(WELCOME, 'index.html'), encoding='utf-8') as f:
            page = f.read()
        for name, block in (('STABLE', 'downloads-stable'), ('PREVIEW', 'downloads-preview')):
            said = re.search(r"\bvar %s = '([^']+)'" % name, script)
            offered = re.search(r'id="%s".*?<span class="release">v([^<]+)</span>' % block, page, re.S)
            self.assertTrue(said, name)
            self.assertTrue(offered, block)
            self.assertEqual(said.group(1), offered.group(1), name)


if __name__ == '__main__':
    unittest.main()
