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
"""The Box2Dxt platformer in the Stack Player (tools/web-player/stacks/
Box2Dxt Platformer.oxtstack), held to what it is made from, without a
browser or an engine:

- the pin (box2dxt-platformer/pin.json) names the suite at a full commit,
  the platformer and the five sheets it draws from, each with a size and
  a SHA-256; box2dxt_platformer_files.py lays them out as the builder
  reads them, and refuses a file that is not the pinned one (or a pin
  that names anything else)
- the committed stack is the builder's: the game's stack, named as the
  sample is, with its import stamped whole (uPfMediaV), the atlases'
  folder by a relative name (no path of the machine that built it) and
  the chrome built, so that it opens to its title with no question
- the builder makes the import the game's own first run makes, with the
  game's own handlers, and never the save dialog (pfImportSave)
- the game is offered in the player's samples with its picture, and the
  player's check plays it; Learn's gallery and the package leave it out
  (the suite's demos left the package in #298), alike; the notices name
  its pictures

  python3 -m unittest discover -s tools/ci/tests
"""

import hashlib
import json
import os
import re
import shutil
import sys
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(os.path.dirname(HERE)))
PLAYER = os.path.join(REPO, 'tools', 'web-player')
sys.path.insert(0, PLAYER)
sys.path.insert(0, os.path.join(REPO, 'tools', 'oxt'))
sys.path.insert(0, os.path.join(REPO, 'tools', 'web-ide'))
import box2dxt_platformer_files as files  # noqa: E402
import build_player  # noqa: E402

TITLE = 'Box2Dxt Platformer'
STACK = os.path.join(PLAYER, 'stacks', TITLE + '.oxtstack')
SHEETS = ('spritesheet-characters-default', 'spritesheet-enemies-default', 'spritesheet-tiles-default',
          'spritesheet-backgrounds-default', 'enemies')


def read(*parts):
    with open(os.path.join(REPO, *parts), encoding='utf-8') as f:
        return f.read()


def stack_bytes():
    with open(STACK, 'rb') as f:
        return f.read()


class Pin(unittest.TestCase):

    def test_names_the_suite_the_game_and_its_sheets(self):
        pin = files.load()
        self.assertEqual(pin['repository'], 'SethMorrowSoftware/xtalk-suite')
        self.assertRegex(pin['commit'], r'^[0-9a-f]{40}$')
        paths = [f['path'] for f in pin['files']]
        expected = [files.SCRIPT] + ['box2dxt/Spritesheets/%s.%s' % (n, e) for n in SHEETS for e in ('png', 'xml')]
        self.assertEqual(sorted(paths), sorted(expected))
        for f in pin['files']:
            self.assertRegex(f['sha256'], r'^[0-9a-f]{64}$')
            self.assertGreater(f['size'], 0)

    def test_every_sheet_the_game_loads_is_pinned(self):
        # what pfLoadSheets loads is in the platformer's script, which is
        # not here; the builder's and the fetcher's names are
        builder = read('tools', 'web-player', 'box2dxt-platformer.livecodescript')
        self.assertIn('spritesheet-characters-default.png', builder)
        self.assertEqual(files.target_name(files.SCRIPT), 'box2dxt-platformer.livecodescript')
        self.assertIn('/box2dxt-platformer.livecodescript"', builder)
        self.assertEqual(files.target_name('box2dxt/Spritesheets/enemies.png'), 'Spritesheets/enemies.png')

    def suite(self, root, pin, change=None):
        for f in pin['files']:
            path = os.path.join(root, *f['path'].split('/'))
            os.makedirs(os.path.dirname(path), exist_ok=True)
            body = ('pinned ' + f['path']).encode()
            if f['path'] == change:
                body += b'!'
            with open(path, 'wb') as out:
                out.write(body)

    def fake_pin(self):
        pin = files.load()
        pin = json.loads(json.dumps(pin))
        for f in pin['files']:
            body = ('pinned ' + f['path']).encode()
            f['size'], f['sha256'] = len(body), hashlib.sha256(body).hexdigest()
        return pin

    def test_fetch_lays_the_files_out_for_the_builder(self):
        pin = self.fake_pin()
        with tempfile.TemporaryDirectory() as tmp:
            self.suite(os.path.join(tmp, 'suite'), pin)
            files.fetch(os.path.join(tmp, 'out'), os.path.join(tmp, 'suite'), log=lambda *a: None, pin=pin)
            got = sorted(os.path.relpath(os.path.join(r, n), os.path.join(tmp, 'out')).replace(os.sep, '/')
                         for r, _, ns in os.walk(os.path.join(tmp, 'out')) for n in ns)
            self.assertEqual(got, sorted(['box2dxt-platformer.livecodescript']
                                         + ['Spritesheets/%s.%s' % (n, e) for n in SHEETS for e in ('png', 'xml')]))

    def test_fetch_refuses_a_file_that_is_not_the_pinned_one(self):
        pin = self.fake_pin()
        for change in (files.SCRIPT, 'box2dxt/Spritesheets/enemies.xml'):
            with self.subTest(change=change), tempfile.TemporaryDirectory() as tmp:
                self.suite(os.path.join(tmp, 'suite'), pin, change)
                with self.assertRaisesRegex(files.PinError, 'not the pinned file'):
                    files.fetch(os.path.join(tmp, 'out'), os.path.join(tmp, 'suite'), log=lambda *a: None, pin=pin)

    def test_a_pin_that_names_anything_else_is_refused(self):
        pin = files.load()
        with tempfile.TemporaryDirectory() as tmp:
            bad = json.loads(json.dumps(pin))
            bad['commit'] = bad['commit'][:12]
            path = os.path.join(tmp, 'short.json')
            with open(path, 'w') as f:
                json.dump(bad, f)
            with self.assertRaisesRegex(files.PinError, '40-digit'):
                files.load(path)
            for extra in ('box2dxt/src/box2dxt.lcb', 'box2dxt/Spritesheets/sub/x.png', '../x.png'):
                bad = json.loads(json.dumps(pin))
                bad['files'].append({'path': extra, 'size': 1, 'sha256': '0' * 64})
                path = os.path.join(tmp, 'extra.json')
                with open(path, 'w') as f:
                    json.dump(bad, f)
                with self.subTest(extra=extra), self.assertRaisesRegex(files.PinError, 'neither'):
                    files.load(path)
            bad = json.loads(json.dumps(pin))
            bad['files'] = [f for f in bad['files'] if f['path'] != files.SCRIPT]
            with open(path, 'w') as f:
                json.dump(bad, f)
            with self.assertRaisesRegex(files.PinError, 'does not pin'):
                files.load(path)


class Stack(unittest.TestCase):

    def test_is_the_games_stack_with_its_import_whole(self):
        data = stack_bytes()
        self.assertTrue(data.startswith(b'REVO'), data[:8])
        self.assertIn(TITLE.encode(), data)
        # the game's script, as the suite has it (its handlers, by name)
        for name in (b'command pfImportWarm', b'function pfMedia', b'command buildPfUI',
                     b'constant kPfMediaV', b'on openCard'):
            self.assertIn(name, data)
        # the stamps it adopts the import by (pfMedia) and keeps its
        # chrome by (openCard), and the atlases' folder by a relative
        # name, so no path of the machine that built it is in the stack
        for prop in (b'uPfMediaV', b'uSpriteSheetFolderPath', b'uPfUIVersionTag'):
            self.assertIn(prop, data)
        self.assertNotIn(b'/tmp/', data)
        self.assertNotIn(b'/home/', data)
        self.assertNotIn(b'C:\\', data)
        # every atlas's image is in it (the Kit's b2ksheet_<name>)
        for sheet in (b'chars', b'hero', b'foes', b'tiles', b'hud', b'bg', b'spooks'):
            self.assertIn(b'b2ksheet_' + sheet, data)

    def test_the_builder_does_the_games_import_without_its_questions(self):
        builder = read('tools', 'web-player', 'box2dxt-platformer.livecodescript')
        self.assertIn('constant kName = "%s"' % TITLE, builder)
        for step in ('dispatch "b2kSheetPersist" to tStack with true', 'dispatch "buildPfUI" to tStack',
                     'dispatch function "pfLoadSheets" to tStack', 'dispatch "pfMakeSounds" to tStack',
                     'dispatch "pfImportWarm" to tStack', 'set the uPfMediaV of tStack to tVersion',
                     'dispatch function "pfMedia" to tStack', 'put "Spritesheets" into tSheets',
                     'set the defaultFolder to pFiles'):
            self.assertIn(step, builder)
        code = '\n'.join(l for l in builder.splitlines() if not l.lstrip().startswith('--'))
        # never the game's save offer, its first run or a dialog of any kind
        for never in ('pfImportSave', 'pfImportMedia', 'answer ', 'ask '):
            self.assertNotIn(never, code)
        self.assertIn('$OXT_PLATFORMER_FILES', builder)
        self.assertIn('$OXT_PLATFORMER', builder)


class Offered(unittest.TestCase):

    def test_in_the_players_samples_with_its_picture(self):
        sample = [s for s in build_player.SAMPLES if s['title'] == TITLE]
        self.assertEqual(len(sample), 1)
        sample = sample[0]
        self.assertEqual(sample['files'], [TITLE + '.oxtstack'])
        self.assertEqual(sample['image'], TITLE + '.webp')
        self.assertEqual(sample['source'], 'stacks')
        self.assertFalse(sample.get('featured'))
        for tag in ('Game', 'Physics', 'Keyboard'):
            self.assertIn(tag, sample['tags'])
        with open(os.path.join(PLAYER, 'stacks', sample['image']), 'rb') as f:
            head = f.read(30)
        self.assertEqual((head[:4], head[8:12]), (b'RIFF', b'WEBP'))
        # the samples with a picture come before the check's own stacks
        titles = [s['title'] for s in build_player.SAMPLES]
        self.assertLess(titles.index(TITLE), titles.index('Tour'))

    def test_the_players_check_plays_it(self):
        check = read('tools', 'web-player', 'build_player.py')
        self.assertIn("if sample['title'] == 'Box2Dxt Platformer':", check)
        self.assertIn('play_platformer(third, third_lines, before)', check)
        body = re.search(r'def play_platformer\(.*?\n\n    def ', check, re.S).group(0)
        for step in ("press('Space')", "down('ArrowRight')", "expect('platformer-plays'",
                     "startswith('PLAYER script error')"):
            self.assertIn(step, body)

    def test_left_out_of_learns_gallery_and_the_package_alike(self):
        import package
        import build_site
        name = TITLE + '.oxtstack'
        self.assertIn(name, package.SHOWCASE_LEFT_OUT)
        self.assertIn(name, build_site.SHOWCASE_LEFT_OUT)
        self.assertNotIn(name, [n for n, _ in package.showcase_stacks(REPO)])
        learn = read('ide', 'Toolset', 'palettes', 'learn', 'revlearn.livecodescript')
        self.assertRegex(learn, r'repeat for each item tName in "[^"]*\bBox2Dxt Platformer\b[^"]*"\s*\n\s*filter tFiles without')

    def test_in_the_notices(self):
        notices = read('THIRD-PARTY-NOTICES.md')
        row = [l for l in notices.splitlines() if '`tools/web-player/stacks/Box2Dxt Platformer.oxtstack`' in l]
        self.assertEqual(len(row), 1)
        self.assertIn('Kenney', row[0])
        self.assertIn('CC0', row[0])


if __name__ == '__main__':
    unittest.main()
