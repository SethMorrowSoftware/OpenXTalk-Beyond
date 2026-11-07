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
"""Nova Rescue (tools/web-player/stacks/Nova Rescue.oxtstack) held to the
files it is made from, without a browser or an engine:

- the committed stack is built from nova-rescue-stack.livecodescript: the
  stack file holds that script, as it is (a change there that was never
  built fails here)
- every picture of art/art.txt is there, at two or three times its size,
  and has a size in the builder; every sound the game plays is there, a
  WAV; the font and each pack's licence are there, and SOURCES.md names
  each file
- no word the game writes in KenVector Future has a V, which that font
  draws as a U (the title's NOVA is a picture, drawn with a V)
- no statement of the game is too long for an iPhone's Safari
- the game is offered: in the Stack Player's samples with its picture,
  and in Home's gallery with an icon
- its phone check calls only handlers its stack has and asks for, runs in
  Chromium and WebKit in web.yml, and its small helpers read what the game
  says
- the engine tests drive the game through the hooks it has

  python3 -m unittest discover -s tools/ci/tests
"""

import os
import re
import struct
import sys
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
CI = os.path.dirname(HERE)
REPO = os.path.dirname(os.path.dirname(CI))
sys.path.insert(0, CI)
import nova_rescue_check  # noqa: E402
import mobile_web_check  # noqa: E402

PLAYER = os.path.join(REPO, 'tools', 'web-player')
ASSETS = os.path.join(PLAYER, 'nova-rescue')
STACK = os.path.join(PLAYER, 'stacks', 'Nova Rescue.oxtstack')


def read(*parts):
    with open(os.path.join(REPO, *parts), encoding='utf-8') as f:
        return f.read()


def game_script():
    return read('tools', 'web-player', 'nova-rescue-stack.livecodescript')


def builder():
    return read('tools', 'web-player', 'nova-rescue.livecodescript')


def art_list():
    """[(name, file, width, height)] of art/art.txt"""
    out = []
    for line in read('tools', 'web-player', 'nova-rescue', 'art', 'art.txt').split('\n'):
        if line and not line.startswith('#'):
            name, file, width, height = line.split('\t')
            out.append((name, file, int(width), int(height)))
    return out


def png_size(path):
    with open(path, 'rb') as f:
        head = f.read(24)
    assert head[:8] == b'\x89PNG\r\n\x1a\n', path
    return struct.unpack('>II', head[16:24])


class BuiltFromItsScript(unittest.TestCase):

    def test_the_stack_holds_the_script(self):
        with open(STACK, 'rb') as f:
            data = f.read()
        self.assertTrue(data.startswith(b'REVO'))
        # the builder sets the stack's script to the file without its first
        # line ("script ..."); the stack file keeps it as UTF-8, as it is
        script = game_script().split('\n', 1)[1].rstrip('\n')
        self.assertIn(script.encode('utf-8'), data,
                      'the committed stack is not built from nova-rescue-stack.livecodescript: '
                      'build it again (<engine> -ui tools/web-player/nova-rescue.livecodescript)')

    def test_the_measure_sees_a_stale_stack(self):
        script = game_script().split('\n', 1)[1]
        changed = script.replace('put 250 * sStreak into tPoints', 'put 200 * sStreak into tPoints')
        self.assertNotEqual(changed, script)
        with open(STACK, 'rb') as f:
            self.assertNotIn(changed.rstrip('\n').encode('utf-8'), f.read())

    def test_the_builder_reads_the_script_and_saves_the_stack(self):
        text = builder()
        self.assertIn('put "nova-rescue-stack.livecodescript" into the last item of tFile', text)
        self.assertIn('put "stacks/Nova Rescue.oxtstack" into the last item of tFile', text)
        self.assertIn('$OXT_NOVA_RESCUE', text)
        self.assertTrue(game_script().startswith('script "Nova Rescue"\n'))


class Assets(unittest.TestCase):

    def test_every_picture_is_there_drawn_larger(self):
        pictures = art_list()
        self.assertGreater(len(pictures), 30)
        for name, file, width, height in pictures:
            with self.subTest(picture=name):
                path = os.path.join(ASSETS, 'art', file)
                self.assertTrue(os.path.isfile(path), path)
                w, h = png_size(path)
                # two or three pixels to a point, the extension's three
                self.assertGreaterEqual(w, 2 * width - 2)
                self.assertGreaterEqual(h, 2 * height - 2)
                self.assertLessEqual(w, 3 * width + 2)

    def test_every_picture_has_a_size_and_every_size_a_picture(self):
        scales = re.search(r'^constant kScales = "([^"]+)"', builder(), re.M).group(1)
        sized = {item.split('=')[0] for item in scales.split(',')}
        self.assertEqual(sized, {name for name, _, _, _ in art_list()})

    def test_every_picture_the_game_names_is_there(self):
        names = {name for name, _, _, _ in art_list()}
        for name in re.findall(r'sPic\["([a-z0-9-]+)"\]', game_script()):
            self.assertIn(name, names)
        # the ones it makes from a name and a number
        for name in ('meteor-big1', 'meteor-med3', 'meteor-small2', 'astronaut3', 'power-repair', 'flame2'):
            self.assertIn(name, names)

    def test_every_sound_the_game_plays_is_a_wav(self):
        played = set(re.findall(r'nrSound "([a-z-]+)"', game_script()))
        self.assertGreater(len(played), 10)
        there = {f[:-4] for f in os.listdir(os.path.join(ASSETS, 'sounds')) if f.endswith('.wav')}
        self.assertEqual(played, there, 'every sound is played, and every one played is there')
        for name in there:
            with open(os.path.join(ASSETS, 'sounds', name + '.wav'), 'rb') as f:
                head = f.read(12)
            self.assertEqual((head[:4], head[8:12]), (b'RIFF', b'WAVE'), name)

    def test_the_font_licences_and_sources(self):
        self.assertTrue(os.path.isfile(os.path.join(ASSETS, 'fonts', 'kenvector_future.ttf')))
        licences = os.listdir(os.path.join(ASSETS, 'licenses'))
        self.assertEqual(len(licences), 6, licences)
        for name in licences:
            self.assertIn('creativecommons.org/publicdomain/zero/1.0', read('tools', 'web-player', 'nova-rescue', 'licenses', name))
        sources = read('tools', 'web-player', 'nova-rescue', 'SOURCES.md')
        for folder in ('art', 'sounds', 'fonts'):
            for name in os.listdir(os.path.join(ASSETS, folder)):
                if name != 'art.txt':
                    self.assertIn('`%s/%s`' % (folder, name), sources)

    def test_no_word_in_kenvector_future_has_a_v(self):
        # KenVector Future draws V as U: "VIBRATION" said UIBRATION and the
        # title NOUA. What the builder writes in it (setLabel, makeButton) and
        # the game's labels, banners, pops and the over screen's lines
        found = []
        found += re.findall(r'setLabel the long id of field "[^"]*", "([^"]*)"', builder())
        found += re.findall(r'makeButton "[^"]*", "([^"]*)"', builder())
        script = game_script()
        found += re.findall(r'set the label of button "[^"]*" to "([^"]*)"', script)
        found += re.findall(r'nrBanner "([^"]*)"', script)
        found += re.findall(r'nrBanner [^\n]*?, "([^"]*)"', script)
        found += re.findall(r'nrPop "([^"]*)"', script)
        found += re.findall(r'set the text of field "(?:Stats|Best Note|Records|Final|Banner Text|Banner Sub)"'
                            r' to ([^\n]*)', script)
        self.assertGreater(len(found), 20)
        for text in found:
            for literal in re.findall(r'"([^"]*)"', '"%s"' % text if '"' not in text else text):
                self.assertNotRegex(literal, '[Vv]', literal)

    def test_the_title_is_a_picture(self):
        self.assertIn('makeSprite "Logo Nova", "logo-nova", "Title"', builder())
        self.assertIn('set the loc of button "Logo Nova"', game_script())
        self.assertIn('logo-nova', [name for name, _, _, _ in art_list()])


class FitsAnIPhonesStack(unittest.TestCase):

    def test_no_statement_is_too_long(self):
        measure = mobile_web_check_test().longest_statement
        for text in (game_script(), builder()):
            self.assertLessEqual(measure(text), 30)


def mobile_web_check_test():
    """The Phone Starter's measure of a long statement"""
    sys.path.insert(0, HERE)
    import test_mobile_web_check
    return test_mobile_web_check.FitsAnIPhonesStack()


class Offered(unittest.TestCase):

    def test_in_the_stack_players_samples(self):
        sys.path.insert(0, PLAYER)
        import build_player
        sample = [s for s in build_player.SAMPLES if s['title'] == 'Nova Rescue']
        self.assertEqual(len(sample), 1)
        self.assertEqual(sample[0]['files'], ['Nova Rescue.oxtstack'])
        self.assertEqual(sample[0]['image'], 'Nova Rescue.webp')
        self.assertIn('Game', sample[0]['tags'])
        for name in ('Nova Rescue.oxtstack', 'Nova Rescue.webp'):
            self.assertTrue(os.path.isfile(os.path.join(PLAYER, 'stacks', name)), name)
        with open(os.path.join(PLAYER, 'stacks', 'Nova Rescue.webp'), 'rb') as f:
            head = f.read(12)
        self.assertEqual((head[:4], head[8:12]), (b'RIFF', b'WEBP'))

    def test_in_homes_gallery_with_an_icon(self):
        learn = read('ide', 'Toolset', 'palettes', 'learn', 'revlearn.livecodescript')
        kit = read('ide', 'Toolset', 'palettes', 'learn', 'revlearnkit.livecodescript')
        self.assertIn('Responsive Starter,Nova Rescue"', learn)
        case = re.search(r'case "Nova Rescue"\n(.*?)\n      case', learn, re.S)
        self.assertIsNotNone(case)
        icon = re.search(r'\|([a-z0-9-]+)\|[a-z]+\|[^|"]+"', case.group(0)).group(1)
        self.assertEqual(icon, 'rocket')
        self.assertIn('case "%s"' % icon, kit)


class Check(unittest.TestCase):

    def test_every_handler_the_check_calls_is_there_and_asked_for(self):
        check = read('tools', 'ci', 'nova_rescue_check.py')
        stack = read('tools', 'ci', 'nova-rescue-check.livecodescript')
        called = set(re.findall(r"call\(page, '(nc\w+)'", check))
        called |= set(re.findall(r"h\.(nc\w+)\b", check))
        self.assertTrue({'ncState', 'ncBegin', 'ncErrors', 'ncRect', 'ncPut', 'ncSpawning'} <= called, called)
        defined = set(re.findall(r'^(?:function|command) (nc\w+)', stack, re.M))
        for name in sorted(called):
            self.assertIn(name, defined, 'nova-rescue-check.livecodescript has no %s' % name)
            self.assertIn(name, nova_rescue_check.HANDLERS, 'the check does not ask for %s to be callable' % name)
        self.assertIn('script "%s"' % nova_rescue_check.CHECK_NAME, stack)
        self.assertIn("findStackWithName('%s')" % nova_rescue_check.CHECK_NAME, nova_rescue_check.CALL)

    def test_the_check_stack_hears_script_errors(self):
        stack = read('tools', 'ci', 'nova-rescue-check.livecodescript')
        self.assertIn('insert the script of me into back', stack)
        self.assertRegex(stack, r'on errorDialog pError\n   put pError & return')

    def test_the_check_finds_its_files(self):
        for path in (nova_rescue_check.GAME, nova_rescue_check.GAME_BUILDER, nova_rescue_check.CHECK_STACK,
                     mobile_web_check.DEPLOY_SCRIPT, mobile_web_check.LIBRARY):
            self.assertTrue(os.path.isfile(path), path)

    def test_the_game_has_what_the_check_reads(self):
        script = game_script()
        for key in ('mode', 'score', 'rescued', 'shipx', 'shipy', 'column', 'bounds', 'now', 'fps', 'font',
                    'audio', 'library', 'work', 'draw'):
            self.assertIn('"%s:"' % key, script)
        for name in ('Play', 'Howto Go', 'Pause', 'Resume', 'Score'):
            self.assertIn('"%s"' % name, builder())

    def test_chromium_and_webkit_in_web_yml(self):
        web = read('.github', 'workflows', 'web.yml')
        step = re.search(r"- name: Play Nova Rescue on phones.*?(?=\n      - name:)", web, re.S)
        self.assertIsNotNone(step)
        self.assertIn("if: matrix.browser != 'firefox'", step.group(0))
        self.assertIn('tools/ci/nova_rescue_check.py', step.group(0))
        self.assertIn('--browser "$BROWSER"', step.group(0))
        self.assertNotIn('--rebuild', step.group(0))
        self.assertEqual(sorted(nova_rescue_check.DEFAULT_DEVICES), ['chromium', 'webkit'])
        self.assertEqual(sorted(nova_rescue_check.DEFAULT_MIN_FPS), ['chromium', 'webkit'])

    def test_parse_state(self):
        s = nova_rescue_check.parse_state('mode:play\nscore:250\ncolumn:0,0,390,664\n\nnonsense')
        self.assertEqual(s, {'mode': 'play', 'score': '250', 'column': '0,0,390,664'})
        self.assertEqual(nova_rescue_check.number(s, 'score'), 250.0)
        self.assertIsNone(nova_rescue_check.number(s, 'fps'))

    def test_rect(self):
        self.assertEqual(nova_rescue_check.rect('272,0,572,390'), [272, 0, 572, 390])
        self.assertEqual(nova_rescue_check.rect('-4,10.6,20,30'), [-4, 10, 20, 30])
        self.assertIsNone(nova_rescue_check.rect('hidden'))
        self.assertIsNone(nova_rescue_check.rect('1,2,3'))


class EngineTests(unittest.TestCase):

    def test_the_tests_use_the_games_hooks(self):
        tests = read('tests', 'lcs', 'webplayer', 'nova-rescue.livecodescript')
        script = game_script()
        hooks = set(re.findall(r'"(nrTest\w+|nrState|nrNewRun|nrGoTitle|nrPress|nrResized|nrCommas)"', tests))
        self.assertTrue({'nrTestBegin', 'nrTestStep', 'nrTestPut', 'nrState', 'nrPress'} <= hooks, hooks)
        for name in hooks:
            self.assertRegex(script, r'\n(?:on|command|function) %s\b' % name, name)
        self.assertGreaterEqual(len(re.findall(r'^on Test', tests, re.M)), 20)


if __name__ == '__main__':
    unittest.main()
