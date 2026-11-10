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
"""Wobble Forts (tools/web-player/stacks/Wobble Forts.oxtstack) held to the
files it is made from, without a browser or an engine:

- the committed stack is built from wobble-forts-stack.livecodescript and
  wobble-forts/levels.txt: the stack file holds both, as they are (a
  change there that was never built fails here)
- every picture of art/art.txt is there, drawn at twice its size (the
  skies, photographs of a sort, at their own); every picture the game and
  its levels name is there; every sound the game plays is there, a WAV,
  and every WAV is played; the font and each pack's licence are there, and
  SOURCES.md names each file
- every level names only pieces the game knows, in a land the game has
- no statement of the game is too long for an iPhone's Safari
- in a browser, its sound mixer (run in node against a stand-in for Web
  Audio) starts no more than six sounds at once, and a sound that ends
  makes room for another
- the game is offered: in the Stack Player's samples with its picture,
  and in Home's gallery with an icon
- its phone check calls only handlers its stack has and asks for, runs in
  Chromium and WebKit in web.yml, and its small helpers read what the game
  says; the deploy's OXT_MW_MODULES, which it uses, changes nothing unset
- the engine tests drive the game through the hooks it has, and CI runs
  them with Box2Dxt

  python3 -m unittest discover -s tools/ci/tests
"""

import json
import os
import re
import shutil
import struct
import subprocess
import sys
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
CI = os.path.dirname(HERE)
REPO = os.path.dirname(os.path.dirname(CI))
sys.path.insert(0, CI)
import wobble_forts_check  # noqa: E402
import mobile_web_check  # noqa: E402

PLAYER = os.path.join(REPO, 'tools', 'web-player')
ASSETS = os.path.join(PLAYER, 'wobble-forts')
STACK = os.path.join(PLAYER, 'stacks', 'Wobble Forts.oxtstack')

# the skies are Kenney's backdrops, drawn at their own size: twice it
# would add a megabyte to the stack for a picture drawn soft anyway
AT_THEIR_OWN_SIZE = {'sky-meadow', 'sky-dunes', 'sky-shroom'}


def read(*parts):
    with open(os.path.join(REPO, *parts), encoding='utf-8') as f:
        return f.read()


def game_script():
    return read('tools', 'web-player', 'wobble-forts-stack.livecodescript')


def builder():
    return read('tools', 'web-player', 'wobble-forts.livecodescript')


def levels():
    return read('tools', 'web-player', 'wobble-forts', 'levels.txt')


def stack_data():
    with open(STACK, 'rb') as f:
        return f.read()


def art_list():
    """[(name, file, width, height)] of art/art.txt"""
    out = []
    for line in read('tools', 'web-player', 'wobble-forts', 'art', 'art.txt').split('\n'):
        if line and not line.startswith('#'):
            name, file, width, height = line.split('\t')
            out.append((name, file, int(width), int(height)))
    return out


def png_size(path):
    with open(path, 'rb') as f:
        head = f.read(24)
    assert head[:8] == b'\x89PNG\r\n\x1a\n', path
    return struct.unpack('>II', head[16:24])


def level_lines():
    """[{name, land, bloops, hint, pieces}] of levels.txt (its form is in
    its first lines): "level <name>", "land", "bloops", "hint", then a
    piece a line, "<kind> <x> <bottom> [<angle>]", to the line "end"."""
    out = []
    for line in levels().split('\n'):
        line = line.strip()
        if not line or line.startswith('#'):
            continue
        word, _, rest = line.partition(' ')
        if word == 'level':
            out.append({'name': rest, 'pieces': [], 'line': line})
        elif word in ('land', 'bloops', 'hint'):
            out[-1][word] = rest
        elif word == 'end':
            out[-1]['ended'] = True
        else:
            out[-1]['pieces'].append(line)
    return out


class BuiltFromItsScript(unittest.TestCase):

    def test_the_stack_holds_the_script(self):
        data = stack_data()
        self.assertTrue(data.startswith(b'REVO'))
        # the builder sets the stack's script to the file without its first
        # line ("script ..."); the stack file keeps it as UTF-8, as it is
        script = game_script().split('\n', 1)[1].rstrip('\n')
        self.assertIn(script.encode('utf-8'), data,
                      'the committed stack is not built from wobble-forts-stack.livecodescript: '
                      'build it again (<engine> -ui tools/web-player/wobble-forts.livecodescript)')

    def test_the_stack_holds_the_levels(self):
        # each level's lines, as they are, in the stack (a custom property)
        data = stack_data()
        for level in level_lines():
            with self.subTest(level=level['name']):
                self.assertIn(level['line'].encode('utf-8'), data)
                for piece in level['pieces']:
                    self.assertIn(piece.encode('utf-8'), data,
                                  'the committed stack is not built from levels.txt: build it again')

    def test_the_measure_sees_a_stale_stack(self):
        script = game_script().split('\n', 1)[1]
        changed = script.replace('wfSound "unlock", 0.8, 1', 'wfSound "unlock", 0.7, 1')
        self.assertNotEqual(changed, script)
        self.assertNotIn(changed.rstrip('\n').encode('utf-8'), stack_data())

    def test_the_builder_reads_the_script_and_saves_the_stack(self):
        text = builder()
        self.assertIn('wobble-forts-stack.livecodescript', text)
        self.assertIn('put "stacks/Wobble Forts.oxtstack" into the last item of tFile', text)
        self.assertIn('$OXT_WOBBLE_FORTS', text)
        self.assertIn('levels.txt', text)
        self.assertTrue(game_script().startswith('script "Wobble Forts"\n'))


class Assets(unittest.TestCase):

    def test_every_picture_is_there_drawn_larger(self):
        pictures = art_list()
        self.assertGreater(len(pictures), 100)
        for name, file, width, height in pictures:
            with self.subTest(picture=name):
                path = os.path.join(ASSETS, 'art', file)
                self.assertTrue(os.path.isfile(path), path)
                w, h = png_size(path)
                scale = 1 if name in AT_THEIR_OWN_SIZE else 2
                self.assertGreaterEqual(w, scale * width - 2)
                self.assertGreaterEqual(h, scale * height - 2)
                self.assertLessEqual(w, 3 * width + 2)

    def test_every_file_of_art_is_listed(self):
        listed = {file for _, file, _, _ in art_list()}
        there = {f for f in os.listdir(os.path.join(ASSETS, 'art')) if f != 'art.txt'}
        self.assertEqual(listed, there)

    def test_every_picture_the_game_names_is_there(self):
        names = {name for name, _, _, _ in art_list()}
        script = game_script()
        # (a name followed by "&" is the start of one made from a colour)
        named = set(re.findall(r'wfPicture [^\n]*?, "([a-z0-9-]+)"(?! &)', script))
        named |= set(re.findall(r'wfFx "([a-z0-9-]+)"(?! &)', script))
        self.assertGreater(len(named), 5)
        for name in named:
            self.assertIn(name, names)
        # the ones it makes from a material, a shape and how broken it is,
        # or from a colour, a land or a number
        for name in ('wood-plank-cracked', 'glass-cube-chipped', 'metal-slab-whole', 'tnt-cube-whole',
                     'debris-stone2', 'bloop-beige', 'grump-pink', 'boss-yellow', 'sky-shroom',
                     'ground-sand', 'logo-wobble', 'logo-forts'):
            self.assertIn(name, names)

    def test_every_sound_the_game_plays_is_a_wav(self):
        script = game_script()
        played = set(re.findall(r'wfSound "([a-z-]+)"[,\n]', script))
        played |= {'wood', 'glass', 'stone', 'metal'}             # a piece knocked (wfHitSound)
        played |= {'thud'}                                        # a Bloop knocked
        played |= {m + '-break' for m in ('wood', 'glass', 'stone')}  # sPMat[i] & "-break"
        played |= {'star%d' % k for k in (1, 2, 3)}               # "star" & k
        for name in ('wood', 'glass', 'stone'):
            self.assertIn('case "%s"' % name, script)
        self.assertIn('wfSound sPMat[i] & "-break"', script)
        self.assertIn('wfSound "star" & k', script)
        self.assertIn('put "thud" into tName', script)
        there = {f[:-4] for f in os.listdir(os.path.join(ASSETS, 'sounds')) if f.endswith('.wav')}
        self.assertEqual(played, there, 'every sound is played, and every one played is there')
        for name in there:
            with open(os.path.join(ASSETS, 'sounds', name + '.wav'), 'rb') as f:
                head = f.read(12)
            self.assertEqual((head[:4], head[8:12]), (b'RIFF', b'WAVE'), name)

    def test_the_font_licences_and_sources(self):
        self.assertTrue(os.path.isfile(os.path.join(ASSETS, 'fonts', 'kenney_future_narrow.ttf')))
        licences = os.listdir(os.path.join(ASSETS, 'licenses'))
        self.assertEqual(len(licences), 8, licences)
        for name in licences:
            self.assertIn('creativecommons.org/publicdomain/zero/1.0',
                          read('tools', 'web-player', 'wobble-forts', 'licenses', name))
        sources = read('tools', 'web-player', 'wobble-forts', 'SOURCES.md')
        for folder in ('art', 'sounds', 'fonts'):
            for name in os.listdir(os.path.join(ASSETS, folder)):
                if name != 'art.txt':
                    self.assertIn('`%s/%s`' % (folder, name), sources)

    def test_none_of_novas_or_the_platformers_pictures(self):
        # the brief: a look of its own, from packs the other games do not use
        sources = read('tools', 'web-player', 'wobble-forts', 'SOURCES.md')
        nova = read('tools', 'web-player', 'nova-rescue', 'SOURCES.md')
        packs = set(re.findall(r'^\| `[^`]+` \| ([^|]+?) \|', sources, re.M))
        nova_packs = set(re.findall(r'^\| `[^`]+` \| ([^|]+?) \|', nova, re.M))
        self.assertTrue(packs)
        pictures = {p for p in packs if not re.search(r'Sounds|Audio|Jingles', p)}
        self.assertFalse(pictures & nova_packs, pictures & nova_packs)

    def test_no_word_in_kenney_future_has_a_k_or_an_x(self):
        # Kenney Future Narrow draws K and X much as it draws H: NEXT read
        # NEHT and "knock" HNOCH. What is written in it: the builder's
        # labels and buttons, the fields it gives the font (setText then
        # textFont: the hint, the tagline, the turn hint, the fail text),
        # the game's labels, the lands' names and the levels' hints
        text = builder()
        script = game_script()
        found, exprs = [], []
        found += re.findall(r'setLabel the long id of field "[^"]*", "([^"]*)"', text)
        found += re.findall(r'makeButton "[^"]*", "([^"]*)"', text)
        for name in re.findall(r'set the textFont of field "([^"]+)" to kFont', text):
            found += re.findall(r'setText the long id of field "%s", "([^"]*)"' % re.escape(name), text)
            exprs += re.findall(r'set the text of field "%s" to ([^\n]*)' % re.escape(name), script)
        for name in ('Clear Next Label', 'Records', 'Map Sub', 'Clear Best', 'Level Name', 'Map Title'):
            exprs += re.findall(r'set the text of field "%s" to ([^\n]*)' % re.escape(name), script)
        found += re.findall(r'^constant kLands = "([^"]*)"', script, re.M)
        found += [line[5:] for line in levels().split('\n') if line.startswith('hint ')]
        self.assertGreater(len(found) + len(exprs), 30)
        # (a value of the game's script: its quoted words only)
        found += [w for expr in exprs for w in re.findall(r'"([^"]*)"', expr)]
        for text in found:
            self.assertNotRegex(text, '[KkXx]', text)

    def test_the_title_is_a_picture(self):
        self.assertIn('logo-wobble', builder())
        self.assertIn('logo-forts', builder())
        self.assertIn('Logo Wobble', game_script())


class Levels(unittest.TestCase):

    def test_fifteen_levels_in_three_lands(self):
        found = level_lines()
        self.assertEqual(len(found), 15)
        self.assertEqual(len({level['name'] for level in found}), 15)
        for n, level in enumerate(found):
            with self.subTest(level=level['name']):
                self.assertTrue(level.get('ended'))
                self.assertEqual(level.get('land'), str(n // 5 + 1))
                self.assertGreater(len(level['pieces']), 2)
                # the last of a land is its boss's
                bosses = [p for p in level['pieces'] if p.startswith('boss-')]
                self.assertEqual(len(bosses), 1 if n % 5 == 4 else 0)

    def test_every_piece_is_one_the_game_knows(self):
        names = {name for name, _, _, _ in art_list()}
        for level in level_lines():
            for colour in level['bloops'].split():
                self.assertIn('bloop-' + colour, names, level['name'])
            self.assertLessEqual(len(level['bloops'].split()), 5, level['name'])
            for piece in level['pieces']:
                with self.subTest(piece=piece):
                    words = piece.split()
                    self.assertIn(len(words), (3, 4), piece)
                    for number in words[1:]:
                        float(number)
                    kind = words[0]
                    if kind.startswith(('grump-', 'boss-')):
                        self.assertIn(kind, names, piece)
                    else:
                        self.assertIn(kind + '-whole', names, piece)
                    self.assertLessEqual(float(words[1]), 1600, piece)

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


def mixer_script():
    """The JavaScript wfAudioScript() returns: its string literals joined,
    as the engine joins them (no escapes in an xTalk string)"""
    script = game_script()
    start = script.index('private function wfAudioScript')
    body = script[start:script.index('end wfAudioScript', start)]
    return ''.join(re.findall(r'"([^"\n]*)"', body))


# A stand-in for Web Audio: every buffer decodes at once, a source records
# its start, and the test ends a source by calling its onended
MIXER_HARNESS = r'''
var started = [], listeners = {};
function Context() { this.state = 'running'; this.currentTime = 0; this.destination = {}; }
Context.prototype.resume = function () {};
Context.prototype.decodeAudioData = function (data, ok) { ok({bytes: data.byteLength}); };
Context.prototype.createGain = function () { return {gain: {value: 1}, connect: function () {}}; };
Context.prototype.createBufferSource = function () {
  return {playbackRate: {value: 1}, onended: null, connect: function () {},
          start: function () { started.push(this); }};
};
var window = {AudioContext: Context, addEventListener: function (e, f) { listeners[e] = f; }};
eval(MIXER);
var A = window.wfAudio, out = {};
for (var i = 0; i < 20; i++) A.add('s' + i, btoa('RIFF'));
listeners.pointerup();
// a fort falls: twenty different sounds in one tick
for (var i = 0; i < 20; i++) A.play('s' + i, 1, 1);
out.burst = started.length;
// three of them end; later, three more ask to play
for (var i = 0; i < 3 && i < started.length; i++) if (started[i].onended) started[i].onended();
A.c.currentTime = 1;
for (var i = 0; i < 20; i++) A.play('s' + i, 1, 1);
out.after = started.length;
out.everyStartedEnds = started.every(function (s) { return typeof s.onended === 'function'; });
console.log(JSON.stringify(out));
'''


@unittest.skipUnless(shutil.which('node'), 'node is not installed')
class Mixer(unittest.TestCase):
    """The browser's mixer caps the sounds playing at once. #403's check in
    Linux WebKit (which plays Web Audio through GStreamer) hung for about
    30 seconds, twice, just after a burst of sounds; capping the burst is
    a guess at that cause, and keeps a phone's speaker from twenty
    knocks at once either way."""

    def run_mixer(self):
        script = MIXER_HARNESS.replace('eval(MIXER)', 'eval(%s)' % json.dumps(mixer_script()))
        out = subprocess.run([shutil.which('node'), '-e', script], capture_output=True, text=True, timeout=60)
        self.assertEqual(out.returncode, 0, out.stderr)
        return json.loads(out.stdout)

    def test_the_harness_reads_the_mixer(self):
        self.assertIn('window.wfAudio', mixer_script())
        self.assertIn('createBufferSource', mixer_script())

    def test_no_more_than_six_sounds_at_once(self):
        self.assertEqual(self.run_mixer()['burst'], 6)

    def test_a_sound_that_ends_makes_room(self):
        result = self.run_mixer()
        self.assertEqual(result['after'], result['burst'] + 3)
        self.assertTrue(result['everyStartedEnds'])


class Offered(unittest.TestCase):

    def test_in_the_stack_players_samples(self):
        sys.path.insert(0, PLAYER)
        import build_player
        sample = [s for s in build_player.SAMPLES if s['title'] == 'Wobble Forts']
        self.assertEqual(len(sample), 1)
        self.assertEqual(sample[0]['files'], ['Wobble Forts.oxtstack'])
        self.assertEqual(sample[0]['image'], 'Wobble Forts.webp')
        self.assertEqual(sample[0]['source'], 'stacks')
        self.assertIn('Game', sample[0]['tags'])
        for name in ('Wobble Forts.oxtstack', 'Wobble Forts.webp'):
            self.assertTrue(os.path.isfile(os.path.join(PLAYER, 'stacks', name)), name)
        with open(os.path.join(PLAYER, 'stacks', 'Wobble Forts.webp'), 'rb') as f:
            head = f.read(12)
        self.assertEqual((head[:4], head[8:12]), (b'RIFF', b'WEBP'))

    def test_in_homes_gallery_with_an_icon(self):
        learn = read('ide', 'Toolset', 'palettes', 'learn', 'revlearn.livecodescript')
        kit = read('ide', 'Toolset', 'palettes', 'learn', 'revlearnkit.livecodescript')
        self.assertIn('Responsive Starter,Nova Rescue,Wobble Forts,', learn)
        case = re.search(r'case "Wobble Forts"\n(.*?)\n      case', learn, re.S)
        self.assertIsNotNone(case)
        icon = re.search(r'\|([a-z0-9-]+)\|[a-z]+\|[^|"]+"', case.group(0)).group(1)
        self.assertEqual(icon, 'target')
        self.assertIn('case "%s"' % icon, kit)

    def test_in_the_notices(self):
        notices = read('THIRD-PARTY-NOTICES.md')
        self.assertIn('`tools/web-player/wobble-forts/`', notices)
        self.assertIn('`kenney_future_narrow.ttf`', notices)


class Check(unittest.TestCase):

    def test_every_handler_the_check_calls_is_there_and_asked_for(self):
        check = read('tools', 'ci', 'wobble_forts_check.py')
        stack = read('tools', 'ci', 'wobble-forts-check.livecodescript')
        called = set(re.findall(r"call\(page, '(wc\w+)'", check))
        called |= set(re.findall(r"h\.(wc\w+)\b", check))
        self.assertTrue({'wcState', 'wcBegin', 'wcErrors', 'wcRect', 'wcPopGrumps'} <= called, called)
        defined = set(re.findall(r'^(?:function|command) (wc\w+)', stack, re.M))
        for name in sorted(called):
            self.assertIn(name, defined, 'wobble-forts-check.livecodescript has no %s' % name)
            self.assertIn(name, wobble_forts_check.HANDLERS, 'the check does not ask for %s to be callable' % name)
        self.assertIn('script "%s"' % wobble_forts_check.CHECK_NAME, stack)
        self.assertIn("findStackWithName('%s')" % wobble_forts_check.CHECK_NAME, wobble_forts_check.CALL)

    def test_the_check_stack_hears_script_errors(self):
        stack = read('tools', 'ci', 'wobble-forts-check.livecodescript')
        self.assertIn('insert the script of me into back', stack)
        self.assertRegex(stack, r'on errorDialog pError\n   put pError & return')

    def test_the_check_finds_its_files(self):
        for path in (wobble_forts_check.GAME, wobble_forts_check.GAME_BUILDER, wobble_forts_check.CHECK_STACK,
                     wobble_forts_check.XTALK_EXTENSIONS, mobile_web_check.DEPLOY_SCRIPT,
                     mobile_web_check.LIBRARY):
            self.assertTrue(os.path.isfile(path), path)

    def test_the_check_gives_the_standalone_box2dxt(self):
        check = read('tools', 'ci', 'wobble_forts_check.py')
        self.assertEqual(wobble_forts_check.BOX2DXT, 'org.openxtalk.box2dxt')
        self.assertIn('OXT_MW_MODULES=', check)
        self.assertIn('box2dxt_module(', check)

    def test_the_game_has_what_the_check_reads(self):
        script = game_script()
        for key in ('mode', 'level', 'score', 'grumps', 'loaded', 'shots', 'stars', 'levelstars', 'physics',
                    'library', 'audio', 'font', 'view', 'fps', 'work', 'draw', 'flyer'):
            self.assertIn('"%s:"' % key, script)
        for name in ('Play', 'Howto Go', 'Pause', 'Resume', 'Score', 'Post', 'Loaded', 'Clear Next'):
            self.assertIn('"%s"' % name, builder())
        self.assertIn('makeButton "Tile" && i', builder())
        self.assertIn('makeDot "Aim" && i', builder())

    def test_chromium_and_webkit_in_web_yml(self):
        web = read('.github', 'workflows', 'web.yml')
        step = re.search(r"- name: Play Wobble Forts on phones.*?(?=\n      - name:)", web, re.S)
        self.assertIsNotNone(step)
        self.assertIn("if: matrix.browser != 'firefox'", step.group(0))
        self.assertIn('tools/ci/wobble_forts_check.py', step.group(0))
        self.assertIn('--browser "$BROWSER"', step.group(0))
        self.assertNotIn('--rebuild', step.group(0))
        self.assertEqual(sorted(wobble_forts_check.DEFAULT_DEVICES), ['chromium', 'webkit'])
        self.assertEqual(sorted(wobble_forts_check.DEFAULT_MIN_FPS), ['chromium', 'webkit'])

    def test_parse_state(self):
        s = wobble_forts_check.parse_state('mode:aim\nscore:1250\nflyer:310,560\n\nnonsense')
        self.assertEqual(s, {'mode': 'aim', 'score': '1250', 'flyer': '310,560'})
        self.assertEqual(wobble_forts_check.number(s, 'score'), 1250.0)
        self.assertIsNone(wobble_forts_check.number(s, 'fps'))

    def test_rect(self):
        self.assertEqual(wobble_forts_check.rect('272,0,572,390'), [272, 0, 572, 390])
        self.assertEqual(wobble_forts_check.rect('-4,10.6,20,30'), [-4, 10, 20, 30])
        self.assertIsNone(wobble_forts_check.rect('hidden'))
        self.assertIsNone(wobble_forts_check.rect('1,2,3'))


class Deploy(unittest.TestCase):

    def test_modules_are_added_only_when_asked_for(self):
        # tools/ci/mobile-web-deploy.livecodescript: OXT_MW_MODULES unset
        # leaves the deploy's modules as they were (no breaking change)
        deploy = read('tools', 'ci', 'mobile-web-deploy.livecodescript')
        self.assertIn('if $OXT_MW_MODULES is not empty then', deploy)
        lines = [l for l in deploy.split('\n') if 'tParams["modules"]' in l]
        self.assertEqual(len(lines), 1, lines)
        self.assertIn('$OXT_MW_MODULES', lines[0])


class EngineTests(unittest.TestCase):

    def test_the_tests_use_the_games_hooks(self):
        tests = read('tests', 'lcs', 'webplayer', 'wobble-forts.livecodescript')
        script = game_script()
        hooks = set(re.findall(r'"(wfTest\w+|wfState|wfPress|wfResized|wfCommas|wfShowMap|wfPlay|wfLoad|'
                               r'wfUnlocked)"', tests))
        self.assertTrue({'wfTestBegin', 'wfTestStep', 'wfTestShoot', 'wfTestTap', 'wfTestPopGrumps',
                         'wfState', 'wfPress'} <= hooks, hooks)
        for name in hooks:
            self.assertRegex(script, r'\n(?:on|command|function) %s\b' % name, name)
        self.assertGreaterEqual(len(re.findall(r'^on Test(?!Setup|Teardown)', tests, re.M)), 15)

    def test_the_tests_find_box2dxt(self):
        tests = read('tests', 'lcs', 'webplayer', 'wobble-forts.livecodescript')
        self.assertIn('$OXT_BOX2DXT', tests)
        for layout in ('/org.openxtalk.box2dxt', '/Extensions/org.openxtalk.box2dxt', '/code'):
            self.assertIn(layout, tests)

    def test_ci_runs_them_with_box2dxt(self):
        linux = read('.github', 'workflows', 'build-linux.yml')
        step = re.search(r"- name: Wobble Forts with Box2Dxt.*?(?=\n      #|\n      - name:)", linux, re.S)
        self.assertIsNotNone(step)
        self.assertIn('OXT_BOX2DXT="$OXT_ROOT"', step.group(0))
        self.assertIn("--filter '^lcs: webplayer/wobble-forts:'", step.group(0))
        # every test of play ran: none skipped for want of Box2D
        self.assertIn("grep -q ' 0 skip$'", step.group(0))


if __name__ == '__main__':
    unittest.main()
