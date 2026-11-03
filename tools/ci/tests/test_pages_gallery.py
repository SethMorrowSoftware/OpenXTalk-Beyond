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

"""The web stacks gallery (tools/pages/games): build_pages.py fills it
with a card for each of the Stack Player's samples that has a picture,
each opening a page of its own that runs the sample in the player through
?play=<title>; the big
ones (Pixel Platformer Maker, SVG Lab) keep their own cards; and a page
or a player from before the gallery is built as it was.

  python3 -m unittest discover -s tools/ci/tests
"""

import json
import os
import re
import shutil
import sys
import tempfile
import unittest

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
PAGES = os.path.join(REPO, 'tools', 'pages')
PLAYER = os.path.join(REPO, 'tools', 'web-player')
sys.path.insert(0, PAGES)
sys.path.insert(0, PLAYER)

import build_pages  # noqa: E402
import build_player  # noqa: E402


def read(path):
    with open(path, encoding='utf-8') as f:
        return f.read()


class TheGallery(unittest.TestCase):

    def setUp(self):
        self.work = tempfile.mkdtemp(prefix='test-pages-gallery-')
        self.player = os.path.join(self.work, 'player')
        os.makedirs(os.path.join(self.player, 'samples'))
        open(os.path.join(self.player, 'standalone-community-9.js'), 'w').close()

    def tearDown(self):
        shutil.rmtree(self.work, ignore_errors=True)

    def samples(self, listed, pictures=None):
        with open(os.path.join(self.player, 'samples', 'samples.json'), 'w', encoding='utf-8') as f:
            json.dump(listed, f)
        for s in listed:
            if isinstance(s, dict) and s.get('image') and (pictures is None or s['title'] in pictures):
                open(os.path.join(self.player, 'samples', s['image']), 'wb').close()

    def built(self):
        target = os.path.join(self.work, 'games')
        self.assertTrue(build_pages.games(os.path.join(PAGES, 'games'), target, self.player))
        return read(os.path.join(target, 'index.html'))

    def cards(self, text):
        found = re.findall(r'<a class="stack( spot)?" href="([a-z0-9-]+)/">', text)
        return [c for c in found if c[1] not in ('pixel-maker', 'svg-lab', 'waterwheel')]

    def test_the_players_samples_become_cards(self):
        self.samples([
            {'title': 'Tiny', 'image': 'Tiny.webp', 'description': 'Small & <b>fine</b>', 'tags': ['A<b>']},
            {'title': 'Fireworks', 'image': 'Fireworks.webp'},
            {'title': 'Beat Box', 'image': 'Beat Box.webp'},
            {'title': 'Lesson', 'image': 'Lesson.webp', 'featured': True},
            {'title': 'No picture', 'image': 'No picture.webp'},
            {'title': 'Nothing to show'},
            'not a sample',
        ], pictures={'Tiny', 'Fireworks', 'Beat Box', 'Lesson'})
        text = self.built()
        # the spotlight first, the first one large, the rest as listed;
        # the lessons in their own shelf; no card for a sample with no picture
        self.assertEqual(self.cards(text), [(' spot', 'beat-box'), ('', 'fireworks'), ('', 'tiny'),
                                            ('', 'lesson')])
        self.assertLess(text.index('Small wonders'), text.index('Learn by playing'))
        self.assertLess(text.index('href="tiny/"'), text.index('Learn by playing'))
        self.assertGreater(text.index('href="lesson/"'), text.index('Learn by playing'))
        self.assertIn('src="../player/samples/Beat%20Box.webp"', text)
        # what the samples say is text, never markup
        self.assertIn('<p>Small &amp; &lt;b&gt;fine&lt;/b&gt;</p>', text)
        self.assertIn('<span class="tag">A&lt;b&gt;</span>', text)
        self.assertNotRegex(text, r'@[A-Z_]+@')
        # the big ones keep their own pages
        self.assertIn('href="pixel-maker/"', text)
        self.assertIn('href="svg-lab/"', text)
        self.assertIn('href="waterwheel/"', text)

    def test_each_sample_gets_its_own_page(self):
        self.samples([
            {'title': 'Beat Box', 'image': 'Beat Box.webp', 'description': 'Drums & <b>more</b>', 'tags': ['Sound']},
            {'title': 'Lesson', 'image': 'Lesson.webp', 'featured': True},
            {'title': 'No picture', 'image': 'No picture.webp'},
        ], pictures={'Beat Box', 'Lesson'})
        self.built()
        games = os.path.join(self.work, 'games')
        page = read(os.path.join(games, 'beat-box', 'index.html'))
        self.assertIn('<title>Beat Box', page)
        self.assertIn('src="../../player/?play=Beat%20Box"', page)
        self.assertIn('../../player/samples/Beat%20Box.webp', page)
        self.assertIn('Drums &amp; &lt;b&gt;more&lt;/b&gt;', page)
        self.assertIn('<span class="tag">Sound</span>', page)
        self.assertNotRegex(page, r'@[A-Z_]+@')
        self.assertTrue(os.path.isfile(os.path.join(games, 'lesson', 'index.html')))
        self.assertFalse(os.path.exists(os.path.join(games, 'no-picture')))
        # the template itself stays off the site
        self.assertFalse(os.path.exists(os.path.join(games, 'stack-page.html')))

    def test_a_sample_cannot_take_a_big_ones_folder(self):
        self.samples([{'title': 'SVG Lab', 'image': 'SVG Lab.webp'}])
        with self.assertRaises(build_pages.BuildError):
            self.built()

    def test_a_player_with_no_samples(self):
        # an older player (or none listed): the shelves are left out and
        # the page is the big ones alone
        text = self.built()
        self.assertEqual(self.cards(text), [])
        self.assertNotIn('Small wonders', text)
        self.assertNotIn('Learn by playing', text)
        self.assertNotRegex(text, r'@[A-Z_]+@')
        self.assertIn('href="pixel-maker/"', text)
        for bad in ('{', '[1, 2]', 'not json'):
            with open(os.path.join(self.player, 'samples', 'samples.json'), 'w', encoding='utf-8') as f:
                f.write(bad)
            self.assertEqual(build_pages.player_samples(self.player), [], bad)

    def test_only_lessons(self):
        self.samples([{'title': 'Lesson', 'image': 'Lesson.webp', 'featured': True}])
        text = self.built()
        self.assertEqual(self.cards(text), [('', 'lesson')])
        self.assertNotIn('Small wonders', text)
        self.assertIn('Learn by playing', text)

    def test_a_page_without_the_shelves_is_left_alone(self):
        page = os.path.join(self.work, 'page.html')
        with open(page, 'w', encoding='utf-8') as f:
            f.write('<p>an older page</p>\n')
        self.samples([{'title': 'Beat Box', 'image': 'Beat Box.webp'}])
        build_pages.gallery(page, self.player)
        self.assertEqual(read(page), '<p>an older page</p>\n')
        build_pages.gallery(os.path.join(self.work, 'none.html'), self.player)
        self.assertFalse(os.path.exists(os.path.join(self.work, 'none.html')))

    def test_the_spotlight_is_in_the_players_samples(self):
        # Beat Box, Fireworks and Live Weather, as seth asked; each a small
        # sample with a picture in the player as it is built
        listed = {s['title']: s for s in build_player.SAMPLES}
        for title in build_pages.SPOTLIGHT:
            self.assertIn(title, listed)
            self.assertFalse(listed[title].get('featured'), title)
            self.assertTrue(os.path.isfile(os.path.join(PLAYER, 'stacks', listed[title]['image'])), title)

    def test_the_template(self):
        text = read(os.path.join(PAGES, 'games', 'index.html'))
        for key in ('PLAYER_SAMPLES', 'PLAYER_LESSONS'):
            self.assertEqual(text.count('<!-- @%s@ -->' % key), 1, key)
            self.assertEqual(text.count('<!-- /@%s@ -->' % key), 1, key)
            self.assertEqual(text.count('@%s_LIST@' % key), 1, key)
        # the page moves only for a reader who has not asked it not to
        self.assertIn('@media (prefers-reduced-motion: reduce)', text)


class TheStackPage(unittest.TestCase):
    """A sample's own page covers the player with the sample's picture
    until the stack plays. When the player cannot start the engine, or
    cannot open the sample, the cover goes, so the player's own message
    shows instead of "Loading..." for ever."""

    def setUp(self):
        self.text = read(os.path.join(PAGES, 'games', 'stack-page.html'))
        body = re.search(r"frame\.addEventListener\('load', function \(\) \{(.*?)\n\}\);", self.text, re.S)
        self.assertIsNotNone(body)
        self.wait = body.group(1)

    def test_the_cover_goes_when_the_stack_plays(self):
        self.assertIn("d.body.classList.contains('playing')", self.wait)
        self.assertIn("loading.style.display = 'none';", self.wait)

    def test_the_cover_goes_when_the_player_fails(self):
        # the engine that cannot start: the player's loading window says so
        self.assertIn("d.getElementById('loading-error')", self.wait)
        self.assertIn('!error.hidden', self.wait)
        # the sample that cannot be opened: the player's error toast
        self.assertIn("""d.querySelector('#toasts .toast[data-tone="3"]')""", self.wait)
        # and the player's error says what the player's error tone is
        player = read(os.path.join(PLAYER, 'index.html'))
        self.assertIn("el.dataset.tone = kind == 'error' ? '3' : '2';", player)
        self.assertIn('<div class="error" id="loading-error" hidden></div>', player)


class ThePlayersDeepLink(unittest.TestCase):
    """?play=<title> opens a sample once the engine is ready; with none, or
    an unknown title, the player is as it was. Run against the real engine
    by hand; here the wiring is held."""

    def setUp(self):
        self.text = read(os.path.join(PLAYER, 'index.html'))

    def test_it_reads_play_and_opens_a_listed_sample(self):
        self.assertIn("new URLSearchParams(location.search).get('play')", self.text)
        body = re.search(r'function playWanted\(\) \{(.*?)\n    \}', self.text, re.S)
        self.assertIsNotNone(body)
        body = body.group(1)
        # only once, only when the engine and the list are both there, and
        # only a sample the list names
        self.assertIn('if (!wanted || !ready || !sampleList) return;', body)
        self.assertIn('wanted = null;', body)
        self.assertIn('x.title == title', body)
        self.assertIn('if (s) getSample(s);', body)

    def test_it_tries_when_either_arrives(self):
        self.assertRegex(self.text, r"call\('library'\);\s*playWanted\(\);")
        self.assertRegex(self.text, r'sampleList = list \|\| \[\];\s*playWanted\(\);')


if __name__ == '__main__':
    unittest.main()
