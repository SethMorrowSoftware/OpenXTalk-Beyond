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

"""The bare player (tools/web-player/play.html, LittleNemo's openxtalk.org
p=26036): the stack and nothing else. build_player.py puts it beside the
player as play/index.html with the player's engine and stamp;
build_pages.py moves it to <site>/play/, pointing at the player's folder;
it only asks the player stack for what playerFromPage takes; another
site's stack is refused; a Mobile Web stack may fill its window; and the
player's own page is as it was. build_player.py --check opens it in a
browser (check_bare).

  python3 -m unittest discover -s tools/ci/tests
"""

import os
import re
import shutil
import sys
import tempfile
import types
import unittest
import zipfile

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
PAGES = os.path.join(REPO, 'tools', 'pages')
PLAYER = os.path.join(REPO, 'tools', 'web-player')
sys.path.insert(0, PAGES)
sys.path.insert(0, PLAYER)

import build_pages  # noqa: E402
import build_player  # noqa: E402

ENGINE = 'standalone-community-9.7.1-BeyondEngine.js'


def read(path):
    with open(path, encoding='utf-8') as f:
        return f.read()


class ThePage(unittest.TestCase):

    def setUp(self):
        self.page = read(os.path.join(PLAYER, 'play.html'))

    def test_nothing_but_the_stack(self):
        body = self.page[self.page.index('<body'):]
        for chrome in ('menubar', 'class="window', 'id="home"', 'id="reload"', 'id="download"',
                       'id="fullscreen"', 'id="about"', 'library'):
            self.assertNotIn(chrome, body.split('<script')[0], chrome)
        self.assertIn('<canvas id="canvas"', body)

    def test_the_whole_screen_only_on_a_phone(self):
        # The player stack takes a body without data-mobile-web-fill for a
        # phone (playerOnPhone, #348) and scales every stack to the window
        # there: the page starts with the attribute, and takes it off only
        # where the player's own page does, by the same test
        self.assertIn('<body data-mobile-web-fill="no">', self.page)
        player = read(os.path.join(PLAYER, 'index.html'))
        is_phone = re.compile(r'function isPhone\(\) \{\n(.*?)\n  \}', re.S)
        self.assertEqual(is_phone.search(self.page).group(1), is_phone.search(player).group(1))
        choose = self.page[self.page.index('function choosePhone'):]
        choose = choose[:choose.index('\n  }\n')]
        self.assertIn("if (playing) return;", choose)
        self.assertIn("if (isPhone()) document.body.removeAttribute('data-mobile-web-fill');", choose)
        self.assertIn("else document.body.setAttribute('data-mobile-web-fill', 'no');", choose)
        script = read(os.path.join(PLAYER, 'stack-player.livecodescript'))
        self.assertIn("document.body.hasAttribute('data-mobile-web-fill') ? 'no' : 'yes'", script)
        # a phone's notch and toolbar
        self.assertIn('viewport-fit=cover', self.page)
        self.assertIn('env(safe-area-inset-top)', self.page)
        self.assertIn('100dvh', self.page)

    def test_the_players_own_page_is_unchanged(self):
        player = read(os.path.join(PLAYER, 'index.html'))
        self.assertIn('<body data-tone="1" data-mobile-web-fill="no">', player)
        self.assertNotIn('play.html', player)
        self.assertNotIn('play/', player)
        self.assertNotIn('oxt-player-base', player)

    def test_only_what_the_player_stack_takes(self):
        script = read(os.path.join(PLAYER, 'stack-player.livecodescript'))
        allowed = re.search(r'if tVerb is among the items of "([a-z,]+)"', script).group(1).split(',')
        asked = set(re.findall(r"call\('([a-z]+)", self.page))
        self.assertTrue(asked)
        self.assertLessEqual(asked, set(allowed))
        # the events the stack sends, all handled
        for event in ('ready', 'opened', 'home', 'choices', 'status'):
            self.assertIn("name == '%s'" % event, self.page)

    def test_another_sites_stack_is_refused(self):
        self.assertIn('url.origin !== location.origin', self.page)
        at = self.page.index('function fetchStack')
        self.assertLess(self.page.index('sameSite(path)', at), self.page.index('fetch(url.href)', at))

    def test_the_base_meta_once(self):
        self.assertEqual(self.page.count(build_pages.BARE_BASE), 1)
        # everything of the player's is asked for through it
        script = self.page[self.page.index('<script'):]
        for asked in ("BASE + 'samples/", "BASE + '@ENGINE_JS@", "(folder || BASE)", "BASE + 'assets/"):
            self.assertIn(asked, script)


class TheBuild(unittest.TestCase):

    def setUp(self):
        self.work = tempfile.mkdtemp(prefix='test-web-player-bare-')
        self.site = os.path.join(self.work, 'StackPlayer')
        os.makedirs(self.site)
        for name in (ENGINE, ENGINE[:-3] + '.wasm', 'standalone.zip'):
            with open(os.path.join(self.site, name), 'wb') as f:
                f.write(name.encode())

    def tearDown(self):
        shutil.rmtree(self.work, ignore_errors=True)

    def test_put_page_puts_it_beside_the_player(self):
        build_player.put_page(self.site)
        bare = read(os.path.join(self.site, 'play', 'index.html'))
        player = read(os.path.join(self.site, 'index.html'))
        stamp = re.search(r'\?v=([0-9a-f]{16})', player).group(1)
        self.assertIn("var STAMP = '%s';" % stamp, bare)
        self.assertIn("BASE + '%s?v='" % ENGINE, bare)
        self.assertNotRegex(bare, r'@[A-Z_]+@')
        self.assertIn(build_pages.BARE_BASE, bare)

    def zip_of_site(self):
        path = os.path.join(self.work, 'OXT-Beyond-test-web-player.zip')
        build_player.make_zip(self.site, path)
        return path

    def site_from(self, zip_path):
        out = os.path.join(self.work, 'out')
        args = types.SimpleNamespace(out=out, ide=None, ide_version=None, player=zip_path,
                                     player_version='test', map=None, map_version=None)
        build_pages.build(args)
        return out

    def test_the_site_has_it_at_play(self):
        build_player.put_page(self.site)
        out = self.site_from(self.zip_of_site())
        bare = read(os.path.join(out, 'play', 'index.html'))
        self.assertIn('<meta name="oxt-player-base" content="../player/">', bare)
        self.assertNotIn(build_pages.BARE_BASE, bare)
        # one copy, at play/; the player is as it was
        self.assertFalse(os.path.exists(os.path.join(out, 'player', 'play')))
        self.assertTrue(os.path.isfile(os.path.join(out, 'player', 'index.html')))
        self.assertTrue(os.path.isfile(os.path.join(out, 'player', ENGINE)))

    def test_an_older_player_has_none(self):
        with open(os.path.join(self.site, 'index.html'), 'w', encoding='utf-8') as f:
            f.write('<html></html>')
        out = self.site_from(self.zip_of_site())
        self.assertFalse(os.path.exists(os.path.join(out, 'play')))
        self.assertTrue(os.path.isfile(os.path.join(out, 'player', 'index.html')))

    def test_a_page_without_its_base_is_refused(self):
        build_player.put_page(self.site)
        path = os.path.join(self.site, 'play', 'index.html')
        with open(path, 'w', encoding='utf-8') as f:
            f.write(read(path).replace(build_pages.BARE_BASE, ''))
        with self.assertRaises(build_pages.BuildError):
            self.site_from(self.zip_of_site())


if __name__ == '__main__':
    unittest.main()
