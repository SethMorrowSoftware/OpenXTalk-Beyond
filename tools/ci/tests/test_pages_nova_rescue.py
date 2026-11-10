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

"""Nova Rescue's page on the GitHub Pages site (tools/pages/games/nova-rescue).
The game is one of the Stack Player's samples, so the page has no engine
or stack of its own: it plays the sample in the bare player
(play/?play=Nova%20Rescue), in a phone's frame on a computer and on the
whole screen on a phone. Its pictures and font are the game's own files,
and its font writes no word with V, K or X, which it draws as U and H.
tools/pages/check_nova_rescue_page.py plays it in a browser, from
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
PAGE = os.path.join(GAMES, 'nova-rescue')
GAME = os.path.join(TOOLS, 'web-player', 'nova-rescue')
sys.path.insert(0, PAGES)
sys.path.insert(0, os.path.join(TOOLS, 'web-player'))

import build_pages  # noqa: E402
import build_player  # noqa: E402
import check_nova_rescue_page  # noqa: E402


def read(*path):
    with open(os.path.join(*path), encoding='utf-8') as f:
        return f.read()


def data(*path):
    with open(os.path.join(*path), 'rb') as f:
        return f.read()


def words(html):
    return re.sub(r'\s+', ' ', re.sub(r'<[^>]+>', ' ', html)).strip()


class NovaRescuePage(unittest.TestCase):
    def setUp(self):
        self.page = read(PAGE, 'index.html')

    def test_it_is_a_player_sample_with_a_page_of_its_own(self):
        self.assertEqual(build_pages.OWN_PAGES.get('Nova Rescue'), 'nova-rescue')
        listed = {s['title']: s for s in build_player.SAMPLES}
        self.assertIn('Nova Rescue', listed)
        self.assertTrue(listed['Nova Rescue'].get('image'))
        self.assertFalse(listed['Nova Rescue'].get('featured'))
        self.assertEqual(check_nova_rescue_page.FOLDER, 'nova-rescue')

    def test_it_plays_the_sample_in_the_bare_player(self):
        play = '../../play/?play=%s&bg=%%233a2e3f' % urllib.parse.quote('Nova Rescue')
        self.assertIn("var PLAY = '%s';" % play, self.page)
        # the links a phone taps, written as HTML
        self.assertEqual(self.page.count('href="%s"' % play.replace('&', '&amp;')), 2)
        self.assertIn('href="../../player/?play=Nova%20Rescue"', self.page)
        # and nothing of its own to run it with
        for name in os.listdir(PAGE):
            self.assertFalse(name.endswith(('.js', '.wasm', '.zip', '.oxtstack')), name)
        self.assertNotIn('@ENGINE_JS@', self.page)

    def test_a_phone_loads_no_engine_until_it_plays(self):
        # the frame has no address in the HTML; the script gives it one
        # only when the window is not a phone's
        self.assertRegex(self.page, r'<iframe id="game"[^>]*\bhidden\b[^>]*></iframe>')
        self.assertNotRegex(self.page, r'<iframe id="game"[^>]*\bsrc=')
        script = self.page[self.page.index('<script>'):]
        phone = script.index('if (isPhone()) {')
        self.assertLess(phone, script.index('frame.src = PLAY;'))
        self.assertIn('return;', script[phone:script.index('}', phone)])
        # the bare player's own test of a phone
        self.assertIn("window.matchMedia('(pointer: coarse)').matches && "
                      "Math.min(window.innerWidth, window.innerHeight) <= 600", script)
        bare = read(TOOLS, 'web-player', 'play.html')
        self.assertIn("window.matchMedia('(pointer: coarse)').matches && "
                      "Math.min(window.innerWidth, window.innerHeight) <= 600", bare)

    def test_the_frame_is_the_stacks_size_and_its_keys_play_at_once(self):
        builder = read(TOOLS, 'web-player', 'nova-rescue.livecodescript')
        self.assertIn('constant kWidth = 390', builder)
        self.assertIn('constant kHeight = 760', builder)
        self.assertIn('.screen iframe{display:block;width:390px;height:760px;', self.page)
        self.assertEqual(check_nova_rescue_page.STACK, (390, 760))
        # once it plays: the frame has the focus, and the engine's canvas in it
        self.assertIn('frame.focus({ preventScroll: true });', self.page)
        self.assertIn('if (canvas) canvas.focus({ preventScroll: true });', self.page)

    def test_the_game_tells_the_page_how_it_is(self):
        builder = read(TOOLS, 'web-player', 'nova-rescue.livecodescript')
        self.assertIn('set the cJavascriptHandlers of stack tName to "nrPageHidden" & return & "nrState"', builder)
        self.assertIn(b'nrPageHidden\nnrState', data(TOOLS, 'web-player', 'stacks', 'Nova Rescue.oxtstack'))
        self.assertIn("findStackWithName('Nova Rescue')", check_nova_rescue_page.FRAME_STATE)
        self.assertEqual(check_nova_rescue_page.parse_state('mode:title\ncolumn:0,0,390,760'),
                         {'mode': 'title', 'column': '0,0,390,760'})
        self.assertEqual(check_nova_rescue_page.rect('0,0,390,760'), [0, 0, 390, 760])
        self.assertIsNone(check_nova_rescue_page.rect('0,0,390'))

    def test_its_pictures_and_font_are_the_games(self):
        for name in ('logo-nova.png', 'ship.png', 'astronaut1.png', 'meteor-big1.png', 'power-twin.png',
                     'power-shield.png', 'power-repair.png', 'star.png', 'mothership.png'):
            self.assertEqual(data(PAGE, name), data(GAME, 'art', name), name)
            self.assertIn('src="%s"' % name, self.page)
        self.assertEqual(data(PAGE, 'kenvector_future.ttf'), data(GAME, 'fonts', 'kenvector_future.ttf'))
        self.assertIn('src:url(kenvector_future.ttf)', self.page)
        for name in ('cover.webp', 'poster.webp'):
            self.assertTrue(os.path.isfile(os.path.join(PAGE, name)), name)
        self.assertIn('url(cover.webp)', self.page)

    def test_its_font_writes_no_v_k_or_x(self):
        css = self.page[self.page.index('<style>'):self.page.index('</style>')]
        # the rules that use the game's font: its name, the buttons, and the
        # headings of How it plays (those of Made with OXT-Beyond do not)
        users = sorted(m.group(1).strip() for m in re.finditer(r'([^{}]+)\{[^{}]*var\(--future\)[^{}]*\}', css))
        self.assertEqual(users, ['.btn', '.card h3', 'h1 .rescue'])
        self.assertRegex(css, r'\.btn\.ghost\{font:700 [^}]*system-ui')
        self.assertRegex(css, r'\.made \.card h3\{font:700 [^}]*system-ui')
        texts = re.findall(r'<span class="rescue"[^>]*>(.*?)</span>', self.page)
        texts += re.findall(r'class="btn primary[^"]*"[^>]*>(.*?)</(?:a|span)>', self.page)
        how = self.page[self.page.index('aria-labelledby="how"'):self.page.index('aria-labelledby="made"')]
        texts += re.findall(r'<h3>(.*?)</h3>', how)
        texts = [words(t) for t in texts]
        self.assertGreaterEqual(len(texts), 9)
        for text in texts:
            self.assertNotRegex(text, '[VKXvkx]', text)
        # "NOVA" is the game's picture of the word, with its own V
        self.assertIn('<img class="nova" src="logo-nova.png"', self.page)

    def test_the_page_sets_its_own_colours(self):
        # the same in a browser's light and dark mode, the game's
        self.assertIn('--amber:#ffb52e', self.page)
        self.assertIn('--card:#3a2e3f', self.page)
        self.assertNotIn('prefers-color-scheme', self.page)
        self.assertIn('@media (prefers-reduced-motion:reduce)', self.page)

    def test_the_gallery_lists_it_as_a_big_one(self):
        gallery = read(GAMES, 'index.html')
        start, end = '<!-- @OWN_PAGE:nova-rescue@ -->', '<!-- /@OWN_PAGE:nova-rescue@ -->'
        self.assertEqual(gallery.count(start), 1)
        self.assertEqual(gallery.count(end), 1)
        card = gallery[gallery.index(start):gallery.index(end)]
        self.assertIn('<a class="stack" href="nova-rescue/">', card)
        self.assertIn('src="nova-rescue/poster.webp"', card)
        self.assertLess(gallery.index('id="own-pages"'), gallery.index(start))
        self.assertLess(gallery.index(end), gallery.index('<!-- @PLAYER_SAMPLES@ -->'))

    def test_the_player_check_plays_it(self):
        self.assertIn('check_nova_rescue_page.check_player(p, browser, site,', read(TOOLS, 'web-player', 'build_player.py'))


if __name__ == '__main__':
    unittest.main()
