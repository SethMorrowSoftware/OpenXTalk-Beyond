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
anchors, to the project on GitHub and to the files its releases have (the
Downloads section: the stable release and the preview of the next one,
which tools/pages/pick_releases.py chooses); it leaves no marker or
placeholder behind; and it asks no other host for anything (no script,
style, font or image from elsewhere). tools/pages/check_front_page.py
reads the same page in a browser.

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
import pick_releases  # noqa: E402

FOLDERS = {'GAMES': 'games/', 'IDE': 'ide/', 'DICTIONARY': 'dictionary/', 'PLAYER': 'player/', 'MAP': 'map/',
           'EXTENSIONS': 'extensions/', 'LESSONS': 'lessons/'}
# The links the page may make to other hosts
EXTERNAL = {
    'https://github.com/SethMorrowSoftware/OpenXTalk-Beyond',
    'https://github.com/SethMorrowSoftware/OpenXTalk-Beyond/releases',
    'https://github.com/SethMorrowSoftware/OpenXTalk-Beyond/issues/new?template=bug_report.yml',
}
TAG = 'v0.2.7-rc.6.11'


def files_of(tag):
    """A release's files, as gh release view lists them."""
    return ['OXT-Beyond-%s-%s' % (tag[1:], s) for s in (
        'linux-arm64-binaries.tar.xz', 'linux-arm64-symbols.tar.xz', 'linux-arm64.tar.xz',
        'linux-x86_64-binaries.tar.xz', 'linux-x86_64-symbols.tar.xz', 'linux-x86_64.tar.xz',
        'mac-universal-binaries.tar.xz', 'mac-universal-symbols.zip', 'mac-universal.dmg', 'mac-universal.zip',
        'mcp-bridge-plugin.lce', 'web-ide.zip', 'web-player.zip', 'win-x86_64-binaries.zip',
        'win-x86_64-portable.zip', 'win-x86_64-setup.exe', 'win-x86_64-symbols.zip',
        'xtalk-assistant-plugin.lce', 'xtalk-sources.zip')] + ['SHA256SUMS']


ASSETS = files_of(TAG)
# The stable release and the preview of the next one, side by side
STABLE, PREVIEW = 'v0.2.7', 'v0.2.8-dp.1'
# The files the Downloads section links, by the end of their names
LINKED = ('win-x86_64-setup.exe', 'win-x86_64-portable.zip', 'mac-universal.dmg', 'mac-universal.zip',
          'linux-x86_64.tar.xz', 'linux-arm64.tar.xz', 'web-ide.zip', 'web-player.zip',
          'xtalk-assistant-plugin.lce', 'mcp-bridge-plugin.lce')
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
        # (moving, and still in the first card until it is pointed at)
        page = parse(self.text)
        self.assertEqual(sorted(set(page.loads)), ['brand/icon.svg', 'brand/logo-animated.svg', 'brand/logo.svg'])
        for name in page.loads:
            self.assertIn(name[len('brand/'):], build_pages.BRAND)
        self.assertNotRegex(self.text, r'url\(\s*["\']?(https?:)?//')
        self.assertNotRegex(self.text, r'@import')


    def test_the_logo(self):
        # The logo in the hero, still and moving (the moving one for the
        # page's first seconds and while the stack window is pointed at;
        # never for less motion), the small one as the favicon, and the
        # banner for link previews: each a file the site has. Its words are
        # the hero's own, so a screen reader has them whichever one shows
        self.assertIn('<span class="hero-logo" role="img" '
                      'aria-label="The OXT-Beyond logo: OXT struck by lightning">', self.text)
        hero = self.text[self.text.index('<span class="hero-logo"'):]
        hero = hero[:hero.index('</span>')]
        self.assertIn('<img class="still" src="brand/logo.svg" alt="" width="132" height="132">', hero)
        self.assertIn('<img class="moving" src="brand/logo-animated.svg" alt="" width="132" height="132">', hero)
        self.assertIn('.hero-logo .moving { display: none !important; }',
                      self.text[self.text.index('@media (prefers-reduced-motion: reduce)'):])
        self.assertIn('<link rel="icon" type="image/svg+xml" href="brand/icon.svg">', self.text)
        # It lies over the stack window's corner, so clicks go through it
        # to the stack (its answer's OK button is under it on a narrow page)
        css = re.search(r'\.hero-logo \{([^}]*)\}', self.text).group(1)
        self.assertIn('pointer-events: none', css)
        preview = re.search(r'<meta property="og:image" content="([^"]+)">', self.text).group(1)
        self.assertEqual(preview, 'https://sethmorrowsoftware.github.io/OpenXTalk-Beyond/brand/social.png')
        for name in build_pages.BRAND:
            self.assertTrue(os.path.isfile(os.path.join(PAGES, 'brand', name)), name)

    def test_the_parts_in_the_logos_look(self):
        # The Web IDE's card is the wide one with the logo inside the IDE's
        # part, so a site without the IDE loses it with the card: still at
        # rest and moving while the card is pointed at or has the focus
        # (never for less motion); every card has its shine, hidden from
        # screen readers; and every animation stops for less motion
        start, end = self.text.index('<!-- @IDE@ -->\n      <section class="card featured">'), None
        end = self.text.index('<!-- /@IDE@ -->', start)
        ide = self.text[start:end]
        self.assertIn('<img class="still" src="brand/logo.svg" alt=""', ide)
        self.assertIn('<img class="moving" src="brand/logo-animated.svg" alt=""', ide)
        self.assertIn('.feature-logo .moving { display: none; }', self.text)
        self.assertIn('.card.featured:hover .feature-logo .moving, '
                      '.card.featured:focus-within .feature-logo .moving { display: block; }', self.text)
        self.assertIn('.feature-logo .moving { display: none !important; }',
                      self.text[self.text.index('@media (prefers-reduced-motion: reduce)'):])
        self.assertEqual(self.text.count('<section class="card'),
                         self.text.count('<span class="shine" aria-hidden="true"></span>'))
        self.assertIn('*, *::before, *::after { animation: none !important; transition: none !important; }', self.text)
        self.assertIn('Where will you go <span class="flame">Beyond</span>?', self.text)

    def test_the_rims_are_still_at_rest(self):
        # A card's fire rim spins only while the card is pointed at or has
        # the focus: spinning at rest it drew every card again each frame,
        # with the first card's moving logo most of each second of a machine
        # without a GPU (tperry2x, openxtalk.org p=25971). In a browser,
        # tools/pages/check_front_page.py holds the whole page to it
        rim = re.search(r'\n  \.card::before \{([^}]*)\}', self.text).group(1)
        self.assertNotIn('animation', rim)
        self.assertIn('.card:hover::before, .card:focus-within::before '
                      '{ opacity: 1; animation: rim-spin 2.2s linear infinite; }', self.text)

    def test_a_change_to_the_page_is_read_in_a_browser(self):
        # web-ide.yml reads the page in a browser (check_front_page.py): a
        # pull request or push that changes the page, its logo or the check
        # runs it. The page was not in its paths, so its own changes, the
        # spinning rims among them, were never read in a browser before
        # they went up
        with open(os.path.join(REPO, '.github', 'workflows', 'web-ide.yml'), encoding='utf-8') as f:
            workflow = f.read()
        self.assertIn('tools/pages/check_front_page.py \\\n            --site "$RUNNER_TEMP/pages"', workflow)
        for path in ('tools/pages/index.html', 'tools/pages/brand/**', 'tools/pages/check_front_page.py'):
            self.assertEqual(workflow.count('      - %s\n' % path), 2, path)

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


def css_rules(text):
    """Each innermost rule of the page's style sheet, as (selector, body),
    comments left out (a rule inside @media is read with its own selector)."""
    css = text[text.index('<style>'):text.index('</style>')]
    css = re.sub(r'/\*.*?\*/', '', css, flags=re.S)
    return [(m.group(1).strip(), m.group(2)) for m in re.finditer(r'([^{}]+)\{([^{}]*)\}', css)]


class StillAtRest(unittest.TestCase):
    """tperry2x (openxtalk.org p=25971): Firefox's performance monitor
    showed "a noticable CPU and memory drain" on the site's Downloads, with
    a slow machine's fans spinning up. The cards' rims and the first card's
    logo were stilled first (test_the_rims_are_still_at_rest); but in a
    browser without a GPU the page still kept 94% to 168% of a core busy at
    rest, with its memory growing, from what was left moving without end:
    the stars' twinkle over the header and the Downloads (about half a core
    on its own), the header's moving logo (another half), the turning rays
    behind the parts, the flame in their heading and the orbit's dot. Now
    nothing moves without end unless it is pointed at or has the keyboard's
    focus, and the page's opening moves end. tools/pages/check_front_page.py
    measures the browser itself, in Chromium and Firefox."""

    def setUp(self):
        with open(os.path.join(PAGES, 'index.html'), encoding='utf-8') as f:
            self.text = f.read()

    def test_nothing_moves_without_end_at_rest(self):
        endless = [(selector, body) for selector, body in css_rules(self.text)
                   if re.search(r'animation:[^;]*\binfinite\b', body)]
        self.assertTrue(endless)
        for selector, body in endless:
            for part in selector.split(','):
                self.assertRegex(part, r':hover|:focus-within|:has\(:focus-visible\)',
                                 'moves without end at rest: %s { %s }' % (selector, body.strip()))

    def test_the_stars_twinkle_twice_and_rest_where_they_began(self):
        # two alternate runs end where the first began, at the opacity the
        # layers keep, so the stars do not jump when they stop
        self.assertIn('@keyframes twinkle { from { opacity: .6; } to { opacity: 1; } }', self.text)
        rules = dict(css_rules(self.text))
        self.assertIn('opacity: .6; animation: twinkle 4s ease-in-out 2 alternate;', rules['.stars::before'])
        self.assertIn('opacity: .6; animation: twinkle 5s ease-in-out 1.5s 2 alternate;', rules['.stars::after'])

    def test_the_header_logo_moves_as_the_page_opens(self):
        # still at rest; moving while the page has the class "opening",
        # which its script puts on and takes off after 6 seconds, and while
        # the stack window is pointed at or has the keyboard's focus (not
        # :focus-within: "Say hello" keeps the focus after a click); the
        # :has() rules on their own, so a browser without :has() keeps the
        # rest
        rules = css_rules(self.text)
        self.assertIn(('.hero-logo .moving', ' display: none; '), rules)
        self.assertIn(('.opening .hero-logo .moving, .scene:hover .hero-logo .moving', ' display: block; '), rules)
        self.assertIn(('.opening .hero-logo .still, .scene:hover .hero-logo .still', ' display: none; '), rules)
        self.assertIn(('.scene:has(:focus-visible) .hero-logo .moving', ' display: block; '), rules)
        self.assertIn(('.scene:has(:focus-visible) .hero-logo .still', ' display: none; '), rules)
        script = self.text[self.text.index('<script>'):self.text.index('</script>')]
        self.assertIn("root.classList.add('opening');", script)
        self.assertIn("setTimeout(function () { root.classList.remove('opening'); }, 6000);", script)
        self.assertNotIn('class="opening"', self.text)

    def test_the_rays_the_flame_and_the_orbit(self):
        rules = dict(css_rules(self.text))
        self.assertNotIn('animation', rules['.explore::before'])
        self.assertNotIn('rays-turn', self.text)
        self.assertNotIn('animation', rules['.section-head h2 .flame'])
        self.assertIn('animation: flame-flow 6s ease-in-out infinite alternate;', rules['.section-head:hover .flame'])
        self.assertNotIn('animation', rules['.orbit::after'])
        self.assertIn('animation: orbit 14s linear infinite;', rules['.scene:hover .orbit::after'])
        self.assertIn('animation: orbit 14s linear infinite;', rules['.scene:has(:focus-visible) .orbit::after'])


class TheRestCheck(unittest.TestCase):
    """check_front_page.py: what it counts as moving at rest, and how it
    reads the browser's CPU and memory from Linux's /proc."""

    @classmethod
    def setUpClass(cls):
        import check_front_page
        cls.check = check_front_page

    def test_every_property_counts(self):
        # without a GPU the compositor draws too: the stars' twinkle
        # (opacity) and the rays (transform) were let through, and cost the
        # most
        self.assertNotIn("p === 'opacity'", self.check.RESTLESS)
        self.assertNotIn("p === 'transform'", self.check.RESTLESS)
        self.assertIn("document.querySelector('.hero-logo')", self.check.RESTLESS)
        self.assertIn('logo.contains(img)', self.check.RESTLESS)

    def test_the_budgets(self):
        self.assertEqual(self.check.REST_CPU, 0.10)
        self.assertEqual(self.check.REST_GROWTH_MB, 8.0)
        self.assertGreaterEqual(self.check.REST_SECONDS, 10)
        self.assertIn(('the Downloads', '#downloads'), self.check.REST_PLACES)
        self.assertIn(('the top', ''), self.check.REST_PLACES)
        # measured once the page's opening is over and every animation that
        # ends has ended
        self.assertIn("classList.contains('opening')", self.check.SETTLED)
        self.assertIn('iterations === Infinity', self.check.SETTLED)

    def fake_proc(self, processes):
        proc = tempfile.mkdtemp(prefix='test-pages-front-proc-')
        self.addCleanup(shutil.rmtree, proc, ignore_errors=True)
        os.makedirs(os.path.join(proc, 'self'))
        for pid, (name, parent, utime, stime, pss) in processes.items():
            folder = os.path.join(proc, str(pid))
            os.makedirs(folder)
            fields = ['S', str(parent)] + ['0'] * 9 + [str(utime), str(stime)] + ['0'] * 8
            with open(os.path.join(folder, 'stat'), 'w') as f:
                f.write('%d (%s) %s\n' % (pid, name, ' '.join(fields)))
            if pss is None:
                # no smaps_rollup: its resident set, from statm (in pages)
                with open(os.path.join(folder, 'statm'), 'w') as f:
                    f.write('1000 256 0 0 0 0 0\n')
            else:
                with open(os.path.join(folder, 'smaps_rollup'), 'w') as f:
                    f.write('00400000-7fff [rollup]\nRss: %d kB\nPss: %d kB\n' % (pss * 2, pss))
        return proc

    def test_the_browsers_processes(self):
        # (given, not asked of the system: Windows has no os.sysconf)
        tick, page = 100, 4096
        proc = self.fake_proc({
            10: ('python3', 1, 0, 0, 0),
            11: ('node', 10, tick, 0, 2048),
            12: ('firefox', 11, 2 * tick, tick, 4096),
            # a name with a space and a bracket, as a browser's helpers have
            13: ('Web Content) x', 12, tick, tick, None),
            20: ('other', 1, 50 * tick, 0, 9999),
        })
        self.assertEqual(sorted(self.check.descendants(10, proc=proc)), [11, 12, 13])
        self.assertEqual(self.check.descendants(13, proc=proc), [])
        cpu, mb = self.check.usage([11, 12, 13], proc=proc, tick=tick, page=page)
        self.assertAlmostEqual(cpu, 6.0)
        self.assertAlmostEqual(mb, (2048 + 4096 + 256 * page // 1024) / 1024.0)
        # a process that ended between the list and the read is left out
        self.assertEqual(self.check.usage([11, 99], proc=proc, tick=tick, page=page), (1.0, 2.0))

    def test_at_rest(self):
        cpu, grown = self.check.at_rest((1.0, 500.0), (1.5, 504.0), 10.0)
        self.assertAlmostEqual(cpu, 0.05)
        self.assertAlmostEqual(grown, 4.0)

    def test_in_firefox_too(self):
        # tperry2x saw it in Firefox; web-ide.yml reads the page in both
        with open(os.path.join(REPO, '.github', 'workflows', 'web-ide.yml'), encoding='utf-8') as f:
            workflow = f.read()
        self.assertIn('-m playwright install --with-deps chromium firefox', workflow)
        # run whether or not Chromium's check passed
        self.assertIn("      - name: The site's front page in Firefox\n        if: ${{ !cancelled() }}\n", workflow)
        self.assertIn('tools/pages/check_front_page.py --browser firefox \\\n'
                      '            --site "$RUNNER_TEMP/pages"', workflow)


class TheBuiltPage(unittest.TestCase):

    def setUp(self):
        self.work = tempfile.mkdtemp(prefix='test-pages-front-')

    def tearDown(self):
        shutil.rmtree(self.work, ignore_errors=True)

    def build(self, parts, assets=ASSETS, release=TAG, preview=None):
        """The front page with parts; its Downloads are those of release
        (a tag, with the files assets) and of preview (a tag, with every
        file a release has), either of them None for a page without it."""
        out = os.path.join(self.work, '-'.join(sorted(parts)) or 'none')
        shutil.rmtree(out, ignore_errors=True)
        os.makedirs(out)
        for key in parts:
            if key in FOLDERS:
                os.makedirs(os.path.join(out, FOLDERS[key]))
        if 'DOWNLOADS' in parts:
            blocks = build_pages.downloads_channels((release, set(assets)) if release else None,
                                                    (preview, set(files_of(preview))) if preview else None)
            parts = dict(parts, DOWNLOADS=' and '.join(tag for tag, _ in blocks),
                         DOWNLOADS_LIST='\n'.join(block for _, block in blocks))
        build_pages.front_page(out, parts)
        with open(os.path.join(out, 'index.html'), encoding='utf-8') as f:
            return out, f.read()

    def check(self, parts, assets=ASSETS, release=TAG, preview=None):
        out, text = self.build(parts, assets, release, preview)
        where = 'parts %s' % sorted(parts)
        # each release on the page, with the files it has
        has = {release: assets} if release else {}
        if preview:
            has[preview] = files_of(preview)
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
                self.assertIn(tag, has, where)
                self.assertIn(name, has[tag], where)
            elif href.startswith(RELEASE + 'tag/'):
                self.assertIn(href[len(RELEASE + 'tag/'):], has, where)
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
                              ('Open the Stack Player', 'player/'), ('Open the codebase map', 'map/'),
                              ('See the extensions', 'extensions/'), ('Open the lessons', 'lessons/')):
            self.assertIn('<a class="button" href="%s">%s</a>' % (folder, label), text)

    def test_the_downloads(self):
        text = self.check({'IDE': '9', 'DOWNLOADS': TAG})
        for name in LINKED:
            self.assertIn('href="%sdownload/%s/OXT-Beyond-0.2.7-rc.6.11-%s"' % (RELEASE, TAG, name), text)
        # (debug symbols and build output are for the release page)
        self.assertNotIn('symbols', text)
        self.assertIn('href="%stag/%s"' % (RELEASE, TAG), text)
        self.assertIn('<span class="release">%s</span>' % TAG, text)

    def blocks(self, text):
        """The Downloads section's releases, in the page's order, as
        (id, heading, tag, the block's text)."""
        found = []
        for part in re.split(r'<div class="channel(?: next)?" (?=id=")', text)[1:]:
            ident = re.match(r'id="([^"]+)"', part).group(1)
            heading = re.search(r'<h3>([^<]+)</h3>', part).group(1)
            tag = re.search(r'<span class="release">([^<]+)</span>', part).group(1)
            found.append((ident, heading, tag, part))
        return found

    def test_the_stable_release_and_the_preview(self):
        # seth, 2026-11-10: "the website downloads should always show the
        # current GM/stable and the current RC/DP so users have a choice".
        # The stable release first, then the preview, each with its own
        # files and its own release page, and its own place to link
        text = self.check({'IDE': '9', 'DOWNLOADS': ''}, files_of(STABLE), STABLE, PREVIEW)
        blocks = self.blocks(text)
        self.assertEqual([b[:3] for b in blocks], [('downloads-stable', 'Stable release', STABLE),
                                                   ('downloads-preview', 'Developer preview', PREVIEW)])
        for (_, _, tag, block), other in zip(blocks, (PREVIEW, STABLE)):
            for name in LINKED:
                self.assertIn('href="%sdownload/%s/OXT-Beyond-%s-%s"' % (RELEASE, tag, tag[1:], name), block)
            self.assertIn('href="%stag/%s"' % (RELEASE, tag), block)
            # (nothing of the other release in this one's block)
            self.assertNotIn('/%s/' % other, block)
            self.assertNotIn('tag/%s"' % other, block)
        self.assertEqual(text.count('releases/download/'), 2 * len(LINKED))
        # the preview says what it is before anyone takes it for the release
        self.assertIn('less tested than the stable release', blocks[1][3])
        self.assertNotIn('less tested', blocks[0][3])

    def test_one_release_alone(self):
        # no preview newer than the stable release (the day a release is
        # made), and a project whose every release so far is a preview
        text = self.check({'DOWNLOADS': ''}, files_of(STABLE), STABLE)
        self.assertEqual([b[:3] for b in self.blocks(text)], [('downloads-stable', 'Stable release', STABLE)])
        section = text[text.index('<section id="downloads"'):]
        self.assertNotIn('preview', section[:section.index('</section>')].lower())
        text = self.check({'DOWNLOADS': ''}, release=None, preview=PREVIEW)
        self.assertEqual([b[:3] for b in self.blocks(text)], [('downloads-preview', 'Developer preview', PREVIEW)])
        text = self.check({'DOWNLOADS': ''})
        self.assertEqual([b[:3] for b in self.blocks(text)], [('downloads-preview', 'Release candidate', TAG)])

    def test_what_a_release_is_called(self):
        for tag, name in (('v0.2.7', 'Stable release'), ('v1.0', 'Stable release'),
                          ('v0.2.8-dp.1', 'Developer preview'), ('v0.2.8-DP.12', 'Developer preview'),
                          ('v0.2.7-rc.6.11', 'Release candidate'), ('v0.2.8-rc1', 'Release candidate'),
                          ('v0.3.0-beta.2', 'Preview'), ('v0.3.0-7', 'Preview')):
            self.assertEqual(build_pages.CHANNELS[build_pages.channel(tag)][0], name, tag)
        # what GitHub marks as a pre-release is one whatever its name
        self.assertEqual(build_pages.CHANNELS[build_pages.channel('v0.3.0', preview=True)][0], 'Preview')
        self.assertEqual(build_pages.channel('v0.2.8-dp.1', preview=True), 'dp')

    def test_a_release_without_the_files_is_left_out(self):
        # the other one still has its block; with neither, no section
        full, none = set(files_of(STABLE)), {'SHA256SUMS'}
        log = io.StringIO()
        with redirect_stdout(log):
            self.assertEqual([t for t, _ in build_pages.downloads_channels((STABLE, full), (PREVIEW, none))],
                             [STABLE])
            self.assertEqual(log.getvalue(), 'no downloads of %s: it has none of the files the page links\n' % PREVIEW)
            self.assertEqual([t for t, _ in build_pages.downloads_channels((STABLE, none),
                                                                           (PREVIEW, set(files_of(PREVIEW))))],
                             [PREVIEW])
            self.assertEqual(build_pages.downloads_channels((STABLE, none), (PREVIEW, none)), [])
        self.assertEqual(build_pages.downloads_channels(None, None), [])

    def test_two_previews_are_not_two_releases(self):
        # each block has its own id, so a preview is never given as both
        with self.assertRaisesRegex(build_pages.BuildError, 'preview'):
            build_pages.downloads_channels((TAG, set(ASSETS)), (PREVIEW, set(files_of(PREVIEW))))

    def test_only_the_files_the_release_has(self):
        assets = [a for a in ASSETS if 'mac-' not in a and not a.endswith('-portable.zip')]
        text = self.check({'DOWNLOADS': TAG}, assets)
        self.assertNotIn('<h4>macOS</h4>', text)
        self.assertNotIn('portable', text)
        self.assertIn('<h4>Windows</h4>', text)
        # a platform's heading is under its release's
        self.assertNotIn('<h3>Windows</h3>', text)

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
        # the extensions page goes up with every site, its card with it;
        # without a suite release it links no package
        self.assertIn('href="extensions/"', text)
        self.assertIn('<p class="version">xTalk Suite</p>', text)
        with open(os.path.join(out, 'extensions', 'index.html'), encoding='utf-8') as f:
            self.assertNotIn('.lce"', f.read())

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

        # and with the stable release and the preview, as pages.yml gives
        # them: both on the front page, and the extensions page's plugins
        # from the stable one
        def listed(tag):
            path = os.path.join(self.work, 'assets-%s.txt' % tag)
            with open(path, 'w', encoding='utf-8') as f:
                f.write('\n'.join(files_of(tag)) + '\n')
            return path

        def built():
            shutil.rmtree(out, ignore_errors=True)
            log = io.StringIO()
            with redirect_stdout(log):
                build_pages.build(args)
            with open(os.path.join(out, 'index.html'), encoding='utf-8') as f, \
                    open(os.path.join(out, 'extensions', 'index.html'), encoding='utf-8') as g:
                return f.read(), g.read(), log.getvalue()

        args.release, args.release_assets = STABLE, listed(STABLE)
        args.preview, args.preview_assets = PREVIEW, listed(PREVIEW)
        text, extensions, log = built()
        self.assertIn('OXT-Beyond-0.2.7-win-x86_64-setup.exe', text)
        self.assertIn('OXT-Beyond-0.2.8-dp.1-win-x86_64-setup.exe', text)
        self.assertLess(text.index('id="downloads-stable"'), text.index('id="downloads-preview"'))
        self.assertIn('downloads: %s and %s\n' % (STABLE, PREVIEW), log)
        self.assertIn('/%s/OXT-Beyond-0.2.7-mcp-bridge-plugin.lce"' % STABLE, extensions)
        self.assertNotIn(PREVIEW, extensions)
        # the preview alone: its files, on both pages
        args.release = args.release_assets = None
        text, extensions, log = built()
        self.assertNotIn('id="downloads-stable"', text)
        self.assertIn('OXT-Beyond-0.2.8-dp.1-win-x86_64-setup.exe', text)
        self.assertIn('/%s/OXT-Beyond-0.2.8-dp.1-mcp-bridge-plugin.lce"' % PREVIEW, extensions)
        shutil.rmtree(out)
        args.preview_assets = None
        with self.assertRaisesRegex(build_pages.BuildError, 'preview-assets'):
            build_pages.build(args)


def release(tag, prerelease=None):
    """A row of gh release list --json tagName,isPrerelease."""
    return {'tagName': tag, 'isPrerelease': ('-' in tag) if prerelease is None else prerelease}


class TheReleasesToOffer(unittest.TestCase):
    """tools/pages/pick_releases.py: which releases the Downloads section
    links, from GitHub's list of them."""

    def pick(self, *tags):
        return pick_releases.pick([t if isinstance(t, dict) else release(t) for t in tags])

    def test_the_stable_release_and_a_newer_preview(self):
        # (the list is newest first, as gh gives it; the runtimes asset's
        # release is not one of the IDE)
        self.assertEqual(self.pick('v0.2.8-dp.1', 'oxt-runtimes-0.2.8-dp.1', 'v0.2.7', 'v0.2.7-rc.6.18'),
                         ('v0.2.7', 'v0.2.8-dp.1'))

    def test_a_preview_behind_the_stable_release_is_not_offered(self):
        # today: 0.2.7 is out and its release candidates are behind it
        self.assertEqual(self.pick('oxt-runtimes-0.2.7', 'v0.2.7', 'v0.2.7-rc.6.18', 'v0.2.7-rc.6.17'),
                         ('v0.2.7', ''))
        self.assertEqual(self.pick('v0.2.8', 'v0.2.8-rc.1', 'v0.2.8-dp.3', 'v0.2.7'), ('v0.2.8', ''))

    def test_by_version_not_by_date(self):
        # a fix to the stable release made after the next version's
        # preview leaves that preview on the page
        self.assertEqual(self.pick('v0.2.7.1', 'v0.2.8-dp.2', 'v0.2.8-dp.1', 'v0.2.7'),
                         ('v0.2.7.1', 'v0.2.8-dp.2'))
        # and the list's order decides nothing
        self.assertEqual(self.pick('v0.2.7', 'v0.2.8-dp.1', 'v0.2.8-dp.2', 'v0.2.7.1'),
                         ('v0.2.7.1', 'v0.2.8-dp.2'))

    def test_previews_in_order(self):
        # numbers as numbers, a developer preview before a release
        # candidate, and a longer name after its own beginning
        for newest, older in (('v0.2.8-dp.10', 'v0.2.8-dp.9'), ('v0.2.8-rc.1', 'v0.2.8-dp.12'),
                              ('v0.2.7-rc.6.11', 'v0.2.7-rc.6.9'), ('v0.2.7-rc.6.1', 'v0.2.7-rc.6'),
                              ('v0.2.10-dp.1', 'v0.2.9-rc.4'), ('v0.3.0-dp.1', 'v0.2.99-rc.9')):
            self.assertEqual(self.pick(older, newest), ('', newest), newest)
            self.assertEqual(self.pick(newest, older), ('', newest), newest)

    def test_no_stable_release_yet(self):
        self.assertEqual(self.pick('v0.2.7-rc.6.18', 'v0.2.7-rc.6.17'), ('', 'v0.2.7-rc.6.18'))
        self.assertEqual(self.pick(), ('', ''))
        self.assertEqual(self.pick('oxt-runtimes-0.2.7', 'nightly'), ('', ''))

    def test_what_github_marks_decides_with_the_name(self):
        # marked as a pre-release by hand, it is not the stable release;
        # named as one (a version with a pre-release part), it is not either
        self.assertEqual(self.pick(release('v0.3.0', True), 'v0.2.7'), ('v0.2.7', 'v0.3.0'))
        self.assertEqual(self.pick(release('v0.2.8-dp.1', False), 'v0.2.7'), ('v0.2.7', 'v0.2.8-dp.1'))
        # a draft is no release yet (pages.yml leaves them out of the list too)
        self.assertEqual(self.pick(dict(release('v0.2.8'), isDraft=True), 'v0.2.7'), ('v0.2.7', ''))

    def test_the_command(self):
        import json
        import subprocess
        listing = os.path.join(tempfile.mkdtemp(prefix='test-pages-releases-'), 'releases.json')
        self.addCleanup(shutil.rmtree, os.path.dirname(listing), ignore_errors=True)
        with open(listing, 'w', encoding='utf-8') as f:
            json.dump([release(t) for t in ('v0.2.8-dp.1', 'v0.2.7')], f)
        script = os.path.join(PAGES, 'pick_releases.py')
        done = subprocess.run([sys.executable, script, listing], capture_output=True, text=True)
        self.assertEqual((done.returncode, done.stdout), (0, 'stable=v0.2.7\npreview=v0.2.8-dp.1\n'))
        with open(listing, 'w', encoding='utf-8') as f:
            f.write('not json')
        done = subprocess.run([sys.executable, script, listing], capture_output=True, text=True)
        self.assertEqual((done.returncode, done.stdout), (1, ''))
        self.assertIn('pick_releases.py:', done.stderr)

    def test_every_tag_it_picks_is_one_the_page_takes(self):
        for tag in ('v0.2.7', 'v0.2.8-dp.1', 'v0.2.7-rc.6.11', 'v1.0.0+build.5'):
            self.assertIsNotNone(pick_releases.order(tag), tag)
            self.assertNotEqual(build_pages.downloads_html(tag, set(files_of(tag))), '', tag)
        for tag in ('0.2.7', 'v', 'vNext', 'v0.2.7"><script>', 'v0.2.7 ', 'oxt-runtimes-0.2.7', 'v0..7', ''):
            self.assertIsNone(pick_releases.order(tag), tag)

    def test_pages_yml_asks_for_both(self):
        # the site's workflow lists every release, takes the two this
        # picks whatever tag the run was given, and hands both to the page
        with open(os.path.join(REPO, '.github', 'workflows', 'pages.yml'), encoding='utf-8') as f:
            workflow = f.read()
        self.assertIn('--json tagName,isPrerelease > "$RUNNER_TEMP/releases.json"', workflow)
        self.assertIn('python3 tools/pages/pick_releases.py "$RUNNER_TEMP/releases.json"', workflow)
        self.assertIn('args+=(--release "$DOWNLOADS_TAG" --release-assets "$RUNNER_TEMP/release-assets.txt")',
                      workflow)
        self.assertIn('args+=(--preview "$PREVIEW_TAG" --preview-assets "$RUNNER_TEMP/preview-assets.txt")',
                      workflow)
        step = workflow[workflow.index('      - name: List the downloads'):]
        step = step[:step.index('\n      - name: ', 10)]
        self.assertNotIn('$TAG', step)
        self.assertNotIn('inputs.tag', step)


if __name__ == '__main__':
    unittest.main()
