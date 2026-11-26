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
tools/pages/build_pages.py): a card for every xTalk Suite extension, each
linking its .lce packages in the suite release pages.yml found. The table
writes a card for each member of the suite, and a member it does not name
yet gets a card made from its own packages (their manifest.xml and
api.lcdoc, read only from a package whose checksum is the one the
release's SHA256SUMS gives, and escaped like any other text), so no
package is ever a bare link. Each card says which of the OXT-Beyond
releases the front page offers has it built in, from that release's
tools/oxt/xtalk-extensions.json, and nothing without one. Whatever the
release has, every package link leads to a file it has, no marker or
placeholder is left, and without a release with packages every card links
the suite's releases instead. Like the rest of the site, the page asks no
other host for anything and is still at rest. After the extensions come
OXT-Beyond's own two plugins, the xTalk Assistant and the xTalk MCP
Bridge, linked in the OXT-Beyond release the front page's Downloads
links.

  python3 -m unittest discover -s tools/ci/tests
"""

import hashlib
import html.parser
import io
import json
import os
import re
import shutil
import sys
import tempfile
import unittest
import zipfile
from contextlib import redirect_stdout
from xml.sax.saxutils import escape, quoteattr

CI = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REPO = os.path.dirname(os.path.dirname(CI))
PAGES = os.path.join(REPO, 'tools', 'pages')
sys.path.insert(0, PAGES)
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import build_pages  # noqa: E402
from test_pages_front import parse  # noqa: E402
from test_pages_at_rest import css_rules, endless  # noqa: E402

SUITE = 'https://github.com/SethMorrowSoftware/xtalk-suite'
TAG = 'v2026.11.22.8'
DOWNLOAD = '%s/releases/download/%s/' % (SUITE, TAG)
# The packages that xtalk-suite's lce-packages.yml attached to its release
# v2026.11.22.8 (2026-11-22), one per row of its PACKAGES table: twenty
# members, and the helpers, Kits and script layers built on them
SUITE_PACKAGES = [
    'artnetxt-0.1.0.lce', 'audioxt-0.1.0.lce', 'barcodext-0.1.0.lce', 'box2dxt-0.2.0.lce',
    'box2dxt-kit-0.2.0.lce', 'box3dxt-0.1.0.lce', 'box3dxt-kit-0.1.0.lce', 'coinxt-0.1.0.lce',
    'coinxt-script-0.1.0.lce', 'curlxt-0.2.1.lce', 'curlxt-helpers-0.2.1.lce', 'curlxt-tsnet-0.2.1.lce',
    'datachannelxt-0.1.0.lce', 'datachannelxt-helpers-0.1.0.lce', 'enetxt-0.1.0.lce', 'enetxt-helpers-0.1.0.lce',
    'gamepadxt-0.1.0.lce', 'midixt-0.1.0.lce', 'nostrxt-0.1.0.lce', 'nostrxt-relay-0.1.0.lce',
    'onionxt-1.0.0.lce', 'onionxt-httpd-1.0.0.lce', 'oscxt-0.1.0.lce', 'pdfxt-0.1.0.lce',
    'render3dxt-0.1.0.lce', 'sodiumxt-0.1.0.lce', 'torrentxt-0.1.0.lce', 'torrentxt-helpers-0.1.0.lce',
    'webpxt-0.1.0.lce', 'xlsxt-0.1.0.lce',
]
ASSETS = SUITE_PACKAGES + ['SHA256SUMS']
# The order the page shows the members in: cryptography, networking,
# physics and 3D, game controllers and sound, show control, documents and
# pictures
MEMBERS = ['sodiumxt', 'coinxt', 'nostrxt', 'torrentxt', 'enetxt', 'datachannelxt', 'curlxt', 'onionxt',
           'box2dxt', 'box3dxt', 'render3dxt', 'gamepadxt', 'audioxt', 'midixt', 'oscxt', 'artnetxt', 'pdfxt',
           'xlsxt', 'webpxt', 'barcodext']
# The other hosts the page may link to: the suite, each extension's own
# repository, and OXT-Beyond; a card made from a package links its folder
# in the suite at the release's tag (checked in TheBuiltPage.build)
EXTERNAL = {SUITE, SUITE + '/releases', 'https://github.com/SethMorrowSoftware/OpenXTalk-Beyond',
            # the xTalk Suite's own packages page, for the IDEs built on LiveCode Community 9
            'https://sethmorrowsoftware.github.io/xtalk-suite/'}
EXTERNAL |= {row[5] for row in build_pages.EXTENSIONS}
BEYOND = 'https://github.com/SethMorrowSoftware/OpenXTalk-Beyond'
EXTERNAL |= {BEYOND + '/releases', BEYOND + '/tree/main/tools/plugins'}
# OXT-Beyond's own plugins, in the release the front page's Downloads links
BEYOND_TAG = 'v0.2.7-rc.6.14'
BEYOND_DOWNLOAD = '%s/releases/download/%s/' % (BEYOND, BEYOND_TAG)
BEYOND_PLUGINS = ['OXT-Beyond-0.2.7-rc.6.14-xtalk-assistant-plugin.lce',
                  'OXT-Beyond-0.2.7-rc.6.14-mcp-bridge-plugin.lce']
# The SVG elements and attributes an icon may use: shapes, drawn with the
# card's colour, and nothing that loads, links or runs
ICON_ELEMENTS = {'path', 'rect', 'circle', 'ellipse'}
ICON_ATTRIBUTES = {'d', 'x', 'y', 'width', 'height', 'rx', 'ry', 'cx', 'cy', 'r', 'transform', 'fill'}


def template():
    with open(os.path.join(PAGES, 'extensions', 'index.html'), encoding='utf-8') as f:
        return f.read()


def manifest(ident, title, requires=()):
    """A package's manifest.xml as lce-packages.yml writes one."""
    return ('<?xml version="1.0" encoding="UTF-8"?>\n<package version="0.0">\n  <name>%s</name>\n'
            '  <title>%s</title>\n  <author>Seth Morrow</author>\n  <version>0.1.0</version>\n%s</package>\n'
            % (escape(ident), escape(title),
               ''.join('  <requires name=%s/>\n' % quoteattr(r) for r in ('com.livecode.foreign',) + tuple(requires))))


def lcdoc(ident, about, key='Summary'):
    """An api.lcdoc: its library entry, then a handler's."""
    return ('Library: %s\n\nType: library\n\n%s:\n%s\n\nMore about it, which the card leaves out.\n\n'
            'Name: fooStart\n\nType: command\n\nSummary: Starts it.\n' % (ident, key, about))


def package(folder, name, manifest_xml, lcdoc_text=None, native=False, lcm=False):
    """A .lce in folder, with the parts the page reads: a native one has a
    library under code/<platform>/, an xTalk Builder one module.lcm."""
    with zipfile.ZipFile(os.path.join(folder, name), 'w', zipfile.ZIP_DEFLATED) as z:
        z.writestr('manifest.xml', manifest_xml)
        if lcdoc_text is not None:
            z.writestr('api.lcdoc', lcdoc_text)
        if native:
            z.writestr('code/x86_64-linux/foo.so', b'\x7fELF')
        if lcm:
            z.writestr('module.lcm', b'LCM')
    return name


def sums(folder, names):
    """SHA256SUMS of the files names in folder, as sha256sum writes it."""
    with open(os.path.join(folder, 'SHA256SUMS'), 'w', encoding='utf-8') as f:
        for name in names:
            with open(os.path.join(folder, name), 'rb') as g:
                f.write('%s  %s\n' % (hashlib.sha256(g.read()).hexdigest(), name))


def card(text, ident):
    """The card with the id ident on a built page."""
    at = text.index('<article class="ext" id="%s">' % ident)
    return text[at:text.index('</article>', at)]


class TheTable(unittest.TestCase):

    def test_every_suite_package_has_a_card(self):
        named = [package for row in build_pages.EXTENSIONS for package, _ in row[7]]
        self.assertEqual(len(named), len(set(named)))
        self.assertEqual(set(named), {build_pages.SUITE_PACKAGE.match(n).group('package') for n in SUITE_PACKAGES})

    def test_one_card_a_member_with_its_own_repository(self):
        members = [row[0] for row in build_pages.EXTENSIONS]
        self.assertEqual(members, MEMBERS)
        for row in build_pages.EXTENSIONS:
            self.assertRegex(row[5], r'^https://github\.com/SethMorrowSoftware/[A-Za-z0-9-]+$')
            self.assertEqual(row[5].rsplit('/', 1)[1].lower(), row[0])
            # the library first, then what is built on it, each package one
            # of its own member's
            self.assertEqual(row[7][0][0], row[0])
            for package, _ in row[7]:
                self.assertEqual(build_pages.suite_family(package), row[0])

    def test_every_card_says_what_it_does(self):
        # first class: a name, what it is built on and a sentence or two of
        # what it does, as the first eight had
        for member, name, kind, what, needs, repo, icon, files in build_pages.EXTENSIONS:
            self.assertEqual(name.lower(), member)
            self.assertRegex(kind, r'^(Native|Script|xTalk Builder) library · \S', member)
            self.assertGreater(len(what), 80, member)
            self.assertLess(len(what), 260, member)
            self.assertTrue(what.endswith('.'), member)
            self.assertTrue(needs is None or needs.strip() == needs and needs, member)

    def test_every_extension_built_in_has_its_card(self):
        # what OXT-Beyond ships built in (tools/oxt/xtalk-extensions.json)
        # is on the page with words of its own, not only a card made from
        # its package
        found = build_pages.built_in_members(os.path.join(REPO, 'tools', 'oxt', 'xtalk-extensions.json'))
        with open(os.path.join(REPO, 'tools', 'oxt', 'xtalk-extensions.json'), encoding='utf-8') as f:
            names = [m['name'].lower() for m in json.load(f)['members']]
        self.assertTrue(names)
        self.assertLessEqual(set(names), found)
        self.assertLessEqual(set(names), {row[0] for row in build_pages.EXTENSIONS})

    def test_the_icons_only_draw(self):
        class Shapes(html.parser.HTMLParser):
            def __init__(self):
                super().__init__()
                self.found = []

            def handle_starttag(self, tag, attrs):
                self.found.append((tag, dict(attrs)))

            def handle_startendtag(self, tag, attrs):
                self.found.append((tag, dict(attrs)))

            def handle_data(self, data):
                if data.strip():
                    self.found.append(('#text', {}))

        for ident, icon in [(row[0], row[6]) for row in build_pages.EXTENSIONS] + [('package', build_pages.SUITE_ICON)]:
            shapes = Shapes()
            shapes.feed(icon)
            shapes.close()
            self.assertTrue(shapes.found, ident)
            for tag, attrs in shapes.found:
                self.assertIn(tag, ICON_ELEMENTS, ident)
                self.assertLessEqual(set(attrs), ICON_ATTRIBUTES, ident)
                self.assertIn(attrs.get('fill', 'currentColor'), ('currentColor', 'none'), ident)
            self.assertNotRegex(icon, r'url\(|href|javascript', ident)
        # each its own
        icons = [row[6] for row in build_pages.EXTENSIONS] + [build_pages.SUITE_ICON]
        self.assertEqual(len(icons), len(set(icons)))

    def test_package_names(self):
        m = build_pages.SUITE_PACKAGE.match('torrentxt-helpers-0.1.0.lce')
        self.assertEqual((m.group('package'), m.group('version')), ('torrentxt-helpers', '0.1.0'))
        m = build_pages.SUITE_PACKAGE.match('box2dxt-kit-0.2.0-rc.1.lce')
        self.assertEqual((m.group('package'), m.group('version')), ('box2dxt-kit', '0.2.0-rc.1'))
        for name in ('SHA256SUMS', 'sodiumxt.lce', 'sodiumxt-0.1.0.zip', '../x-1.lce', 'Sodium-1.lce'):
            self.assertIsNone(build_pages.SUITE_PACKAGE.match(name), name)
        self.assertEqual(build_pages.suite_family('curlxt-tsnet'), 'curlxt')
        self.assertEqual(build_pages.suite_family('pdfxt'), 'pdfxt')

    def test_the_newest_of_two_versions(self):
        found = build_pages.suite_packages(['sodiumxt-0.9.0.lce', 'sodiumxt-0.10.0.lce', 'SHA256SUMS'])
        self.assertEqual(found, {'sodiumxt': ('0.10.0', 'sodiumxt-0.10.0.lce')})


class WhatAPackageSays(unittest.TestCase):
    """What a card made from a package takes from it."""

    def test_the_first_paragraph_of_the_library_entry(self):
        about = build_pages.lcdoc_about(lcdoc('org.x', 'Builds and reads <oscParse> bytes:\n`open datagram '
                                                       'socket`, then write.\nNote: this line is part of it.'))
        self.assertEqual(about, 'Builds and reads oscParse bytes: open datagram socket, then write. '
                                'Note: this line is part of it.')
        # a script library's Description, with \r\n lines
        text = lcdoc('kit', 'A pure-script toolkit.', key='Description').replace('\n', '\r\n')
        self.assertEqual(build_pages.lcdoc_about('Title: Kit\r\n\r\n' + text), 'A pure-script toolkit.')
        # a handler's summary is not the library's
        self.assertEqual(build_pages.lcdoc_about('Library: x\n\nType: library\n\nName: y\n\nSummary: Not this.\n'), '')
        self.assertEqual(build_pages.lcdoc_about(''), '')

    def test_a_long_one_ends_at_a_sentence(self):
        long = ' '.join(['This sentence says one more thing about it.'] * 20)
        about = build_pages.lcdoc_about(lcdoc('org.x', long))
        self.assertLessEqual(len(about), build_pages.SUITE_ABOUT_LIMIT)
        self.assertTrue(about.endswith('it.'), about)
        about = build_pages.lcdoc_about(lcdoc('org.x', 'word ' * 200))
        self.assertLessEqual(len(about), build_pages.SUITE_ABOUT_LIMIT + 4)
        self.assertTrue(about.endswith(' ...'), about)

    def test_titles_and_labels(self):
        title = build_pages.suite_title
        self.assertEqual(title('render3dxt', 'render3dxt: 3D Renderer for OpenXTalk'), '3D Renderer')
        self.assertEqual(title('pdfxt', 'PDFium for OpenXTalk'), 'PDFium')
        self.assertEqual(title('torrentxt', 'TorrentXT helpers'), 'helpers')
        self.assertEqual(title('curlxt', 'tsNet calls (curlxt)'), 'tsNet calls')
        self.assertEqual(title('coinxt', 'CoinXT'), '')
        # (a name that only starts with the member's is not the member's)
        self.assertEqual(title('box', 'Boxes for OpenXTalk'), 'Boxes')
        label = build_pages.suite_label
        self.assertEqual(label('torrentxt', 'torrentxt-helpers', {'title': 'TorrentXT helpers'}), 'Helpers')
        self.assertEqual(label('curlxt', 'curlxt-tsnet', {'title': 'tsNet calls (curlxt)'}), 'tsNet calls')
        self.assertEqual(label('coinxt', 'coinxt-script', {'title': 'CoinXT script layer'}), 'Script layer')
        self.assertEqual(label('box3dxt', 'box3dxt-kit', None), 'Kit')
        self.assertEqual(label('box3dxt', 'box3dxt-kit', {'title': 'box3dxt'}), 'Kit')

    def test_the_release_s_built_in_extensions(self):
        work = tempfile.mkdtemp(prefix='test-pages-extensions-built-in-')
        self.addCleanup(shutil.rmtree, work, ignore_errors=True)
        path = os.path.join(work, 'x.json')
        with open(path, 'w', encoding='utf-8') as f:
            json.dump({'members': [{'name': 'SodiumXT', 'repository': 'SethMorrowSoftware/SodiumXT'},
                                   {'name': 'curl', 'repository': 'SethMorrowSoftware/curlXT'}]}, f)
        self.assertEqual(build_pages.built_in_members(path), {'sodiumxt', 'curl', 'curlxt'})
        for text in ('', '{}', '[]', '{"members": 3}', 'not json'):
            with open(path, 'w', encoding='utf-8') as f:
                f.write(text)
            with redirect_stdout(io.StringIO()) as log:
                self.assertIsNone(build_pages.built_in_members(path), text)
            self.assertIn('say nothing of it', log.getvalue())
        with redirect_stdout(io.StringIO()):
            self.assertIsNone(build_pages.built_in_members(os.path.join(work, 'none.json')))

    def test_the_built_in_line(self):
        line = build_pages.built_line
        both = [('0.2.7', {'sodiumxt'}), ('0.2.8-dp.2.1', {'sodiumxt', 'curlxt'})]
        self.assertEqual(line('sodiumxt', both), '        <p class="built">Built into OXT-Beyond 0.2.7</p>\n')
        self.assertEqual(line('curlxt', both), '        <p class="built">Built into OXT-Beyond 0.2.8-dp.2.1</p>\n')
        self.assertEqual(line('pdfxt', both), '        <p class="built no">Not built into OXT-Beyond 0.2.8-dp.2.1: '
                                              'install its package there too</p>\n')
        self.assertEqual(line('pdfxt', both[:1]), '        <p class="built no">Not built into OXT-Beyond 0.2.7: '
                                                   'install its package there too</p>\n')
        self.assertEqual(line('sodiumxt', []), '')
        self.assertIn('0.2.8&lt;b&gt;', line('x', [('0.2.8<b>', set())]))


class TheTemplate(unittest.TestCase):

    def setUp(self):
        self.text = template()

    def test_markers(self):
        for key in ('SUITE_RELEASE', 'SUITE_NONE', 'SUITE_SUMS', 'BUILT_IN'):
            self.assertEqual(self.text.count('<!-- @%s@ -->' % key), 1, key)
            self.assertEqual(self.text.count('<!-- /@%s@ -->' % key), 1, key)
            self.assertLess(self.text.index('<!-- @%s@ -->' % key), self.text.index('<!-- /@%s@ -->' % key))
        self.assertEqual(self.text.count('@EXTENSIONS_LIST@'), 1)
        # every package is on a card, so there is no list of the others
        self.assertNotIn('SUITE_MORE', self.text)
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

    def build(self, tag, assets, beyond_tag=None, beyond_assets=(), facts=None, built_in=()):
        out = os.path.join(self.work, 'site-%d' % len(os.listdir(self.work)))
        shown = build_pages.extensions_page(os.path.join(PAGES, 'extensions'), out, tag, set(assets),
                                            beyond_tag, set(beyond_assets), facts, built_in)
        with open(os.path.join(out, 'index.html'), encoding='utf-8') as f:
            text = f.read()
        where = '%s %d files' % (tag, len(assets))
        self.assertNotIn('<!-- @', text, where)
        self.assertNotIn('<!-- /@', text, where)
        self.assertNotRegex(text, r'@[A-Z_]+@', where)
        page = parse(text)
        self.assertEqual(page.errors, [], where)
        families = {build_pages.suite_family(m.group('package'))
                    for m in map(build_pages.SUITE_PACKAGE.match, assets) if m}
        for href in page.links:
            if href.startswith(SUITE + '/releases/download/'):
                self.assertTrue(href.startswith(DOWNLOAD), href)
                self.assertIn(href[len(DOWNLOAD):], assets, href)
            elif href.startswith(BEYOND + '/releases/download/'):
                self.assertTrue(href.startswith(BEYOND_DOWNLOAD), href)
                self.assertIn(href[len(BEYOND_DOWNLOAD):], beyond_assets, href)
            elif href.startswith(SUITE + '/releases/tag/'):
                self.assertEqual(href, SUITE + '/releases/tag/' + TAG)
            elif href.startswith(SUITE + '/tree/'):
                # a card made from a package: its member's folder in the
                # suite, as the release has it
                self.assertTrue(href.startswith('%s/tree/%s/' % (SUITE, TAG)), href)
                self.assertIn(href.rsplit('/', 1)[1], families - {row[0] for row in build_pages.EXTENSIONS}, href)
            elif href.startswith('https://'):
                self.assertIn(href, EXTERNAL, href)
            else:
                self.assertIn(href, ('../',), href)
        for row in build_pages.EXTENSIONS:
            self.assertIn('id="%s"' % row[0], text)
            self.assertIn('href="%s"' % row[5], text)
        # the cards in the table's order, before any made from a package
        at = [text.index('<article class="ext" id="%s">' % row[0]) for row in build_pages.EXTENSIONS]
        self.assertEqual(at, sorted(at))
        # every package of the release on a card, once
        for name in assets:
            if build_pages.SUITE_PACKAGE.match(name):
                self.assertEqual(page.links.count(DOWNLOAD + name), 1, name)
        # what OXT-Beyond has built in, said only when it is known
        self.assertEqual('each card says from which release' in text, bool(built_in), where)
        self.assertEqual(text.count('<p class="built'), len(re.findall(r'<article class="ext" id="(?!xtalk-assistant|'
                                                                      r'mcp-bridge)', text)) if built_in else 0)
        return shown, text, page

    def test_the_plugins(self):
        # The xTalk Assistant and the xTalk MCP Bridge, OXT-Beyond's own,
        # each linked in the release the front page's Downloads links
        shown, text, page = self.build(TAG, ASSETS, BEYOND_TAG, BEYOND_PLUGINS + ['SHA256SUMS'])
        for name in BEYOND_PLUGINS:
            self.assertEqual(page.links.count(BEYOND_DOWNLOAD + name), 1, name)
        for ident in ('xtalk-assistant', 'mcp-bridge'):
            self.assertIn('id="%s"' % ident, text)
        self.assertIn('xTalk Assistant <small>0.2.7-rc.6.14</small>', text)
        self.assertIn('xTalk MCP Bridge <small>0.2.7-rc.6.14</small>', text)

    def test_the_plugins_without_a_release(self):
        # no OXT-Beyond release listed, or one without the plugin: its card
        # links OXT-Beyond's releases
        shown, text, page = self.build(TAG, ASSETS)
        self.assertNotIn('-plugin.lce', text)
        self.assertEqual(page.links.count(BEYOND + '/releases'), 2)
        shown, text, page = self.build(TAG, ASSETS, BEYOND_TAG, BEYOND_PLUGINS[:1])
        self.assertIn(BEYOND_DOWNLOAD + BEYOND_PLUGINS[0], text)
        self.assertNotIn(BEYOND_PLUGINS[1], text)
        self.assertEqual(page.links.count(BEYOND + '/releases'), 1)

    def test_a_beyond_tag_that_is_not_one(self):
        for tag in ('0.2.7', 'v0.2.7"><script>', ''):
            with self.assertRaises(build_pages.BuildError):
                build_pages.plugins_html(tag, set(BEYOND_PLUGINS))

    def test_with_every_package(self):
        shown, text, page = self.build(TAG, ASSETS)
        self.assertEqual(shown, TAG)
        self.assertIn('href="%sSHA256SUMS"' % DOWNLOAD, text)
        self.assertIn('<span class="tag">%s</span>' % TAG, text)
        self.assertNotIn('class="soon"', text[:text.index('id="the-plugins"')])
        # a card for each member, and none made from a package
        self.assertEqual(text.count('<article class="ext"'), len(MEMBERS) + len(build_pages.PLUGINS))
        self.assertNotIn(build_pages.SUITE_ICON, text)
        # each card's library is the filled button, what is built on it the
        # outlined one, in the order they install
        self.assertIn('<a class="file" href="%ssodiumxt-0.1.0.lce" download>' % DOWNLOAD, text)
        self.assertIn('<a class="file ghost" href="%storrentxt-helpers-0.1.0.lce" download>' % DOWNLOAD, text)
        self.assertIn('Helpers <small>0.1.0</small></a>', text)
        curl = card(text, 'curlxt')
        self.assertLess(curl.index('curlxt-0.2.1.lce'), curl.index('curlxt-helpers-0.2.1.lce'))
        self.assertLess(curl.index('curlxt-helpers-0.2.1.lce'), curl.index('curlxt-tsnet-0.2.1.lce'))
        self.assertIn('tsNet calls <small>0.2.1</small>', curl)
        self.assertIn('<p class="needs">Needs macOS 13 or later on a Mac</p>', card(text, 'pdfxt'))

    def test_with_no_release(self):
        shown, text, page = self.build(None, ())
        self.assertIsNone(shown)
        self.assertNotIn('.lce"', text)
        self.assertEqual(text.count('class="soon"'), len(build_pages.EXTENSIONS) + len(build_pages.PLUGINS))
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
        coin = card(text, 'coinxt')
        self.assertIn('class="soon"', coin)
        self.assertNotIn('.lce"', coin)
        self.assertNotIn('SHA256SUMS', text)

    def test_a_package_its_card_does_not_name(self):
        # a member's new package goes on its card, after the ones the table
        # names, with a label from its title, or from its name without one
        assets = ASSETS + ['torrentxt-streams-0.1.0.lce', 'box3dxt-editor-0.1.0.lce']
        facts = {'torrentxt-streams-0.1.0.lce': {'id': 'torrentStreams', 'title': 'TorrentXT streams',
                                                 'requires': ['torrentHelpers'], 'kind': 'script', 'about': 'x'}}
        shown, text, page = self.build(TAG, assets, facts=facts)
        torrent = card(text, 'torrentxt')
        self.assertLess(torrent.index('torrentxt-helpers-0.1.0.lce'), torrent.index('torrentxt-streams-0.1.0.lce'))
        self.assertIn('<a class="file ghost" href="%storrentxt-streams-0.1.0.lce" download>' % DOWNLOAD, torrent)
        self.assertIn('Streams <small>0.1.0</small>', torrent)
        self.assertIn('Editor <small>0.1.0</small>', card(text, 'box3dxt'))
        self.assertNotIn('id="torrentxt-streams"', text)

    def test_a_member_the_table_does_not_name(self):
        # one that joined the suite after the table was written: a card of
        # its own, made from its packages, after the table's cards, and
        # here with nothing read from them
        shown, text, page = self.build(TAG, ASSETS + ['riptide-0.3.0.lce', 'riptide-kit-0.3.0.lce'])
        new = card(text, 'riptide')
        self.assertGreater(text.index('id="riptide"'), text.index('id="barcodext"'))
        self.assertLess(text.index('id="riptide"'), text.index('id="the-plugins"'))
        self.assertIn('<h3>riptide</h3>', new)
        self.assertIn(build_pages.SUITE_ICON, new)
        self.assertIn('<p class="what">%s</p>' % build_pages.html.escape(build_pages.SUITE_UNREAD), new)
        self.assertIn('<a class="file" href="%sriptide-0.3.0.lce" download>' % DOWNLOAD, new)
        self.assertIn('riptide <small>0.3.0</small>', new)
        self.assertIn('<a class="file ghost" href="%sriptide-kit-0.3.0.lce" download>' % DOWNLOAD, new)
        self.assertIn('Kit <small>0.3.0</small>', new)
        self.assertIn('<a class="source" href="%s/tree/%s/riptide">Guide and source</a>' % (SUITE, TAG), new)
        self.assertNotIn('id="more-packages"', text)

    def test_its_id_is_its_own(self):
        # a member named like a part of the page takes another id
        shown, text, page = self.build(TAG, ASSETS + ['installing-1.0.0.lce'])
        self.assertIn('<article class="ext" id="suite-installing">', text)
        self.assertEqual(text.count('id="installing"'), 1)

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

    def test_what_is_built_in(self):
        built_in = [('0.2.7', {'sodiumxt', 'coinxt'}), ('0.2.8-dp.2.1', {'sodiumxt', 'coinxt', 'curlxt'})]
        shown, text, page = self.build(TAG, ASSETS + ['lightxt-1.0.0.lce'], built_in=built_in)
        self.assertIn('<p class="built">Built into OXT-Beyond 0.2.7</p>', card(text, 'sodiumxt'))
        self.assertIn('<p class="built">Built into OXT-Beyond 0.2.8-dp.2.1</p>', card(text, 'curlxt'))
        for member in ('pdfxt', 'lightxt'):
            self.assertIn('<p class="built no">Not built into OXT-Beyond 0.2.8-dp.2.1: install its package there '
                          'too</p>', card(text, member))
        # (the plugins' section says they are built in)
        for ident in ('xtalk-assistant', 'mcp-bridge'):
            self.assertNotIn('class="built', card(text, ident))
        # and nothing of it without a release's list
        shown, text, page = self.build(TAG, ASSETS)
        self.assertNotIn('class="built', text)
        self.assertIn('so there is nothing to install there.', text)


class ACardFromItsPackages(unittest.TestCase):
    """The card of a member the table does not name, from the release's
    own packages as pages.yml downloads them."""

    def setUp(self):
        self.work = tempfile.mkdtemp(prefix='test-pages-extensions-packages-')
        self.folder = os.path.join(self.work, 'suite-lce')
        os.makedirs(self.folder)

    def tearDown(self):
        shutil.rmtree(self.work, ignore_errors=True)

    def release(self):
        """lightxt, a native library with a Kit that needs it, and SodiumXT,
        which the Kit needs too."""
        f = self.folder
        return [
            package(f, 'lightxt-1.0.0.lce', manifest('org.openxtalk.library.light', 'Stage Lights for OpenXTalk'),
                    lcdoc('org.openxtalk.library.light', 'Dims the lights over <lxSend> DMX:\nthe `universe` you '
                          'name, at up to 44 frames a second.'), native=True, lcm=True),
            package(f, 'lightxt-kit-1.0.0.lce',
                    manifest('lightxt-kit', 'lightxt Kit', ['org.openxtalk.library.light', 'org.openxtalk.library.sodium']),
                    lcdoc('lightxt-kit', 'Scenes and fades.', key='Description')),
            package(f, 'sodiumxt-0.1.0.lce', manifest('org.openxtalk.library.sodium', 'SodiumXT'), native=True,
                    lcm=True),
        ]

    def facts(self, names):
        log = io.StringIO()
        with redirect_stdout(log):
            found = build_pages.suite_package_facts(self.folder, names)
        return found, log.getvalue()

    def page(self, facts, assets):
        out = os.path.join(self.work, 'site-%d' % len(os.listdir(self.work)))
        build_pages.extensions_page(os.path.join(PAGES, 'extensions'), out, TAG, set(assets), None, (), facts)
        with open(os.path.join(out, 'index.html'), encoding='utf-8') as f:
            text = f.read()
        self.assertEqual(parse(text).errors, [])
        return text

    def test_what_it_says(self):
        names = self.release()
        sums(self.folder, names)
        facts, log = self.facts(names)
        self.assertEqual(log, '')
        self.assertEqual(facts['lightxt-1.0.0.lce'],
                         {'id': 'org.openxtalk.library.light', 'title': 'Stage Lights for OpenXTalk', 'requires': [],
                          'kind': 'native', 'about': 'Dims the lights over lxSend DMX: the universe you name, at up '
                                                     'to 44 frames a second.'})
        self.assertEqual(facts['lightxt-kit-1.0.0.lce']['kind'], 'script')
        self.assertEqual(facts['lightxt-kit-1.0.0.lce']['requires'],
                         ['org.openxtalk.library.light', 'org.openxtalk.library.sodium'])
        text = self.page(facts, ASSETS + ['lightxt-1.0.0.lce', 'lightxt-kit-1.0.0.lce'])
        light = card(text, 'lightxt')
        self.assertIn('<h3>lightxt</h3><p class="kind">Native library · Stage Lights</p>', light)
        self.assertIn('<p class="what">Dims the lights over lxSend DMX: the universe you name, at up to 44 frames a '
                      'second.</p>', light)
        # what it needs of another member, by that member's name
        self.assertIn('<p class="needs">Needs SodiumXT</p>', light)
        self.assertLess(light.index('lightxt-1.0.0.lce'), light.index('lightxt-kit-1.0.0.lce'))
        self.assertIn('Kit <small>1.0.0</small>', light)

    def test_an_xtalk_builder_library_and_one_it_cannot_place(self):
        f = self.folder
        names = [package(f, 'dmxxt-0.1.0.lce', manifest('org.x.dmx', 'DMX', ['org.elsewhere.thing']),
                         lcdoc('org.x.dmx', 'Plain levels.'), lcm=True)]
        sums(f, names)
        facts, log = self.facts(names)
        text = self.page(facts, ASSETS + names)
        dmx = card(text, 'dmxxt')
        self.assertIn('<p class="kind">xTalk Builder library · DMX</p>', dmx)
        self.assertIn('<p class="needs">Needs org.elsewhere.thing</p>', dmx)

    def test_only_what_the_checksums_vouch_for(self):
        names = self.release()
        sums(self.folder, names)
        # a package changed after its checksum was taken is not read
        with zipfile.ZipFile(os.path.join(self.folder, 'lightxt-1.0.0.lce'), 'a') as z:
            z.writestr('extra.txt', 'changed')
        facts, log = self.facts(names)
        self.assertNotIn('lightxt-1.0.0.lce', facts)
        self.assertIn('lightxt-1.0.0.lce is not the file SHA256SUMS lists, so its card says less', log)
        self.assertIn('lightxt-kit-1.0.0.lce', facts)
        text = self.page(facts, ASSETS + ['lightxt-1.0.0.lce', 'lightxt-kit-1.0.0.lce'])
        light = card(text, 'lightxt')
        self.assertIn('<p class="what">%s</p>' % build_pages.html.escape(build_pages.SUITE_UNREAD), light)
        self.assertIn('<p class="kind">xTalk Suite extension</p>', light)
        # one the checksums do not list, or one not downloaded
        facts, log = self.facts(['lightxt-2.0.0.lce'])
        self.assertEqual(facts, {})
        self.assertIn('lightxt-2.0.0.lce is not in SHA256SUMS', log)
        with open(os.path.join(self.folder, 'SHA256SUMS'), 'a', encoding='utf-8') as g:
            g.write('%s  lightxt-3.0.0.lce\n' % ('0' * 64))
        facts, log = self.facts(['lightxt-3.0.0.lce'])
        self.assertIn('lightxt-3.0.0.lce is not downloaded', log)
        # and without SHA256SUMS, none
        os.remove(os.path.join(self.folder, 'SHA256SUMS'))
        facts, log = self.facts(names)
        self.assertEqual(facts, {})
        self.assertIn('has no SHA256SUMS, so none of them is read', log)

    def test_one_it_cannot_read(self):
        f = self.folder
        with open(os.path.join(f, 'brokenxt-1.0.0.lce'), 'wb') as g:
            g.write(b'not a zip at all')
        names = ['brokenxt-1.0.0.lce',
                 package(f, 'noidxt-1.0.0.lce', '<package><title>No id</title></package>'),
                 package(f, 'badxmlxt-1.0.0.lce', '<package><name>x</name>'),
                 package(f, 'nomanifestxt-1.0.0.lce', '<package/>')]
        with zipfile.ZipFile(os.path.join(f, 'nomanifestxt-1.0.0.lce'), 'w') as z:
            z.writestr('api.lcdoc', lcdoc('x', 'y'))
        sums(f, names)
        facts, log = self.facts(names)
        self.assertEqual(facts, {})
        for name in names:
            self.assertIn('%s is not readable (' % name, log)
        text = self.page(facts, ASSETS + names)
        for name in names:
            self.assertIn(build_pages.html.escape(build_pages.SUITE_UNREAD), card(text, name.split('-')[0]))

    def test_no_more_than_the_limit(self):
        f = self.folder
        names = [package(f, 'bigxt-1.0.0.lce', manifest('org.x.big', 'Big'), lcdoc('org.x.big', 'x' * 5000))]
        sums(f, names)
        limit = build_pages.SUITE_PART_LIMIT
        build_pages.SUITE_PART_LIMIT = 1000
        try:
            facts, log = self.facts(names)
        finally:
            build_pages.SUITE_PART_LIMIT = limit
        self.assertEqual(facts, {})
        self.assertIn('bigxt-1.0.0.lce is not readable (its api.lcdoc is', log)

    def test_what_it_says_is_text(self):
        # a package's words are escaped like any other text: nothing in
        # them becomes markup on the page
        f = self.folder
        hostile = '<script>alert(1)</script><img src=x onerror=alert(2)>"\'&'
        names = [package(f, 'evilxt-1.0.0.lce', manifest('org.x.evil', 'evilxt: ' + hostile, ['"><b>x</b>']),
                         lcdoc('org.x.evil', hostile), lcm=True),
                 package(f, 'evilxt-kit-1.0.0.lce', manifest('org.x.evil.kit', hostile, ['org.x.evil']))]
        sums(f, names)
        facts, log = self.facts(names)
        self.assertEqual(sorted(facts), sorted(names))
        text = self.page(facts, ASSETS + names)
        evil = card(text, 'evilxt')
        self.assertNotIn('<script', evil)
        self.assertNotIn('<img', evil)
        self.assertNotIn('<b>', evil)
        self.assertIn('&lt;script&gt;', evil)
        self.assertIn('Needs &quot;&gt;&lt;b&gt;x&lt;/b&gt;', evil)
        page = parse(text)
        self.assertEqual(page.loads, ['../brand/icon.svg', '../brand/logo.svg', '../brand/logo-animated.svg'])


class TheWholeBuild(unittest.TestCase):
    """Through build(), as pages.yml runs it."""

    def setUp(self):
        self.work = tempfile.mkdtemp(prefix='test-pages-extensions-build-')

    def tearDown(self):
        shutil.rmtree(self.work, ignore_errors=True)

    def write(self, name, lines):
        path = os.path.join(self.work, name)
        with open(path, 'w', encoding='utf-8') as f:
            f.write('\n'.join(lines) + '\n')
        return path

    def test_the_whole_build(self):
        player = os.path.join(self.work, 'OXT-Beyond-9.9.9-web-player.zip')
        with zipfile.ZipFile(player, 'w') as z:
            z.writestr('StackPlayer/index.html', '<!DOCTYPE html><title>Player</title>')
        folder = os.path.join(self.work, 'suite-lce')
        os.makedirs(folder)
        names = [package(folder, 'lightxt-1.0.0.lce', manifest('org.x.light', 'Stage lights for OpenXTalk'),
                         lcdoc('org.x.light', 'Dims the lights.'), native=True)]
        sums(folder, names)
        listing = self.write('suite-assets.txt', ASSETS + names)
        beyond = self.write('beyond-assets.txt', BEYOND_PLUGINS)
        built_in = os.path.join(self.work, 'built-in.json')
        with open(built_in, 'w', encoding='utf-8') as f:
            json.dump({'members': [{'name': 'SodiumXT', 'repository': 'SethMorrowSoftware/SodiumXT'}]}, f)
        out = os.path.join(self.work, 'site')
        args = build_pages.argparse.Namespace(out=out, ide=None, ide_version=None, player=player,
                                              player_version='9.9.9', map=None, map_version=None,
                                              suite_release=TAG, suite_assets=listing, suite_packages=folder,
                                              release=BEYOND_TAG, release_assets=beyond,
                                              release_built_in=built_in)
        with redirect_stdout(io.StringIO()) as log:
            build_pages.build(args)
        self.assertIn('extension packages read: 1\n', log.getvalue())
        with open(os.path.join(out, 'index.html'), encoding='utf-8') as f:
            front = f.read()
        self.assertIn('<a class="button" href="extensions/">See the extensions</a>', front)
        self.assertIn('<p class="version">xTalk Suite %s</p>' % TAG, front)
        with open(os.path.join(out, 'extensions', 'index.html'), encoding='utf-8') as f:
            text = f.read()
        self.assertIn(DOWNLOAD + 'nostrxt-relay-0.1.0.lce', text)
        self.assertIn(BEYOND_DOWNLOAD + BEYOND_PLUGINS[1], text)
        self.assertIn('<p class="what">Dims the lights.</p>', card(text, 'lightxt'))
        self.assertIn('<p class="built">Built into OXT-Beyond 0.2.7-rc.6.14</p>', card(text, 'sodiumxt'))
        self.assertIn('<p class="built no">Not built into OXT-Beyond 0.2.7-rc.6.14', card(text, 'lightxt'))
        # each option needs the one it belongs to
        for option, value, needs in (('suite_assets', None, 'suite-assets'),
                                     ('suite_release', None, 'suite-release'),
                                     ('release', None, '--release')):
            shutil.rmtree(out, ignore_errors=True)
            kept = getattr(args, option)
            setattr(args, option, value)
            if option == 'release':
                args.release_assets = None
            with self.assertRaisesRegex(build_pages.BuildError, needs), redirect_stdout(io.StringIO()):
                build_pages.build(args)
            setattr(args, option, kept)
            args.release_assets = beyond
        # and the preview's list of what it has built in, after the
        # stable release's
        preview = self.write('preview-assets.txt', ['OXT-Beyond-0.2.8-dp.2.1-win-x86_64-setup.exe'])
        preview_built_in = os.path.join(self.work, 'preview-built-in.json')
        with open(preview_built_in, 'w', encoding='utf-8') as f:
            json.dump({'members': [{'name': 'SodiumXT'}, {'name': 'lightxt'}]}, f)
        args.release, args.release_assets = 'v0.2.7', self.write('stable-assets.txt', ['OXT-Beyond-0.2.7-win-x86_64-setup.exe'])
        args.preview, args.preview_assets, args.preview_built_in = 'v0.2.8-dp.2.1', preview, preview_built_in
        shutil.rmtree(out, ignore_errors=True)
        with redirect_stdout(io.StringIO()):
            build_pages.build(args)
        with open(os.path.join(out, 'extensions', 'index.html'), encoding='utf-8') as f:
            text = f.read()
        self.assertIn('<p class="built">Built into OXT-Beyond 0.2.7</p>', card(text, 'sodiumxt'))
        self.assertIn('<p class="built">Built into OXT-Beyond 0.2.8-dp.2.1</p>', card(text, 'lightxt'))
        self.assertIn('<p class="built no">Not built into OXT-Beyond 0.2.8-dp.2.1', card(text, 'pdfxt'))


class TheWorkflow(unittest.TestCase):
    """pages.yml finds the suite's newest release with .lce files and
    hands its files to build_pages.py, with the packages themselves for
    the cards the table does not write, and each offered OXT-Beyond
    release's own list of what it has built in; a failure leaves the page
    without them, with a warning, and never stops the site."""

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

    def test_it_downloads_the_packages(self):
        step = self.text[self.text.index('- name: The xTalk Suite release with packages'):]
        step = step[:step.index('- name:', 10)]
        self.assertIn('gh release download "$tag" --repo SethMorrowSoftware/xtalk-suite --pattern \'*.lce\' \\\n'
                      '                   --pattern SHA256SUMS --dir "$RUNNER_TEMP/suite-lce"', step)
        self.assertIn('echo "SUITE_LCE=$RUNNER_TEMP/suite-lce" >> "$GITHUB_ENV"', step)
        self.assertIn('::warning::could not download the packages', step)
        build = self.text[self.text.index('- name: Build the site'):]
        self.assertIn('args+=(--suite-packages "$SUITE_LCE")', build)

    def test_it_gives_what_each_release_has_built_in(self):
        build = self.text[self.text.index('- name: Build the site'):]
        build = build[:build.index('python3 tools/pages/build_pages.py')]
        for tag, option, name in (('DOWNLOADS_TAG', '--release-built-in', 'release-built-in.json'),
                                  ('PREVIEW_TAG', '--preview-built-in', 'preview-built-in.json')):
            self.assertIn('git show "refs/tags/$%s:tools/oxt/xtalk-extensions.json" > "$RUNNER_TEMP/%s"; then'
                          % (tag, name), build)
            self.assertIn('args+=(%s "$RUNNER_TEMP/%s")' % (option, name), build)
        # the tags are in the checkout
        self.assertIn('fetch-depth: 0', self.text)

    def test_the_summary_says_where_the_packages_are(self):
        self.assertIn('- Extensions:', self.text)


if __name__ == '__main__':
    unittest.main()
