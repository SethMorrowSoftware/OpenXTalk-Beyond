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
"""Ember Bricks (tools/web-player/stacks/Ember Bricks.oxtstack) held to the
files it is made from, without a browser or an engine:

- the committed stack is built from ember-bricks-stack.livecodescript and
  ember-bricks/levels.txt: the stack file holds the script and the levels,
  as they are (a change there that was never built fails here)
- the levels: twenty-four, each with a name of its own, rows of exactly
  ten places and no more of them than the file allows, made of the
  letters the file explains and the game knows; each has a brick to
  break, and none that steel shuts in, so every level can be cleared
- every sound the game plays is there, a WAV that make_assets.py makes
  now, and every WAV is played; the font is Puzzle Almanac's, byte for
  byte, with its licence; SOURCES.md names each file
- no statement of the game is too long for an iPhone's Safari
- the game is offered: in the Stack Player's samples with its picture, in
  Home's gallery with an icon, in the notices and the player's README
- the duel: the STUN server the game asks is the one the notices and the
  README name; the page may call the handlers the stack lists, and the
  game has each; no DataChannelXT function is called as a statement, and
  the game ends only a link of its own
- its phone check calls only handlers its stack has and asks for, reads
  only what the game says and taps only what the builder makes, has
  DataChannelXT's module as the xTalk Suite's pins name it, and runs in
  Chromium and WebKit in web.yml
- the engine tests drive the game through the hooks it has

  python3 -m unittest discover -s tools/ci/tests
"""

import json
import os
import re
import subprocess
import sys
import unittest
import wave

HERE = os.path.dirname(os.path.abspath(__file__))
CI = os.path.dirname(HERE)
REPO = os.path.dirname(os.path.dirname(CI))
sys.path.insert(0, CI)
import ember_bricks_check  # noqa: E402
import mobile_web_check  # noqa: E402

PLAYER = os.path.join(REPO, 'tools', 'web-player')
ASSETS = os.path.join(PLAYER, 'ember-bricks')
STACK = os.path.join(PLAYER, 'stacks', 'Ember Bricks.oxtstack')
COLS = 10
# the letters of levels.txt: nothing, the seven colours, tough, armoured,
# steel, a bomb, an ember
LETTERS = '.1234567TUXBE'


def read(*parts):
    with open(os.path.join(REPO, *parts), encoding='utf-8') as f:
        return f.read()


def game_script():
    return read('tools', 'web-player', 'ember-bricks-stack.livecodescript')


def builder():
    return read('tools', 'web-player', 'ember-bricks.livecodescript')


def constant(name, text=None):
    """A constant of the game's script, as written (a string without its quotes)"""
    m = re.search(r'^constant %s = (.*)$' % re.escape(name), text if text is not None else game_script(), re.M)
    assert m, name
    return m.group(1).strip().strip('"')


def parse_levels(text):
    """[(name, [row, ...])] of a levels.txt: a line "= Name" begins a level,
    a blank line ends it, and "#" begins a line that is not one"""
    levels = []
    rows = None
    for line in text.split('\n'):
        if line.startswith('#'):
            continue
        if line.startswith('= '):
            rows = []
            levels.append((line[2:].strip(), rows))
        elif line.strip() == '':
            rows = None
        elif rows is None:
            raise ValueError('a row outside a level: %r' % line)
        else:
            rows.append(line)
    return levels


def levels():
    return parse_levels(read('tools', 'web-player', 'ember-bricks', 'levels.txt'))


def shut_in(rows):
    """The bricks of a level that no ball can reach: those that steel (X)
    shuts off from the arena under the wall. A ball goes wherever there is
    no steel (it breaks what else is in its way), a step at a time, up,
    down or to a side."""
    height = len(rows) + 1  # the open row under the wall, where the ball comes from
    grid = [list(row) for row in rows] + [['.'] * COLS]
    seen = set()
    todo = [(height - 1, col) for col in range(COLS)]
    while todo:
        row, col = todo.pop()
        if (row, col) in seen or not (0 <= row < height and 0 <= col < COLS) or grid[row][col] == 'X':
            continue
        seen.add((row, col))
        todo += [(row - 1, col), (row + 1, col), (row, col - 1), (row, col + 1)]
    return [(col + 1, row + 1) for row in range(len(rows)) for col in range(COLS)
            if grid[row][col] not in '.X' and (row, col) not in seen]


class BuiltFromItsFiles(unittest.TestCase):

    def test_the_stack_holds_the_script(self):
        with open(STACK, 'rb') as f:
            data = f.read()
        self.assertTrue(data.startswith(b'REVO'))
        # the builder sets the stack's script to the file without its first
        # line ("script ..."); the stack file keeps it as UTF-8, as it is
        script = game_script().split('\n', 1)[1].rstrip('\n')
        self.assertIn(script.encode('utf-8'), data,
                      'the committed stack is not built from ember-bricks-stack.livecodescript: '
                      'build it again (<engine> -ui tools/web-player/ember-bricks.livecodescript)')

    def test_the_stack_holds_the_levels(self):
        with open(STACK, 'rb') as f:
            data = f.read()
        text = read('tools', 'web-player', 'ember-bricks', 'levels.txt')
        self.assertIn(text.rstrip('\n').encode('utf-8'), data,
                      'the committed stack is not built from ember-bricks/levels.txt: build it again')
        self.assertIn('set the cLevels of stack kStack to tLevels', builder())
        self.assertIn('the cLevels of me', game_script())

    def test_the_measure_sees_a_stale_stack(self):
        script = game_script().split('\n', 1)[1]
        changed = script.replace('constant kDuelLoss = 150', 'constant kDuelLoss = 100')
        self.assertNotEqual(changed, script)
        with open(STACK, 'rb') as f:
            self.assertNotIn(changed.rstrip('\n').encode('utf-8'), f.read())

    def test_the_builder_reads_the_script_and_saves_the_stack(self):
        text = builder()
        self.assertIn('put "ember-bricks-stack.livecodescript" into the last item of tFile', text)
        self.assertIn('put "stacks/Ember Bricks.oxtstack" into the last item of tFile', text)
        self.assertIn('$OXT_EMBER_BRICKS', text)
        self.assertTrue(game_script().startswith('script "Ember Bricks"\n'))

    def test_the_window_the_stack_is_built_with_is_the_one_it_keeps(self):
        # the Stack Player opens a stack in a window of its own size, so the
        # game reads the size it was built with from cWindow, not its width
        text = builder()
        self.assertIn('set the cWindow of stack kStack to kWidth & comma & kHeight', text)
        self.assertEqual((constant('kWidth', text), constant('kHeight', text)), ('900', '640'))
        self.assertIn('the cWindow of me', game_script())


class Levels(unittest.TestCase):

    def test_twenty_four_levels_each_with_a_name_of_its_own(self):
        names = [name for name, _ in levels()]
        self.assertEqual(len(names), 24)
        self.assertEqual(len(set(names)), 24, names)
        for name in names:
            self.assertRegex(name, r'^[A-Z][A-Za-z ]{2,17}$')

    def test_every_row_has_ten_places_of_letters_the_game_knows(self):
        allowed = int(re.search(r'exactly 10 places and at most (\d+) of them',
                                read('tools', 'web-player', 'ember-bricks', 'levels.txt')).group(1))
        self.assertLessEqual(allowed, int(constant('kRows')))
        self.assertEqual(int(constant('kCols')), COLS)
        for name, rows in levels():
            with self.subTest(level=name):
                self.assertTrue(1 <= len(rows) <= allowed, len(rows))
                for row in rows:
                    self.assertEqual(len(row), COLS, row)
                    self.assertEqual(set(row) - set(LETTERS), set(), row)

    def test_the_game_and_the_file_know_the_same_letters(self):
        text = read('tools', 'web-player', 'ember-bricks', 'levels.txt')
        used = set(''.join(''.join(rows) for _, rows in levels()))
        self.assertEqual(used, set(LETTERS), 'every kind of brick is in some level')
        script = game_script()
        for letter in 'TUXBE':
            self.assertRegex(text, r'(?m)^#   %s  ' % letter)
            self.assertIn('"%s"' % letter, script)

    def test_every_level_can_be_cleared(self):
        for name, rows in levels():
            with self.subTest(level=name):
                bricks = sum(1 for row in rows for letter in row if letter not in '.X')
                self.assertGreater(bricks, 0, 'nothing to break')
                self.assertEqual(shut_in(rows), [], 'bricks (column, row) that steel shuts in')

    def test_the_measure_sees_a_brick_shut_in(self):
        self.assertEqual(shut_in(['..........', '..XXX.....', '..X1X.....', '..XXX.....']), [(4, 3)])
        self.assertEqual(shut_in(['..........', '..XXX.....', '..X1X.....', '..X.X.....']), [])
        self.assertEqual(shut_in(['XXXXXXXXXX', 'X1.......X', 'XXXXXXXXXX']), [(2, 2)])
        self.assertEqual(shut_in(['1111111111', 'XXXXXXXXXX']), [(c, 1) for c in range(1, 11)])
        self.assertEqual(shut_in(['1111111111', 'XXXXXXXXX.']), [])

    def test_the_first_level_is_a_gentle_one(self):
        name, rows = levels()[0]
        self.assertEqual(name, 'First Sparks')
        self.assertEqual(set(''.join(rows)) & set('TUXB'), set())

    def test_parse_levels(self):
        parsed = parse_levels('# a note\n= One\n..........\n1111111111\n\n= Two\nXXXXXXXXXX\n')
        self.assertEqual(parsed, [('One', ['..........', '1111111111']), ('Two', ['XXXXXXXXXX'])])
        with self.assertRaises(ValueError):
            parse_levels('1111111111\n')


class Assets(unittest.TestCase):

    def played(self):
        names = set(re.findall(r'ebSound "([a-z-]+)"', game_script()))
        # a brick's sound is a note higher for each step of the heat
        self.assertIn('brick-', names)
        names.discard('brick-')
        names |= {'brick-%d' % i for i in range(1, 6)}
        self.assertIn('ebSound "brick-" & sMult', game_script())
        return names

    def test_every_sound_the_game_plays_is_a_wav_and_every_wav_is_played(self):
        there = {f[:-4] for f in os.listdir(os.path.join(ASSETS, 'sounds')) if f.endswith('.wav')}
        self.assertEqual(self.played(), there)
        self.assertEqual(len(there), 27)
        for name in there:
            with wave.open(os.path.join(ASSETS, 'sounds', name + '.wav'), 'rb') as w:
                self.assertEqual((w.getnchannels(), w.getframerate(), w.getsampwidth()), (1, 22050, 2), name)
                self.assertLess(w.getnframes() / 22050.0, 3.0, name)

    def test_the_sounds_are_what_make_assets_makes(self):
        r = subprocess.run([sys.executable, os.path.join(ASSETS, 'make_assets.py'), '--check'],
                           stdout=subprocess.PIPE, stderr=subprocess.STDOUT, universal_newlines=True)
        self.assertEqual(r.returncode, 0, r.stdout)
        self.assertIn('27 sounds, as made', r.stdout)

    def test_the_font_is_puzzle_almanacs_with_its_licence(self):
        other = os.path.join(PLAYER, 'puzzle-almanac')
        for name in ('AtkinsonHyperlegible-Regular.ttf', 'AtkinsonHyperlegible-Bold.ttf'):
            with open(os.path.join(ASSETS, 'fonts', name), 'rb') as mine, \
                    open(os.path.join(other, 'fonts', name), 'rb') as theirs:
                self.assertEqual(mine.read(), theirs.read(), name)
            self.assertIn('fonts/%s' % name, builder() + game_script())
        self.assertEqual(sorted(os.listdir(os.path.join(ASSETS, 'fonts'))),
                         ['AtkinsonHyperlegible-Bold.ttf', 'AtkinsonHyperlegible-Regular.ttf'])
        licence = read('tools', 'web-player', 'ember-bricks', 'licenses', 'atkinson-hyperlegible-OFL.txt')
        self.assertIn('SIL OPEN FONT LICENSE Version 1.1', licence)
        self.assertIn('Braille Institute of America', licence)

    def test_sources_names_each_file(self):
        sources = read('tools', 'web-player', 'ember-bricks', 'SOURCES.md')
        for folder in ('sounds', 'fonts', 'licenses'):
            for name in os.listdir(os.path.join(ASSETS, folder)):
                self.assertIn('| `%s/%s` |' % (folder, name), sources)
        self.assertIn('| `levels.txt` |', sources)
        rows = re.findall(r'^\| `([^`]+)` \|', sources, re.M)
        for row in rows:
            self.assertTrue(os.path.isfile(os.path.join(ASSETS, row)), row)

    def test_the_game_has_no_pictures(self):
        # what it shows is graphics the builder makes: nothing to licence
        for folder in os.listdir(ASSETS):
            self.assertIn(folder, ('sounds', 'fonts', 'licenses', 'levels.txt', 'make_assets.py', 'SOURCES.md',
                                   '__pycache__'))
        self.assertNotRegex(builder(), r'(?i)\bimport paint\b|create image')


class FitsAnIPhonesStack(unittest.TestCase):

    def test_no_statement_is_too_long(self):
        sys.path.insert(0, HERE)
        import test_mobile_web_check
        measure = test_mobile_web_check.FitsAnIPhonesStack().longest_statement
        for text in (game_script(), builder(), read('tools', 'ci', 'ember-bricks-check.livecodescript')):
            self.assertLessEqual(measure(text), 30)


class Offered(unittest.TestCase):

    def test_in_the_stack_players_samples(self):
        sys.path.insert(0, PLAYER)
        import build_player
        sample = [s for s in build_player.SAMPLES if s['title'] == 'Ember Bricks']
        self.assertEqual(len(sample), 1)
        self.assertEqual(sample[0]['files'], ['Ember Bricks.oxtstack'])
        self.assertEqual(sample[0]['image'], 'Ember Bricks.webp')
        self.assertEqual(sample[0]['source'], 'stacks')
        self.assertIn('Game', sample[0]['tags'])
        self.assertIn('Multiplayer', sample[0]['tags'])
        for name in ('Ember Bricks.oxtstack', 'Ember Bricks.webp'):
            self.assertTrue(os.path.isfile(os.path.join(PLAYER, 'stacks', name)), name)
        with open(os.path.join(PLAYER, 'stacks', 'Ember Bricks.webp'), 'rb') as f:
            head = f.read(30)
        self.assertEqual((head[:4], head[8:12]), (b'RIFF', b'WEBP'))
        # (a lossy WebP: its width is in the frame's header) 960 wide at most
        self.assertEqual(head[12:16], b'VP8 ')
        self.assertLessEqual(int.from_bytes(head[26:28], 'little') & 0x3fff, 960)

    def test_in_homes_gallery_with_an_icon(self):
        learn = read('ide', 'Toolset', 'palettes', 'learn', 'revlearn.livecodescript')
        kit = read('ide', 'Toolset', 'palettes', 'learn', 'revlearnkit.livecodescript')
        self.assertRegex(learn, r'"Puzzle Almanac,Ember Bricks"\n')
        case = re.search(r'case "Ember Bricks"\n(.*?)\n      case', learn, re.S)
        self.assertIsNotNone(case)
        group = re.search(r'return "([a-z]+)\|', case.group(0)).group(1)
        self.assertEqual(group, 'small')
        icon, accent = re.search(r'\|([a-z0-9-]+)\|([a-z]+)\|[^|"]+"', case.group(0)).groups()
        self.assertEqual((icon, accent), ('blocks', 'rose'))
        self.assertIn('case "%s"' % icon, kit)
        self.assertIn('case "%s"' % accent, kit)

    def test_in_the_notices_and_the_readme(self):
        notices = read('THIRD-PARTY-NOTICES.md')
        self.assertIn('`tools/web-player/ember-bricks/`', notices)
        self.assertIn('`tools/web-player/ember-bricks/fonts/`', notices)
        readme = read('tools', 'web-player', 'README.md')
        self.assertIn('\n## Ember Bricks\n', readme)
        self.assertIn('`ember-bricks.livecodescript`, `ember-bricks-stack.livecodescript`, `ember-bricks/`', readme)


class Duel(unittest.TestCase):

    def test_the_stun_server_is_the_one_the_notices_and_the_readme_name(self):
        ice = constant('kDuelIce')
        self.assertRegex(ice, r'^stun:[a-z0-9.-]+:\d+$')
        server = ice[len('stun:'):]
        self.assertIn('`%s`' % server, read('THIRD-PARTY-NOTICES.md'))
        self.assertIn('`%s`' % server, read('tools', 'web-player', 'README.md'))

    def test_the_rules_the_readme_gives_are_the_games(self):
        readme = read('tools', 'web-player', 'README.md')
        section = readme[readme.index('\n## Ember Bricks\n'):]
        self.assertEqual(constant('kDuelFor'), '180')
        self.assertIn('three minutes on the clock', section)
        self.assertIn('A lost ball costs %s points' % constant('kDuelLoss'), section)
        self.assertIn('a life is won every %s points' % '{:,}'.format(int(constant('kLifeEvery'))), section)
        self.assertEqual(len(levels()), 24)
        self.assertIn('twenty-four levels', section)

    def test_the_page_may_call_the_handlers_the_game_has(self):
        m = re.search(r'set the cJavascriptHandlers of stack kStack to (.*)', builder())
        self.assertIsNotNone(m)
        names = re.findall(r'"(\w+)"', m.group(1))
        self.assertEqual(names, ['ebPageHidden', 'ebPasted', 'ebState', 'ebRectOf'])
        for name in names:
            self.assertRegex(game_script(), r'\n(?:on|command|function) %s\b' % name, name)

    def test_no_datachannel_function_is_called_as_a_statement(self):
        # a function of an extension called as a statement is an error at
        # the first line it is met on, and takes the script with it
        script = game_script()
        self.assertEqual(re.findall(r'(?m)^\s*dc[A-Z]\w*\(.*$', script), [])
        called = set(re.findall(r'\b(dc[A-Z]\w*)\b', script))
        self.assertTrue({'dcCreatePeer', 'dcSetRemoteDescription', 'dcLocalDescription', 'dcCreateChannelEx',
                         'dcSendText', 'dcPoll', 'dcFreePeer', 'dcCleanup', 'dcLibraryVersion'} <= called, called)

    def test_the_game_ends_only_a_link_of_its_own(self):
        # dcCleanup frees every peer of the process, another stack's too:
        # the game calls it only when it made one, and frees its own peer
        script = game_script()
        self.assertEqual(len(re.findall(r'(?m)^\s*dcCleanup\s*$', script)), 1)
        close = script[script.index('\ncommand ebDuelClose'):script.index('\nend ebDuelClose')]
        self.assertRegex(close, r'if sRtcUsed is true then\n\s+put false into sRtcUsed\n\s+try\n\s+dcCleanup\n')
        self.assertIn('dcFreePeer', script)

    def test_a_code_says_what_it_is(self):
        script = game_script()
        self.assertEqual(constant('kDuelCode'), 'EB' + constant('kDuelVersion'))
        for name in ('ebDuelEncode', 'ebDuelDecode'):
            self.assertRegex(script, r'\nfunction %s\b' % name)


class Check(unittest.TestCase):

    def test_every_handler_the_check_calls_is_there_and_asked_for(self):
        check = read('tools', 'ci', 'ember_bricks_check.py')
        stack = read('tools', 'ci', 'ember-bricks-check.livecodescript')
        called = set(re.findall(r"call\((?:self\.)?page, '(ec\w+)'", check))
        called |= set(re.findall(r"h\.(ec\w+)\b", check))
        self.assertEqual(called, set(ember_bricks_check.HANDLERS))
        defined = set(re.findall(r'^(?:function|command) (ec\w+)', stack, re.M))
        for name in sorted(called):
            self.assertIn(name, defined, 'ember-bricks-check.livecodescript has no %s' % name)
        self.assertIn('script "%s"' % ember_bricks_check.CHECK_NAME, stack)
        self.assertIn("findStackWithName('%s')" % ember_bricks_check.CHECK_NAME, ember_bricks_check.CALL)
        self.assertIn("findStackWithName('%s')" % ember_bricks_check.CHECK_NAME, ember_bricks_check.OPENED)

    def test_the_check_stack_hears_script_errors(self):
        stack = read('tools', 'ci', 'ember-bricks-check.livecodescript')
        self.assertIn('insert the script of me into back', stack)
        self.assertRegex(stack, r'on errorDialog pError\n   put pError & return')

    def test_the_check_stack_calls_what_the_game_has(self):
        stack = read('tools', 'ci', 'ember-bricks-check.livecodescript')
        names = set(re.findall(r'dispatch (?:function )?"(eb\w+)" to stack kGame', stack))
        self.assertEqual(names, {'ebState', 'ebTestSet'})
        for name in names:
            self.assertRegex(game_script(), r'\n(?:command|function) %s\b' % name, name)
        self.assertIn('constant kGame = "Ember Bricks"', stack)
        self.assertIn('constant kCard = "Game"', stack)
        self.assertIn('create card "Game"', builder().replace('set the name of card 1 of stack kStack to "Game"',
                                                               'create card "Game"'))

    def test_the_check_finds_its_files(self):
        for path in (ember_bricks_check.GAME, ember_bricks_check.GAME_BUILDER, ember_bricks_check.CHECK_STACK,
                     ember_bricks_check.XTALK_EXTENSIONS, mobile_web_check.DEPLOY_SCRIPT, mobile_web_check.LIBRARY):
            self.assertTrue(os.path.isfile(path), path)

    def test_datachannelxts_module_is_the_one_the_suites_pins_name(self):
        with open(os.path.join(REPO, 'tools', 'oxt', 'xtalk-extensions.json'), encoding='utf-8') as f:
            pins = json.load(f)
        ids = [e['id'] for member in pins['members'] for e in member.get('extensions', []) if e.get('kind') == 'lcb']
        self.assertIn(ember_bricks_check.DATACHANNELXT, ids)
        # the deploy script takes the module, as it takes Box2Dxt's
        self.assertIn('$OXT_MW_MODULES', read('tools', 'ci', 'mobile-web-deploy.livecodescript'))
        self.assertIn("OXT_MW_MODULES='\\n'.join(modules)", read('tools', 'ci', 'ember_bricks_check.py'))

    def test_the_game_has_what_the_check_reads(self):
        check = read('tools', 'ci', 'ember_bricks_check.py')
        script = game_script()
        keys = set(re.findall(r"\b[shg]\.get\('([a-z]+)'", check)) | set(re.findall(r"number\([shg], '([a-z]+)'", check))
        keys |= set(ember_bricks_check.KEYS)
        self.assertTrue({'mode', 'phase', 'score', 'bricks', 'padx', 'ball', 'window', 'arena', 'wide', 'fps',
                         'lobby', 'code', 'duel', 'stage', 'left', 'rival', 'link', 'shift', 'rtc'} <= keys, keys)
        for key in keys:
            self.assertIn('"%s:"' % key, script, key)
        # the controls it taps, measures and reads
        names = set(re.findall(r"(?:\.tap\(|\btap\(|control\(|\.text\()'([A-Z][A-Za-z0-9 ]+)'", check))
        self.assertTrue({'Play', 'Howto Go', 'Pause', 'Resume', 'Score', 'Duel Open', 'Host', 'Join', 'Code Copy',
                         'Code Paste', 'Code Go', 'Rematch', 'Pause Home', 'Result Title'} <= names, names)
        made = builder()
        for name in names:
            self.assertIn('"%s"' % name, made, name)
        # what the lobby and the result say, as the game says it
        for text in re.findall(r"== '([A-Z][A-Z !]+)'", check) + re.findall(r"'(?:host|guest)': '([A-Z ]+)'", check):
            self.assertIn('"%s"' % text, script, text)
        for step in set(re.findall(r"get\('lobby'\) == '([a-z-]+)'", check)):
            self.assertIn('"%s"' % step, script, step)

    def test_chromium_and_webkit_in_web_yml(self):
        web = read('.github', 'workflows', 'web.yml')
        step = re.search(r"- name: Play Ember Bricks on phones.*?(?=\n      - name:|\Z)", web, re.S)
        self.assertIsNotNone(step)
        self.assertIn("if: matrix.browser != 'firefox'", step.group(0))
        self.assertIn('tools/ci/ember_bricks_check.py', step.group(0))
        self.assertIn('--browser "$BROWSER"', step.group(0))
        self.assertIn('ember-bricks', step.group(0))
        self.assertNotIn('--rebuild', step.group(0))
        self.assertNotIn('--no-duel', step.group(0))
        # (a second try in Chromium too: the duel's link is a real one)
        self.assertIn('retry_check.py --tries 2', step.group(0))
        self.assertEqual(sorted(ember_bricks_check.DEFAULT_DEVICES), ['chromium', 'webkit'])
        self.assertEqual(sorted(ember_bricks_check.DEFAULT_MIN_FPS), ['chromium', 'webkit'])
        self.assertEqual(ember_bricks_check.DUEL_BROWSERS, ('chromium',))

    def test_parse_state(self):
        s = ember_bricks_check.parse_state('mode:play\nscore:250\narena:2,74,388,653\nball:160,430,0,-1,true\n\nnonsense')
        self.assertEqual(s, {'mode': 'play', 'score': '250', 'arena': '2,74,388,653', 'ball': '160,430,0,-1,true'})
        self.assertEqual(ember_bricks_check.number(s, 'score'), 250.0)
        self.assertIsNone(ember_bricks_check.number(s, 'fps'))
        self.assertEqual(ember_bricks_check.said(s), 'mode=play, score=250, ball=160,430,0,-1,true, arena=2,74,388,653')
        self.assertEqual(ember_bricks_check.said({'Score': None}), "{'Score': None}")

    def test_rects(self):
        self.assertEqual(ember_bricks_check.rect('272,0,572,390'), [272, 0, 572, 390])
        self.assertEqual(ember_bricks_check.rect('-4,10.6,20,30'), [-4, 10, 20, 30])
        self.assertIsNone(ember_bricks_check.rect('hidden'))
        self.assertIsNone(ember_bricks_check.rect('1,2,3'))
        self.assertTrue(ember_bricks_check.inside([2, 74, 388, 653], [0, 0, 390, 760]))
        self.assertFalse(ember_bricks_check.inside([2, 74, 391, 653], [0, 0, 390, 760]))
        self.assertFalse(ember_bricks_check.inside(None, [0, 0, 390, 760]))
        self.assertTrue(ember_bricks_check.apart([0, 0, 100, 40], [100, 0, 200, 40]))
        self.assertFalse(ember_bricks_check.apart([0, 0, 101, 40], [100, 0, 200, 40]))
        self.assertFalse(ember_bricks_check.apart(None, [100, 0, 200, 40]))


class EngineTests(unittest.TestCase):

    def test_the_tests_use_the_games_hooks(self):
        tests = read('tests', 'lcs', 'webplayer', 'ember-bricks.livecodescript')
        script = game_script()
        hooks = set(re.findall(r'"(eb[A-Z]\w+)"', tests))
        self.assertTrue({'ebTestBegin', 'ebTestStep', 'ebTestLevel', 'ebTestBall', 'ebTestPaddle', 'ebTestDrop',
                         'ebTestSet', 'ebTestDuel', 'ebDuelSent', 'ebDuelReceive', 'ebState', 'ebPress',
                         'ebPasted', 'ebDuelEncode', 'ebDuelDecode'} <= hooks, hooks)
        for name in hooks:
            self.assertRegex(script, r'\n(?:on|command|function) %s\b' % name, name)
        self.assertGreaterEqual(len(re.findall(r'^on Test(?!Setup|Teardown)', tests, re.M)), 60)

    def test_no_description_of_a_test_starts_with_a_digit(self):
        # the test runner refuses one that does
        tests = read('tests', 'lcs', 'webplayer', 'ember-bricks.livecodescript')
        self.assertEqual(re.findall(r'TestAssert "\d[^"]*"', tests), [])


if __name__ == '__main__':
    unittest.main()
