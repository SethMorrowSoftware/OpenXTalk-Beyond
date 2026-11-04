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

"""The extensions page of the GitHub Pages site
(tools/pages/extensions/index.html, filled in by
tools/pages/build_pages.py): a card for each xTalk Suite extension that
OXT-Beyond ships built in, each linking its .lce packages in the suite
release pages.yml found. Whatever the release has, every package link
leads to a file it has, a package the table does not name is still
linked, no marker or placeholder is left, and without a release with
packages every card links the suite's releases instead. Like the rest of
the site, the page asks no other host for anything and is still at rest.

  python3 -m unittest discover -s tools/ci/tests
"""

import io
import os
import re
import shutil
import sys
import tempfile
import unittest
import zipfile
from contextlib import redirect_stdout

CI = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REPO = os.path.dirname(os.path.dirname(CI))
PAGES = os.path.join(REPO, 'tools', 'pages')
sys.path.insert(0, PAGES)
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import build_pages  # noqa: E402
from test_pages_front import parse  # noqa: E402
from test_pages_at_rest import css_rules, endless  # noqa: E402

SUITE = 'https://github.com/SethMorrowSoftware/xtalk-suite'
TAG = 'v2026.11.04'
DOWNLOAD = '%s/releases/download/%s/' % (SUITE, TAG)
# The packages as xtalk-suite's tools/build-lce-packages.py list names them
# (main at 41975bc, 2026-11-03), one per row of its PACKAGES table, in its
# load order
SUITE_PACKAGES = [
    'sodiumxt-0.1.0.lce', 'torrentxt-0.1.0.lce', 'torrentxt-helpers-0.1.0.lce', 'enetxt-0.1.0.lce',
    'enetxt-helpers-0.1.0.lce', 'datachannelxt-0.1.0.lce', 'datachannelxt-helpers-0.1.0.lce',
    'box2dxt-0.2.0.lce', 'box2dxt-kit-0.2.0.lce', 'coinxt-0.1.0.lce', 'coinxt-script-0.1.0.lce',
    'onionxt-1.0.0.lce', 'onionxt-httpd-1.0.0.lce', 'nostrxt-0.1.0.lce', 'nostrxt-relay-0.1.0.lce',
]
ASSETS = SUITE_PACKAGES + ['SHA256SUMS']
# The other hosts the page may link to: the suite, each extension's own
# repository, and OXT-Beyond
EXTERNAL = {SUITE, SUITE + '/releases', 'https://github.com/SethMorrowSoftware/OpenXTalk-Beyond'}
EXTERNAL |= {row[5] for row in build_pages.EXTENSIONS}


def template():
    with open(os.path.join(PAGES, 'extensions', 'index.html'), encoding='utf-8') as f:
        return f.read()


class TheTable(unittest.TestCase):

    def test_every_suite_package_has_a_card(self):
        named = [package for row in build_pages.EXTENSIONS for package, _ in row[7]]
        self.assertEqual(len(named), len(set(named)))
        self.assertEqual(named, [build_pages.SUITE_PACKAGE.match(n).group('package') for n in SUITE_PACKAGES])

    def test_one_card_a_member_with_its_own_repository(self):
        members = [row[0] for row in build_pages.EXTENSIONS]
        self.assertEqual(members, ['sodiumxt', 'torrentxt', 'enetxt', 'datachannelxt', 'box2dxt', 'coinxt',
                                   'onionxt', 'nostrxt'])
        for row in build_pages.EXTENSIONS:
            self.assertRegex(row[5], r'^https://github\.com/SethMorrowSoftware/[A-Za-z0-9-]+$')
            self.assertEqual(row[5].rsplit('/', 1)[1].lower(), row[0])
            # the library first, then what is built on it
            self.assertEqual(row[7][0][0], row[0])

    def test_package_names(self):
        m = build_pages.SUITE_PACKAGE.match('torrentxt-helpers-0.1.0.lce')
        self.assertEqual((m.group('package'), m.group('version')), ('torrentxt-helpers', '0.1.0'))
        m = build_pages.SUITE_PACKAGE.match('box2dxt-kit-0.2.0-rc.1.lce')
        self.assertEqual((m.group('package'), m.group('version')), ('box2dxt-kit', '0.2.0-rc.1'))
        for name in ('SHA256SUMS', 'sodiumxt.lce', 'sodiumxt-0.1.0.zip', '../x-1.lce', 'Sodium-1.lce'):
            self.assertIsNone(build_pages.SUITE_PACKAGE.match(name), name)

    def test_the_newest_of_two_versions(self):
        found = build_pages.suite_packages(['sodiumxt-0.9.0.lce', 'sodiumxt-0.10.0.lce', 'SHA256SUMS'])
        self.assertEqual(found, {'sodiumxt': ('0.10.0', 'sodiumxt-0.10.0.lce')})


class TheTemplate(unittest.TestCase):

    def setUp(self):
        self.text = template()

    def test_markers(self):
        for key in ('SUITE_RELEASE', 'SUITE_NONE', 'SUITE_MORE', 'SUITE_SUMS'):
            self.assertEqual(self.text.count('<!-- @%s@ -->' % key), 1, key)
            self.assertEqual(self.text.count('<!-- /@%s@ -->' % key), 1, key)
            self.assertLess(self.text.index('<!-- @%s@ -->' % key), self.text.index('<!-- /@%s@ -->' % key))
        self.assertEqual(self.text.count('@EXTENSIONS_LIST@'), 1)
        # the release's own links only inside its block
        release = self.text[self.text.index('<!-- @SUITE_RELEASE@ -->'):self.text.index('<!-- /@SUITE_RELEASE@ -->')]
        for key in ('@SUITE_TAG@', '@SUITE_TAG_URL@', '@SUITE_SUMS_URL@'):
            self.assertEqual(self.text.count(key), release.count(key), key)

    def test_nothing_from_another_host(self):
        page = parse(self.text)
        self.assertEqual(page.errors, [])
        self.assertEqual(sorted(set(page.loads)), ['../brand/icon.svg', '../brand/logo-animated.svg', '../brand/logo.svg'])
        self.assertNotRegex(self.text, r'url\(\s*["\']?(https?:)?//')
        self.assertNotRegex(self.text, r'@import')

    def test_still_at_rest(self):
        # As the gallery (test_pages_at_rest.py): a rim runs only around the
        # card pointed at or focused, the flame flows twice as the page
        # opens, the rays are still and the logo moves only as it opens
        found = endless(self.text)
        self.assertTrue(found)
        for selector, body in found:
            for part in selector.split(','):
                self.assertRegex(part, r':hover|:focus-within|:focus-visible',
                                 'moves without end at rest: %s { %s }' % (selector, body.strip()))
        rules = dict(css_rules(self.text))
        self.assertNotIn('animation', rules['.ext::before'])
        self.assertNotIn('animation', rules['.sky::after'])
        self.assertIn('animation: flow 6s ease-in-out 2 alternate;', rules['.flame'])
        reduce = self.text[self.text.index('@media (prefers-reduced-motion: reduce)'):]
        self.assertIn('*, *::before, *::after { animation: none !important; transition: none !important; }', reduce)
        self.assertIn('.hero-logo .moving { display: none !important; }', reduce)
        script = self.text[self.text.index('<script>'):self.text.index('</script>')]
        self.assertIn("setTimeout(function () { root.classList.remove('opening'); }, 6000);", script)


class TheBuiltPage(unittest.TestCase):

    def setUp(self):
        self.work = tempfile.mkdtemp(prefix='test-pages-extensions-')

    def tearDown(self):
        shutil.rmtree(self.work, ignore_errors=True)

    def build(self, tag, assets):
        out = os.path.join(self.work, 'site-%d' % len(os.listdir(self.work)))
        shown = build_pages.extensions_page(os.path.join(PAGES, 'extensions'), out, tag, set(assets))
        with open(os.path.join(out, 'index.html'), encoding='utf-8') as f:
            text = f.read()
        where = '%s %d files' % (tag, len(assets))
        self.assertNotIn('<!-- @', text, where)
        self.assertNotIn('<!-- /@', text, where)
        self.assertNotRegex(text, r'@[A-Z_]+@', where)
        page = parse(text)
        self.assertEqual(page.errors, [], where)
        for href in page.links:
            if href.startswith(SUITE + '/releases/download/'):
                self.assertTrue(href.startswith(DOWNLOAD), href)
                self.assertIn(href[len(DOWNLOAD):], assets, href)
            elif href.startswith(SUITE + '/releases/tag/'):
                self.assertEqual(href, SUITE + '/releases/tag/' + TAG)
            elif href.startswith('https://'):
                self.assertIn(href, EXTERNAL, href)
            else:
                self.assertIn(href, ('../',), href)
        for row in build_pages.EXTENSIONS:
            self.assertIn('id="%s"' % row[0], text)
            self.assertIn('href="%s"' % row[5], text)
        return shown, text, page

    def test_with_every_package(self):
        shown, text, page = self.build(TAG, ASSETS)
        self.assertEqual(shown, TAG)
        for name in SUITE_PACKAGES:
            self.assertEqual(page.links.count(DOWNLOAD + name), 1, name)
        self.assertIn('href="%sSHA256SUMS"' % DOWNLOAD, text)
        self.assertIn('<span class="tag">%s</span>' % TAG, text)
        self.assertNotIn('class="soon"', text)
        self.assertNotIn('id="more-packages"', text)
        # each card's library is the filled button, what is built on it the
        # outlined one
        self.assertIn('<a class="file" href="%ssodiumxt-0.1.0.lce" download>' % DOWNLOAD, text)
        self.assertIn('<a class="file ghost" href="%storrentxt-helpers-0.1.0.lce" download>' % DOWNLOAD, text)
        self.assertIn('Helpers <small>0.1.0</small></a>', text)

    def test_with_no_release(self):
        shown, text, page = self.build(None, ())
        self.assertIsNone(shown)
        self.assertNotIn('.lce"', text)
        self.assertEqual(text.count('class="soon"'), len(build_pages.EXTENSIONS))
        self.assertIn('href="%s/releases"' % SUITE, text)
        self.assertNotIn('class="tag"', text)

    def test_a_release_without_packages(self):
        # (the suite has releases of other things, or one whose packages
        # did not upload): the same as none
        shown, text, page = self.build(TAG, ['SHA256SUMS', 'notes.txt'])
        self.assertIsNone(shown)
        self.assertNotIn('SHA256SUMS', text)
        self.assertNotIn(TAG, text)

    def test_only_the_files_the_release_has(self):
        assets = [n for n in ASSETS if not n.startswith('coinxt') and n != 'SHA256SUMS']
        shown, text, page = self.build(TAG, assets)
        self.assertEqual(shown, TAG)
        card = text[text.index('id="coinxt"'):]
        card = card[:card.index('</article>')]
        self.assertIn('class="soon"', card)
        self.assertNotIn('.lce"', card)
        self.assertNotIn('SHA256SUMS', text)

    def test_a_package_the_table_does_not_name(self):
        shown, text, page = self.build(TAG, ASSETS + ['riptide-0.3.0.lce'])
        self.assertIn('id="more-packages"', text)
        self.assertIn('href="%sriptide-0.3.0.lce"' % DOWNLOAD, text)

    def test_names_are_escaped(self):
        tag = 'v1.0'
        out = os.path.join(self.work, 'escaped')
        build_pages.extensions_page(os.path.join(PAGES, 'extensions'), out, tag, {'sodiumxt-1.0+x.lce'})
        with open(os.path.join(out, 'index.html'), encoding='utf-8') as f:
            text = f.read()
        self.assertIn('%s/releases/download/v1.0/sodiumxt-1.0%%2Bx.lce' % SUITE, text)
        self.assertIn('SodiumXT <small>1.0+x</small>', text)

    def test_a_tag_that_is_not_one(self):
        for tag in ('v1"><script>', '../x', '-v1', ' v1'):
            with self.assertRaises(build_pages.BuildError):
                build_pages.extensions_html(tag, set(ASSETS))

    def test_the_whole_build(self):
        # through build(), as pages.yml runs it
        player = os.path.join(self.work, 'OXT-Beyond-9.9.9-web-player.zip')
        with zipfile.ZipFile(player, 'w') as z:
            z.writestr('StackPlayer/index.html', '<!DOCTYPE html><title>Player</title>')
        listing = os.path.join(self.work, 'suite-assets.txt')
        with open(listing, 'w', encoding='utf-8') as f:
            f.write('\n'.join(ASSETS) + '\n')
        out = os.path.join(self.work, 'site')
        args = build_pages.argparse.Namespace(out=out, ide=None, ide_version=None, player=player,
                                              player_version='9.9.9', map=None, map_version=None,
                                              suite_release=TAG, suite_assets=listing)
        with redirect_stdout(io.StringIO()):
            build_pages.build(args)
        with open(os.path.join(out, 'index.html'), encoding='utf-8') as f:
            front = f.read()
        self.assertIn('<a class="button" href="extensions/">See the extensions</a>', front)
        self.assertIn('<p class="version">xTalk Suite %s</p>' % TAG, front)
        with open(os.path.join(out, 'extensions', 'index.html'), encoding='utf-8') as f:
            self.assertIn(DOWNLOAD + 'nostrxt-relay-0.1.0.lce', f.read())
        shutil.rmtree(out)
        args.suite_assets = None
        with self.assertRaisesRegex(build_pages.BuildError, 'suite-assets'):
            build_pages.build(args)


class TheWorkflow(unittest.TestCase):
    """pages.yml finds the suite's newest release with .lce files and
    hands its files to build_pages.py; a failure leaves the page without
    packages, with a warning, and never stops the site."""

    def setUp(self):
        with open(os.path.join(REPO, '.github', 'workflows', 'pages.yml'), encoding='utf-8') as f:
            self.text = f.read()

    def test_it_lists_the_suite_release(self):
        self.assertIn('--repo SethMorrowSoftware/xtalk-suite', self.text)
        self.assertIn("grep -q '\\.lce$'", self.text)
        self.assertIn('args+=(--suite-release "$SUITE_TAG" --suite-assets "$RUNNER_TEMP/suite-assets.txt")',
                      self.text)
        step = self.text[self.text.index('- name: The xTalk Suite release with packages'):]
        step = step[:step.index('- name:', 10)]
        self.assertIn('continue-on-error: true', step)

    def test_the_summary_says_where_the_packages_are(self):
        self.assertIn('- Extensions:', self.text)


if __name__ == '__main__':
    unittest.main()
