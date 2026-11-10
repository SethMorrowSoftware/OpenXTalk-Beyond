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

"""Puzzle Almanac's page on the GitHub Pages site
(tools/pages/games/puzzle-almanac). The game is one of the Stack Player's
samples, so the page has no engine or stack of its own: it plays the
sample in the bare player (play/?play=Puzzle%20Almanac), in a phone's frame
on a computer and on the whole screen on a phone. Its pictures and font are
the game's own files, and the keys it names are the game's.
tools/pages/check_puzzle_almanac_page.py plays it in a browser, from
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
PAGE = os.path.join(GAMES, 'puzzle-almanac')
GAME = os.path.join(TOOLS, 'web-player', 'puzzle-almanac')
sys.path.insert(0, PAGES)
sys.path.insert(0, os.path.join(TOOLS, 'web-player'))

import build_pages  # noqa: E402
import build_player  # noqa: E402
import check_puzzle_almanac_page  # noqa: E402


def read(*path):
    with open(os.path.join(*path), encoding='utf-8') as f:
        return f.read()


def data(*path):
    with open(os.path.join(*path), 'rb') as f:
        return f.read()


class PuzzleAlmanacPage(unittest.TestCase):
    def setUp(self):
        self.page = read(PAGE, 'index.html')

    def test_it_is_a_player_sample_with_a_page_of_its_own(self):
        self.assertEqual(build_pages.OWN_PAGES.get('Puzzle Almanac'), 'puzzle-almanac')
        listed = {s['title']: s for s in build_player.SAMPLES}
        self.assertIn('Puzzle Almanac', listed)
        self.assertTrue(listed['Puzzle Almanac'].get('image'))
        self.assertFalse(listed['Puzzle Almanac'].get('featured'))
        self.assertEqual(check_puzzle_almanac_page.FOLDER, 'puzzle-almanac')

    def test_it_plays_the_sample_in_the_bare_player(self):
        play = '../../play/?play=%s&bg=%%23f7f0e1' % urllib.parse.quote('Puzzle Almanac')
        self.assertIn("var PLAY = '%s';" % play, self.page)
        # the links a phone taps, written as HTML
        self.assertEqual(self.page.count('href="%s"' % play.replace('&', '&amp;')), 2)
        self.assertIn('href="../../player/?play=Puzzle%20Almanac"', self.page)
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
        builder = read(TOOLS, 'web-player', 'puzzle-almanac.livecodescript')
        self.assertIn('constant kWidth = 390', builder)
        self.assertIn('constant kHeight = 760', builder)
        self.assertIn('.screen iframe{display:block;width:390px;height:760px;', self.page)
        self.assertEqual(check_puzzle_almanac_page.STACK, (390, 760))
        # once it plays: the frame has the focus, and the engine's canvas in it
        self.assertIn('frame.focus({ preventScroll: true });', self.page)
        self.assertIn('if (canvas) canvas.focus({ preventScroll: true });', self.page)

    def test_the_keys_it_names_are_the_games(self):
        game = read(TOOLS, 'web-player', 'puzzle-almanac-stack.livecodescript')
        keys = game[game.index('on rawKeyDown pKey'):game.index('end rawKeyDown')]
        # N and W on Home, the arrows, a number, Enter, Escape
        for code in ('110', '87', '65361', '65362', '65363', '65364', '65293', '65307'):
            self.assertIn(code, keys)
        self.assertIn('pKey >= 49 and pKey <= 57', keys)
        for name in ('<kbd>N</kbd> Number Place', '<kbd>W</kbd> Hidden Word', '<kbd>Enter</kbd>',
                     '<kbd>Esc</kbd>'):
            self.assertIn(name, self.page)

    def test_the_game_tells_the_page_how_it_is(self):
        builder = read(TOOLS, 'web-player', 'puzzle-almanac.livecodescript')
        self.assertIn('set the cJavascriptHandlers of stack tName to "paPageHidden" & return & "paState"', builder)
        self.assertIn(b'paPageHidden\npaState', data(TOOLS, 'web-player', 'stacks', 'Puzzle Almanac.oxtstack'))
        self.assertIn("findStackWithName('Puzzle Almanac')", check_puzzle_almanac_page.FRAME_STATE)
        self.assertIn('h.paState', check_puzzle_almanac_page.PAGE_STATE)
        game = read(TOOLS, 'web-player', 'puzzle-almanac-stack.livecodescript')
        for key in ('screen', 'panel', 'howto', 'chosen', 'typed', 'ndaily', 'wdaily', 'window', 'font', 'audio',
                    'library'):
            self.assertIn('"%s:"' % key, game)
        self.assertEqual(check_puzzle_almanac_page.parse_state('screen:home\nwindow:390,760'),
                         {'screen': 'home', 'window': '390,760'})

    def test_its_pictures_and_font_are_the_games(self):
        for name in ('animal-owl.png', 'animal-panda.png', 'animal-rabbit.png', 'star.png', 'tile-gold.png',
                     'tile-blue.png', 'tile-stone.png'):
            self.assertEqual(data(PAGE, name), data(GAME, 'art', name), name)
            self.assertIn(name, self.page)
        for name in ('AtkinsonHyperlegible-Regular.ttf', 'AtkinsonHyperlegible-Bold.ttf'):
            self.assertEqual(data(PAGE, name), data(GAME, 'fonts', name), name)
            self.assertIn('src:url(%s)' % name, self.page)
        for name in ('cover.webp', 'poster.webp'):
            self.assertTrue(os.path.isfile(os.path.join(PAGE, name)), name)
        self.assertIn('url(cover.webp)', self.page)
        # and the footer says whose they are
        footer = self.page[self.page.index('<footer>'):]
        for name in ('Kenney', 'Atkinson Hyperlegible', 'Open Font License', 'ENABLE'):
            self.assertIn(name, footer)

    def test_the_page_sets_its_own_colours(self):
        # the game's paper, the same in a browser's light and dark mode
        game = read(TOOLS, 'web-player', 'puzzle-almanac-stack.livecodescript')
        for name, colour in (('paper', 'F7F0E1'), ('card', 'FFFBF2'), ('ink', '3B2F2A'), ('leaf', '4E9A5B')):
            self.assertIn('--%s:#%s' % (name, colour.lower()), self.page)
            self.assertIn('"#%s"' % colour, game)
        self.assertIn('color-scheme:light', self.page)
        self.assertNotIn('prefers-color-scheme', self.page)
        self.assertIn('@media (prefers-reduced-motion:reduce)', self.page)

    def test_the_gallery_lists_it_as_a_big_one(self):
        gallery = read(GAMES, 'index.html')
        start, end = '<!-- @OWN_PAGE:puzzle-almanac@ -->', '<!-- /@OWN_PAGE:puzzle-almanac@ -->'
        self.assertEqual(gallery.count(start), 1)
        self.assertEqual(gallery.count(end), 1)
        card = gallery[gallery.index(start):gallery.index(end)]
        self.assertIn('<a class="stack" href="puzzle-almanac/">', card)
        self.assertIn('src="puzzle-almanac/poster.webp"', card)
        self.assertLess(gallery.index('<!-- /@OWN_PAGE:wobble-forts@ -->'), gallery.index(start))
        self.assertLess(gallery.index(end), gallery.index('<!-- @PLAYER_SAMPLES@ -->'))

    def test_the_player_check_plays_it(self):
        self.assertIn('check_puzzle_almanac_page.check_player(p, browser, site,',
                      read(TOOLS, 'web-player', 'build_player.py'))


if __name__ == '__main__':
    unittest.main()
