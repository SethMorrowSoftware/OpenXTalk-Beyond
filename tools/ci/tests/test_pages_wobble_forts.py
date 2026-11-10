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

"""Wobble Forts' page on the GitHub Pages site (tools/pages/games/wobble-forts).
The game is one of the Stack Player's samples, so the page has no engine
or stack of its own: it plays the sample in the bare player
(play/?play=Wobble%20Forts), in a phone's frame turned on its side on a
computer, first on the page, and on the whole screen on a phone. Its
pictures and font are the game's own files, and its font writes no word
with K or X, which it draws much as it draws H.
tools/pages/check_wobble_forts_page.py plays it in a browser, from
build_player.py --check.

  python3 -m unittest discover -s tools/ci/tests
"""

import os
import re
import sys
import unittest
import urllib.parse

CI = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TOOLS = os.path.dirname(CI)
PAGES = os.path.join(TOOLS, 'pages')
GAMES = os.path.join(PAGES, 'games')
PAGE = os.path.join(GAMES, 'wobble-forts')
GAME = os.path.join(TOOLS, 'web-player', 'wobble-forts')
sys.path.insert(0, PAGES)
sys.path.insert(0, os.path.join(TOOLS, 'web-player'))

import build_pages  # noqa: E402
import build_player  # noqa: E402
import check_wobble_forts_page  # noqa: E402

PICTURES = ('logo-wobble.png', 'logo-forts.png', 'bloop-yellow.png', 'bloop-blue.png', 'bloop-pink.png',
            'bloop-green.png', 'bloop-beige.png', 'grump-green.png', 'boss-pink.png', 'wood-cube-whole.png',
            'glass-cube-whole.png', 'stone-cube-whole.png', 'metal-cube-whole.png', 'tnt-cube-whole.png',
            'star-gold.png')


def read(*path):
    with open(os.path.join(*path), encoding='utf-8') as f:
        return f.read()


def data(*path):
    with open(os.path.join(*path), 'rb') as f:
        return f.read()


def words(html):
    return re.sub(r'\s+', ' ', re.sub(r'<[^>]+>', ' ', html)).strip()


class WobbleFortsPage(unittest.TestCase):
    def setUp(self):
        self.page = read(PAGE, 'index.html')

    def test_it_is_a_player_sample_with_a_page_of_its_own(self):
        self.assertEqual(build_pages.OWN_PAGES.get('Wobble Forts'), 'wobble-forts')
        listed = {s['title']: s for s in build_player.SAMPLES}
        self.assertIn('Wobble Forts', listed)
        self.assertTrue(listed['Wobble Forts'].get('image'))
        self.assertFalse(listed['Wobble Forts'].get('featured'))
        self.assertEqual(check_wobble_forts_page.FOLDER, 'wobble-forts')

    def test_it_plays_the_sample_in_the_bare_player(self):
        play = '../../play/?play=%s&bg=%%23d0f4f7' % urllib.parse.quote('Wobble Forts')
        self.assertIn("var PLAY = '%s';" % play, self.page)
        # the links a phone taps, written as HTML
        self.assertEqual(self.page.count('href="%s"' % play.replace('&', '&amp;')), 2)
        self.assertIn('href="../../player/?play=Wobble%20Forts"', self.page)
        # and nothing of its own to run it with
        for name in os.listdir(PAGE):
            self.assertFalse(name.endswith(('.js', '.wasm', '.zip', '.oxtstack')), name)
        self.assertNotIn('@ENGINE_JS@', self.page)
        # the background is the game's sky
        builder = read(TOOLS, 'web-player', 'wobble-forts.livecodescript')
        self.assertIn('set the backgroundColor of card "Fort" to "#D0F4F7"', builder)

    def test_a_phone_loads_no_engine_until_it_plays(self):
        self.assertRegex(self.page, r'<iframe id="game"[^>]*\bhidden\b[^>]*></iframe>')
        self.assertNotRegex(self.page, r'<iframe id="game"[^>]*\bsrc=')
        script = self.page[self.page.index('<script>'):]
        phone = script.index('if (isPhone()) {')
        self.assertLess(phone, script.index('frame.src = PLAY;'))
        self.assertIn('return;', script[phone:script.index('}', phone)])
        self.assertIn("window.matchMedia('(pointer: coarse)').matches && "
                      "Math.min(window.innerWidth, window.innerHeight) <= 600", script)

    def test_the_frame_is_the_stacks_size_first_on_the_page(self):
        builder = read(TOOLS, 'web-player', 'wobble-forts.livecodescript')
        self.assertIn('constant kWidth = 960', builder)
        self.assertIn('constant kHeight = 540', builder)
        self.assertIn('.screen iframe{display:block;width:960px;height:540px;', self.page)
        self.assertEqual(check_wobble_forts_page.STACK, (960, 540))
        main = self.page[self.page.index('<main>'):]
        self.assertLess(main.index('id="device"'), main.index('class="hero'))
        self.assertIn('frame.focus({ preventScroll: true });', self.page)
        self.assertIn('if (canvas) canvas.focus({ preventScroll: true });', self.page)

    def test_the_game_tells_the_page_how_it_is(self):
        builder = read(TOOLS, 'web-player', 'wobble-forts.livecodescript')
        script = read(TOOLS, 'web-player', 'wobble-forts-stack.livecodescript')
        self.assertIn('set the cJavascriptHandlers of stack tName to "wfPageHidden" & return & "wfState"', builder)
        self.assertIn(b'wfPageHidden\nwfState', data(TOOLS, 'web-player', 'stacks', 'Wobble Forts.oxtstack'))
        self.assertIn("findStackWithName('Wobble Forts')", check_wobble_forts_page.FRAME_STATE)
        for key in ('mode', 'window', 'physics', 'font', 'audio', 'library', 'shots'):
            self.assertIn('"%s:"' % key, script)
        self.assertEqual(check_wobble_forts_page.parse_state('mode:title\nwindow:960,540'),
                         {'mode': 'title', 'window': '960,540'})
        # the keys alone reach a fort: Space on the map plays the next
        self.assertRegex(script, r'case "map"\n[^\n]*\n\s*wfPlay wfNextLevel\(\)')

    def test_its_pictures_and_font_are_the_games(self):
        for name in PICTURES:
            self.assertEqual(data(PAGE, name), data(GAME, 'art', name), name)
            self.assertIn('src="%s"' % name, self.page)
        self.assertEqual(data(PAGE, 'kenney_future_narrow.ttf'), data(GAME, 'fonts', 'kenney_future_narrow.ttf'))
        self.assertIn('src:url(kenney_future_narrow.ttf)', self.page)
        for name in ('cover.webp', 'poster.webp'):
            self.assertTrue(os.path.isfile(os.path.join(PAGE, name)), name)
        self.assertIn('url(cover.webp)', self.page)
        # and nothing else
        there = set(os.listdir(PAGE)) - {'index.html', 'cover.webp', 'poster.webp', 'kenney_future_narrow.ttf'}
        self.assertEqual(there, set(PICTURES))

    def test_its_font_writes_no_k_or_x(self):
        css = self.page[self.page.index('<style>'):self.page.index('</style>')]
        users = sorted(m.group(1).strip() for m in re.finditer(r'([^{}]+)\{[^{}]*var\(--future\)[^{}]*\}', css))
        self.assertEqual(users, ['.btn', '.card h3'])
        self.assertRegex(css, r'\.btn\.ghost\{[^}]*font:700 [^}]*system-ui')
        self.assertRegex(css, r'\.made \.card h3\{font:700 [^}]*system-ui')
        texts = re.findall(r'class="btn primary[^"]*"[^>]*>(.*?)</(?:a|span)>', self.page)
        how = self.page[self.page.index('aria-labelledby="how"'):self.page.index('aria-labelledby="made"')]
        texts += re.findall(r'<h3>(.*?)</h3>', how)
        texts = [words(t) for t in texts]
        self.assertGreaterEqual(len(texts), 7)
        for text in texts:
            self.assertNotRegex(text, '[KXkx]', text)
        # the title is the game's pictures of its words
        self.assertIn('src="logo-wobble.png"', self.page)

    def test_the_page_sets_its_own_colours(self):
        self.assertIn('--sky:#d0f4f7', self.page)
        self.assertIn('--edge:#6b4423', self.page)
        self.assertNotIn('prefers-color-scheme', self.page)
        self.assertIn('@media (prefers-reduced-motion:reduce)', self.page)

    def test_the_gallery_lists_it_as_a_big_one(self):
        gallery = read(GAMES, 'index.html')
        start, end = '<!-- @OWN_PAGE:wobble-forts@ -->', '<!-- /@OWN_PAGE:wobble-forts@ -->'
        self.assertEqual(gallery.count(start), 1)
        self.assertEqual(gallery.count(end), 1)
        card = gallery[gallery.index(start):gallery.index(end)]
        self.assertIn('<a class="stack" href="wobble-forts/">', card)
        self.assertIn('src="wobble-forts/poster.webp"', card)
        self.assertLess(gallery.index('id="own-pages"'), gallery.index(start))
        self.assertLess(gallery.index(end), gallery.index('<!-- @PLAYER_SAMPLES@ -->'))

    def test_the_player_check_plays_it(self):
        self.assertIn('check_wobble_forts_page.check_player(p, browser, site,', read(TOOLS, 'web-player', 'build_player.py'))


if __name__ == '__main__':
    unittest.main()
