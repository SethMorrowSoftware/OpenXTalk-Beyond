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
- the online lobby: its relays are the ones the notices and the README
  name, and xTalk Chat's; both kinds of its messages are ones a relay
  does not keep, and a word to one player is sealed; the step it opens
  on says what going online shows, and nothing dials a relay but the
  player's own GO ONLINE; it hears NostrXT's relay library through an
  ear of its own and never takes or closes what another stack's chat
  uses; the list has the rows the builder makes; a room's code has no
  letter that looks like another; it asks a relay for nothing the relay
  kept and takes none of it for news, and the check's relay is one that
  keeps what it passes on, as some public ones do
- its phone check calls only handlers its stack has and asks for, reads
  only what the game says and taps only what the builder makes, has the
  xTalk Suite's modules and script libraries as the Suite's pins name
  them and as the IDE's web builder includes them, and runs in Chromium
  and WebKit in web.yml, the duel and the lobby with it; the deploy
  script adds a script library only when it is asked to
- the engine tests drive the game through the hooks it has
- the mouse's pointer, hidden over the arena while a level is played: the
  engine has one cursor for all its windows, so only the game's two
  handlers of the pointer touch it, every frame and every change of
  screen says how it is, a pointer the game hides is watched for frames
  that stop, and the stack closing gives it back before anything else;
  the check plays a level with a mouse in both browsers
- whatever comes into the game (a message of the engine's, a button, the
  page) changes what the window shows only behind a locked screen, and no
  handler leaves the screen locked: on a phone every statement that
  changes the window with the screen unlocked is a drawing of it, and
  waits for the screen's next frame

  python3 -m unittest discover -s tools/ci/tests
"""

import json
import os
import re
import subprocess
import sys
import time
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


def script_handlers(text):
    """The handlers of a script, {name: (kind, [(line number, code)])}: kind
    is on, command or function, with "private " before it for a private
    one, and the code of a line is the line without its comment and
    without the words in its quotes"""
    out = {}
    name = None
    for number, line in enumerate(text.split('\n'), 1):
        code = re.sub(r'"[^"]*"', '""', line)
        code = re.sub(r'(--|#|//).*$', '', code).rstrip()
        if name is None:
            m = re.match(r'(private\s+)?(on|command|function)\s+(\w+)', code)
            if m:
                name = m.group(3)
                out[name] = (('private ' if m.group(1) else '') + m.group(2), [])
        elif re.match(r'end\s+%s\b' % re.escape(name), code):
            name = None
        else:
            out[name][1].append((number, code))
    return out


# A statement that changes what the window shows: a property of a control
# (the stack's own, its rect or its whole screen, are the window itself)
CHANGES = re.compile(r'\s*set the \w+(?:\[[^\]]*\])? of (?!me\b)')


def screen_faults(text):
    """Where a handler of a script would leave the screen locked, or unlock
    one it did not lock: [(handler, line number, what)]. A handler locks
    and unlocks as often, and between the two nothing leaves it."""
    faults = []
    for name, (kind, lines) in script_handlers(text).items():
        depth = 0
        number = 0
        for number, code in lines:
            word = code.strip()
            if word == 'lock screen':
                depth += 1
            elif word == 'unlock screen':
                depth -= 1
                if depth < 0:
                    faults.append((name, number, 'unlocks a screen it did not lock'))
                    depth = 0
            elif depth > 0 and re.match(r'(exit to top|exit %s|return|pass|throw)\b' % re.escape(name), word):
                faults.append((name, number, 'leaves with the screen locked: ' + word))
        if depth:
            faults.append((name, number, 'ends with the screen locked'))
    return faults


def unlocked_changes(text, entries):
    """Those of entries (handlers of a script) that change what the window
    shows with the screen unlocked, themselves or through a handler they
    call: {entry: (the handlers on the way to the statement, its line
    number)}. What a handler does between lock screen and unlock screen is
    locked, whatever it calls there."""
    handlers = script_handlers(text)
    called = re.compile(r'\b(%s)\b' % '|'.join(sorted(handlers, key=len, reverse=True)))
    unlocked = {}
    for name, (kind, lines) in handlers.items():
        depth = 0
        first = None
        calls = []
        for number, code in lines:
            word = code.strip()
            if word == 'lock screen':
                depth += 1
            elif word == 'unlock screen':
                depth = max(0, depth - 1)
            elif depth == 0:
                if first is None and CHANGES.match(code):
                    first = number
                calls += [c for c in called.findall(code) if c != name]
        unlocked[name] = (first, calls)
    clean = set()

    def way(name, on_it):
        first, calls = unlocked[name]
        if first is not None:
            return [name], first
        for other in calls:
            if other in on_it or other in clean:
                continue
            found = way(other, on_it | {other})
            if found:
                return [name] + found[0], found[1]
        clean.add(name)
        return None

    out = {}
    for entry in entries:
        found = way(entry, {entry})
        if found:
            out[entry] = found
    return out


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


class Lobby(unittest.TestCase):
    """The online lobby: what the notices and the README say of it is what
    the game does, and it takes of NostrXT only what leaves another
    stack's chat as it was."""

    def code(self):
        """The lines of the game that are not comments, strings blanked,
        by handler"""
        return {name: [line for number, line in lines] for name, (kind, lines) in script_handlers(game_script()).items()}

    def test_the_relays_are_the_ones_the_notices_and_the_readme_name(self):
        relays = constant('kNetRelays').split(',')
        self.assertEqual(len(relays), 3)
        self.assertEqual(len(set(relays)), 3)
        notices = read('THIRD-PARTY-NOTICES.md')
        readme = read('tools', 'web-player', 'README.md')
        section = readme[readme.index('\n## Ember Bricks\n'):]
        for relay in relays:
            self.assertRegex(relay, r'^wss://[a-z0-9.-]+$')
            self.assertIn('`%s`' % relay, notices, relay)
            self.assertIn('`%s`' % relay, section, relay)
        # (xTalk Chat's: OXT-Beyond has one list of public relays to answer for)
        chat = read('ide', 'Extensions', 'org.openxtalk.plugin.xtalkchat', 'xtalkchat-core.livecodescript')
        self.assertEqual(constant('kNetRelays'), constant('kDefaultRelays', chat))

    def test_a_relay_keeps_nothing_of_the_lobby(self):
        # both kinds are ephemeral (NIP-01: 20000 to 29999): a relay passes
        # them on to who is there, and keeps none
        kinds = [int(constant('kNetKindWho')), int(constant('kNetKindTell'))]
        self.assertEqual(len(set(kinds)), 2)
        for kind in kinds:
            self.assertTrue(20000 <= kind <= 29999, kind)
        # a word to one player is sealed for that player, and only what
        # unseals is read
        script = game_script()
        self.assertEqual(len(re.findall(r'\bnxNip44Encrypt\(', script)), 1)
        self.assertEqual(len(re.findall(r'\bnxNip44Decrypt\(', script)), 1)
        # an entry stands for less time than the relays would be asked
        # again in, and one that says "in a duel" for the match and no more
        self.assertLess(int(constant('kNetBeat')) * 2, int(constant('kNetStale')))
        self.assertLessEqual(int(constant('kNetStale')), 60)

    def test_only_what_is_new_is_taken_from_a_relay(self):
        # some relays keep for a few minutes what they pass on (strfry,
        # five by default) and give it to whoever asks: the game asks for
        # none of it, and takes for news none that comes all the same
        script = game_script()
        listen = script[script.index('\nprivate command ebNetListen'):script.index('\nend ebNetListen')]
        for name in ('tWho', 'tMe'):
            self.assertIn('put 0 into %s["limit"]' % name, listen)
            self.assertIn('put the seconds - kNetOld into %s["since"]' % name, listen)
        self.assertTrue(60 <= int(constant('kNetOld')) <= 300, constant('kNetOld'))
        event = script[script.index('\nprivate command ebNetEvent'):script.index('\nend ebNetEvent')]
        gate = event.index('if not ebNetFresh(tEvent["kind"], tPk, tEvent["created_at"]) then\n      exit ebNetEvent')
        self.assertLess(gate, event.index('ebNetWho tPk'))
        self.assertLess(gate, event.index('ebNetSignal tPk'))
        fresh = script[script.index('\nprivate function ebNetFresh'):script.index('\nend ebNetFresh')]
        self.assertIn('if the seconds - pAt > kNetOld then\n      return false', fresh)
        self.assertIn('if sLob["at"][pPk] is a number and pAt < sLob["at"][pPk] then\n         return false', fresh)
        # a message is taken once in a visit, not once in a stay in the
        # lobby: what was seen is not forgotten when a match begins
        self.assertIn('if sSeen[tId] is true then\n      exit ebNetEvent', event)
        stop = script[script.index('\nprivate command ebNetStop'):script.index('\nend ebNetStop')]
        self.assertNotIn('sSeen', stop)
        # no two of the game's messages are one to a relay: each has its
        # count in the visit (a relay passes on the first of two with one
        # id, and an id is made of the words and the second)
        publish = script[script.index('\nprivate command ebNetPublish'):script.index('\nend ebNetPublish')]
        self.assertIn('add 1 to sSaid\n', publish)
        self.assertIn('nxTagsFromText(pTag & return & "seq" & tab & sSaid)', publish)
        self.assertNotIn('sSaid', stop)
        # and the check's relay is one that keeps them
        self.assertGreaterEqual(ember_bricks_check.LOBBY_RELAY_KEEPS, 300)
        self.assertIn('ephemeral=LOBBY_RELAY_KEEPS', read('tools', 'ci', 'ember_bricks_check.py'))

    def test_a_relay_that_goes_is_asked_again_before_the_lobby_is_given_up(self):
        # with no relay open the lobby is kept kNetOpenFor seconds: one
        # that went is asked again well inside that, more than once, or a
        # moment without the network would be the end of the lobby
        soon, tries = int(constant('kNetRetrySoon')), int(constant('kNetTries'))
        self.assertGreaterEqual(soon, 2)
        self.assertGreaterEqual(tries, 2)
        self.assertLessEqual(soon * tries, int(constant('kNetOpenFor')) - soon)
        self.assertGreater(int(constant('kNetRetry')), soon)
        # (and one that answers and hangs up is not asked for ever: its
        # times are counted afresh only when it has stayed a while)
        self.assertGreaterEqual(int(constant('kNetSteady')), 30)
        script = game_script()
        lost = script[script.index('\nprivate command ebNetLost'):script.index('\nend ebNetLost')]
        self.assertIn('if tUrl is not empty and sLob["tries"][tUrl] < kNetTries then\n'
                      '      add 1 to sLob["tries"][tUrl]\n'
                      '      put sLob["clock"] + kNetRetry into sLob["again"][tUrl]', lost)
        alone = lost[lost.index('if ebNetOpen() is 0 then'):]
        self.assertIn('put sLob["clock"] + kNetRetrySoon into tSoon', alone)
        self.assertIn('if sLob["again"][tOther] > tSoon then\n            put tSoon into sLob["again"][tOther]', alone)
        self.assertIn('if sLob["clock"] - sLob["since"][pRelay] >= kNetSteady then\n         put 0 into sLob["tries"][tUrl]', lost)
        # the lobby is given up before a relay is asked again in a frame,
        # so the asking has to be due before that
        step = script[script.index('\nprivate command ebNetStep'):script.index('\nend ebNetStep')]
        self.assertIn('if sLob["clock"] - sLob["alone"] > kNetOpenFor then\n            ebNetNone', step)
        self.assertLess(step.index('ebNetNone'), step.index('get ebNetDial(tUrl)'))
        # a frame long in coming (the phone slept) is no time a relay was
        # waited for, whichever is heard first, the frame or the relays' going
        self.assertIn('if pReal > kNetSlept and sLob["alone"] is a number then\n      add pReal to sLob["alone"]', step)
        self.assertLess(step.index('add pReal to sLob["alone"]'), step.index('ebNetNone'))
        self.assertTrue(1 <= float(constant('kNetSlept')) <= 5, constant('kNetSlept'))
        # a test's lobby has no relay but the ones a test gives it, which
        # are none: nothing of NostrXT's is called for them
        dial = script[script.index('\nprivate function ebNetDial'):script.index('\nend ebNetDial')]
        self.assertLess(dial.index('if sLob["fake"] is true then'), dial.index('nxrConnect pUrl'))
        listen = script[script.index('\nprivate command ebNetListen'):script.index('\nend ebNetListen')]
        self.assertLess(listen.index('if sLob["fake"] is true then\n      exit ebNetListen'), listen.index('nxrSubscribe'))
        # the browser's check has the relay hang up on everyone, and gives
        # the pages less time to be back than the lobby is kept for
        check = read('tools', 'ci', 'ember_bricks_check.py')
        self.assertIn('relay.relay.hang_up()', check)
        self.assertLess(ember_bricks_check.LOBBY_BACK_IN, int(constant('kNetOpenFor')))
        self.assertGreater(ember_bricks_check.LOBBY_BACK_IN, soon * 2)

    def test_the_checks_relay_hangs_up_and_goes_on_listening(self):
        import socket
        import nostr_test_relay

        def client(port):
            c = socket.create_connection(('127.0.0.1', port), timeout=5)
            c.sendall(b'GET / HTTP/1.1\r\nHost: x\r\nUpgrade: websocket\r\nConnection: Upgrade\r\n'
                      b'Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r\nSec-WebSocket-Version: 13\r\n\r\n')
            self.assertIn(b' 101 ', c.recv(4096))
            return c

        def wait_for(count):
            end = time.time() + 5
            while time.time() < end and len(server.relay.connected()) != count:
                time.sleep(0.02)
            return len(server.relay.connected())

        server = nostr_test_relay.serve()
        try:
            port = server.server_address[1]
            one, two = client(port), client(port)
            self.assertEqual(wait_for(2), 2)
            self.assertEqual(server.relay.hang_up(), 2)
            # each client's connection has ended, with no closing frame
            self.assertEqual(one.recv(16), b'')
            self.assertEqual(two.recv(16), b'')
            self.assertEqual(wait_for(0), 0)
            one.close()
            two.close()
            # and one that asks again is let in
            three = client(port)
            self.assertEqual(wait_for(1), 1)
            three.close()
        finally:
            server.shutdown()
            server.server_close()

    def test_the_checks_relay_keeps_what_it_is_told_to(self):
        import nostr_test_relay
        kept = nostr_test_relay.Relay(None, 300)
        self.assertTrue(kept.take({'id': 'a', 'kind': 1}, 0))
        self.assertTrue(kept.take({'id': 'b', 'kind': 21043}, 10))
        self.assertTrue(kept.take({'id': 'c', 'kind': 21044}, 20))
        self.assertFalse(kept.take({'id': 'b', 'kind': 21043}, 30))
        # what is kept for good in the order it came, then the ephemeral
        # ones while they are held, the newest first
        self.assertEqual([e['id'] for e in kept.stored(100)], ['a', 'c', 'b'])
        self.assertEqual([e['id'] for e in kept.stored(315)], ['a', 'c'])
        self.assertEqual([e['id'] for e in kept.stored(400)], ['a'])
        # and as it was for whoever asks for none of that (the web IDE's tour)
        plain = nostr_test_relay.Relay(None)
        self.assertTrue(plain.take({'id': 'a', 'kind': 1}, 0))
        self.assertTrue(plain.take({'id': 'b', 'kind': 21043}, 10))
        self.assertEqual([e['id'] for e in plain.stored(11)], ['a'])
        self.assertTrue(plain.take({'id': 'b', 'kind': 21043}, 12))
        self.assertFalse(plain.take({'id': 'a', 'kind': 1}, 13))
        self.assertIn('def serve(log_path=None, port=0, ephemeral=0):', read('tools', 'ci', 'nostr_test_relay.py'))
        self.assertIn('nostr_test_relay.serve(os.path.join(out, \'relay.txt\'))', read('tools', 'ci', 'web_ide_tour.py'))

    def test_going_online_is_the_players_choice(self):
        # the step the lobby opens on says what going online shows, and no
        # relay is dialled but from the player's own GO ONLINE
        script = game_script()
        look = script[script.index('\nprivate command ebLobbyLook'):script.index('\nend ebLobbyLook')]
        start = look[look.index('case "start"'):look.index('case "net-wait"')]
        self.assertIn('Going online shows this name to the other players. The lobby is on public Nostr relays, '
                      'which see your internet address.', start)
        code = self.code()

        def having(pattern):
            return sorted(name for name, lines in code.items() if any(re.search(pattern, line) for line in lines))

        # one handler dials; it is called to go online, and while online
        # for a relay that was lost (the step of a lobby that is on)
        self.assertEqual(having(r'\bnxrConnect\b'), ['ebNetDial'])
        self.assertEqual(having(r'\bebNetDial\('), ['ebNetRelay', 'ebNetStart', 'ebNetStep'])
        self.assertEqual(having(r'^\s*ebNetStep\b'), ['ebAdvance'])
        self.assertIn('   if sLob["on"] is true then\n      ebNetStep pReal\n   end if\n', script)
        # going online comes of GO ONLINE (the button, or Return in the
        # name's field, which presses it) and of leaving a match that
        # began in the lobby
        self.assertEqual(having(r'^\s*ebNetStart\b'), ['ebDuelLeave', 'ebNetGo'])
        self.assertEqual(having(r'^\s*ebNetGo\b'), ['ebDuelPress'])
        self.assertRegex(script, r'case "Net Go"\n\s+ebNetGo\n')
        leave = script[script.index('\ncommand ebDuelLeave'):script.index('\nend ebDuelLeave')]
        self.assertRegex(leave, r'if tBack then\n(?:\s+--[^\n]*\n)*\s+ebDuelOpen\n\s+if sLobby is "start" then\n\s+ebNetStart\n')
        # and a test's lobby dials none: the relays a test gives it
        # (ebNetRelay, which is of a test's lobby only) are none
        fake = script[script.index('\ncommand ebTestNet'):script.index('\nend ebTestNet')]
        self.assertNotIn('ebNetStart', fake)
        self.assertIn('put true into sLob["fake"]', fake)
        given = script[script.index('\ncommand ebNetRelay '):script.index('\nend ebNetRelay\n')]
        self.assertLess(given.index('if sLob["fake"] is not true then\n      exit ebNetRelay'), given.index('ebNetDial('))
        dial = script[script.index('\nprivate function ebNetDial'):script.index('\nend ebNetDial')]
        pretend = dial[dial.index('if sLob["fake"] is true then'):dial.index('nxrConnect pUrl')]
        self.assertIn('return true\n   end if\n', pretend)

    def test_the_game_hears_the_relays_through_an_ear_of_its_own(self):
        # NostrXT's relay library tells the top stack, or the one object
        # that took it all (nxrInit), which another stack's chat may be:
        # the game takes nothing, names a callback of its own to each
        # relay it opens, and closes only those
        script = game_script()
        code = [line for lines in self.code().values() for line in lines]
        for name in ('nxrInit', 'nxrShutdown'):
            self.assertEqual([line for line in code if re.search(r'\b%s\b' % name, line)], [], name)
        self.assertIn('nxrSetCallback tRelay, "ebRelayCall"', script)
        self.assertEqual(len([line for line in code if re.search(r'\bnxrDisconnect\b', line)]), 1)
        made = builder()
        ear = made[made.index('\nprivate function earScript'):made.index('\nend earScript')]
        self.assertIn('"on ebRelayCall pRelay, pKind, pOne, pTwo"', ear)
        self.assertIn('"   dispatch " & quote & "ebNetHeard" & quote & " to tGame with pRelay, pKind, pOne, pTwo"', ear)
        self.assertIn('set the script of button "Relay Ear" to earScript()', made)
        self.assertIn('set the visible of button "Relay Ear" to false', made)
        self.assertRegex(script, r'\non ebNetHeard pRelay, pKind, pOne, pTwo\n')
        # the ear is in the message path only while the game is online
        put = script[script.index('\nprivate command ebNetEar'):script.index('\nend ebNetEar')]
        self.assertIn('insert the script of button "Relay Ear" into back', put)
        self.assertIn('remove the script of button "Relay Ear" from back', put)
        # and what it hands on is for a lobby that is on, from a relay of its own
        heard = script[script.index('\non ebNetHeard'):script.index('\nend ebNetHeard')]
        self.assertIn('if sLob["on"] is not true or sLob["relay"][pRelay] is empty then\n      exit ebNetHeard', heard)

    def test_no_nostrxt_function_is_called_as_a_statement(self):
        # (as DataChannelXT's: an error at the first line it is met on)
        script = game_script()
        self.assertEqual(re.findall(r'(?m)^\s*nxr?[A-Z]\w*\(.*$', script), [])
        called = set(re.findall(r'\b(nxr?[A-Z]\w*)\b', '\n'.join(line for lines in self.code().values() for line in lines)))
        self.assertTrue({'nxProbeCapabilities', 'nxrVersion', 'nxKeyGenerate', 'nxKeyPublic', 'nxrConnect',
                         'nxrSetCallback', 'nxrSubscribe', 'nxrPublish', 'nxrDisconnect', 'nxFilterBuild',
                         'nxEventBuild', 'nxEventSign', 'nxEventFromJson', 'nxTagFirst', 'nxTagsFromText',
                         'nxNip44Encrypt', 'nxNip44Decrypt'} <= called, called)

    def test_the_list_has_the_rows_the_builder_makes(self):
        made = builder()
        self.assertEqual(constant('kNetRows'), constant('kWho', made))
        self.assertLessEqual(int(constant('kNetRowsShort')), int(constant('kNetRows')))
        self.assertIn('repeat with i = 1 to kWho', made)
        for name in ('Name', 'Net Go', 'Codes Open', 'Quick', 'Friend', 'Accept', 'Decline', 'Relay Ear'):
            self.assertIn('"%s"' % name, made, name)
            self.assertIn('"%s"' % name, game_script(), name)

    def test_a_rooms_code_has_no_letter_that_looks_like_another(self):
        letters = constant('kNetLetters')
        self.assertEqual(len(letters), 32)
        self.assertEqual(len(set(letters)), 32)
        self.assertRegex(letters, r'^[A-Z2-9]+$')
        for look_alike in 'IO01':
            self.assertNotIn(look_alike, letters)
        self.assertEqual(constant('kNetCodeLength'), '6')
        # (a link's "duel=" is what the game reads a room from)
        self.assertIn('"duel="', game_script())

    def test_the_duels_codes_are_as_they_were(self):
        # a lobby's description is the invite and the answer of the codes:
        # their version is the one two players by code share
        self.assertEqual(constant('kDuelVersion'), '1')
        self.assertEqual(constant('kNetVersion'), '1')


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

    def test_the_lobbys_modules_and_libraries_are_the_ones_the_suites_pins_name(self):
        with open(os.path.join(REPO, 'tools', 'oxt', 'xtalk-extensions.json'), encoding='utf-8') as f:
            pins = json.load(f)
        kinds = {e['id']: e.get('kind') for member in pins['members'] for e in member.get('extensions', [])}
        self.assertEqual(ember_bricks_check.MODULES, (ember_bricks_check.SODIUMXT, ember_bricks_check.COINXT,
                                                      ember_bricks_check.DATACHANNELXT))
        for name in ember_bricks_check.MODULES:
            self.assertEqual(kinds.get(name), 'lcb', name)
        for name in ember_bricks_check.LIBRARIES:
            self.assertEqual(kinds.get(name), 'lcs', name)
        # each library after those it uses: NostrXT signs with CoinXT, and
        # its relay library builds on it
        self.assertEqual(ember_bricks_check.LIBRARIES, ('coinxt', 'nostrxt', 'nostr-relay'))
        # and each is one the IDE's web builder knows the web engine has
        # the library of: the check's standalone is one the IDE could make
        web = read('ide-support', 'revsaveasemscriptenstandalone.livecodescript')
        known = constant('kXTalkWebExtensions', web).split(',')
        for name in ember_bricks_check.MODULES + ember_bricks_check.LIBRARIES:
            self.assertIn(name, known, name)

    def test_script_libraries_are_added_only_when_asked_for(self):
        # tools/ci/mobile-web-deploy.livecodescript: OXT_MW_LIBRARIES unset
        # leaves the deploy of every other check as it was
        deploy = read('tools', 'ci', 'mobile-web-deploy.livecodescript')
        self.assertIn('if $OXT_MW_LIBRARIES is not empty then', deploy)
        self.assertEqual(deploy.count('$OXT_MW_LIBRARIES'), 3)  # its words, the question, the loop
        self.assertIn('put $OXT_MW_LIBRARY & return & $OXT_MW_CHECK into tParams["auxiliary_stackfiles"]', deploy)
        self.assertIn('if tLibraries is not empty then\n         put return & tLibraries after '
                      'tParams["auxiliary_stackfiles"]', deploy)
        # the libraries are started before the template is filled in
        self.assertLess(deploy.index('if $OXT_MW_LIBRARIES is not empty then'),
                        deploy.index('put fileText($OXT_MW_TEMPLATE) into tParams["startup_script"]'))
        self.assertIn("OXT_MW_LIBRARIES='\\n'.join(libraries)", read('tools', 'ci', 'ember_bricks_check.py'))
        for other in ('mobile_web_check.py', 'wobble_forts_check.py', 'puzzle_almanac_check.py'):
            self.assertNotIn('OXT_MW_LIBRARIES', read('tools', 'ci', other), other)

    def test_the_game_has_what_the_check_reads(self):
        check = read('tools', 'ci', 'ember_bricks_check.py')
        script = game_script()
        keys = set(re.findall(r"\b[shg]\.get\('([a-z]+)'", check)) | set(re.findall(r"number\([shg], '([a-z]+)'", check))
        keys |= set(ember_bricks_check.KEYS)
        self.assertTrue({'mode', 'phase', 'score', 'bricks', 'padx', 'ball', 'window', 'arena', 'wide', 'fps',
                         'lobby', 'code', 'duel', 'stage', 'left', 'rival', 'link', 'shift', 'rtc',
                         'nostr', 'online', 'name', 'relays', 'room', 'who', 'doing', 'foe', 'invite'} <= keys, keys)
        for key in keys:
            self.assertIn('"%s:"' % key, script, key)
        # the controls it taps, measures and reads
        names = set(re.findall(r"(?:\.tap\(|\btap\(|control\(|\.text\(|middle\(self\.page, )'([A-Z][A-Za-z0-9 ]+)'",
                               check))
        self.assertTrue({'Play', 'Howto Go', 'Pause', 'Resume', 'Score', 'Duel Open', 'Host', 'Join', 'Code Copy',
                         'Code Paste', 'Code Go', 'Rematch', 'Pause Home', 'Result Title', 'Codes Open', 'Name',
                         'Net Go', 'Accept', 'Quick', 'Friend', 'Result Home', 'Lobby Text', 'Banner Sub',
                         'Code'} <= names, names)
        made = builder()
        for name in names:
            self.assertIn('"%s"' % name, made, name)
        # (a row of the lobby's list is tapped by the place its player has)
        self.assertIn("return 'Who %d' % (names.index(name) + 1)", check)
        self.assertIn('makeButton "Who" && i,', made)
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
        self.assertNotIn('--no-lobby', step.group(0))
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


class OneDrawing(unittest.TestCase):
    """The engine draws the window again after every statement that changed
    what it shows, unless the screen is locked, and on a phone each
    drawing waits for the screen's next frame: a level begun with the
    screen unlocked was a hundred drawings and more, well over a second on
    Android (the emulator's tests of the game: twenty-four levels begun
    did not end within sixty seconds). A desktop's tests cannot see it
    (they run with no window), so the script is read instead."""

    # What comes into the game with the screen unlocked on purpose, or
    # only from the tests' hands
    ALLOWED = {
        'ebButtonLook': 'a button as it is pressed: the one thing it changes is the drawing wanted, at once',
        'ebCatch': 'in the game a frame catches a spark, and a frame locks; alone it is a test, and a few drawings',
        'ebDuelReceive': 'in the game a frame hears the rival, and a frame locks; alone it is a test',
    }

    def entries(self):
        """The ways into the game: the engine's messages, what a button's
        script calls, what the page may call, and the hooks of the engine
        tests (on a phone a test's time is drawings too)"""
        script = game_script()
        names = [name for name, (kind, lines) in script_handlers(script).items() if kind == 'on']
        button = builder()
        button = button[button.index('\nprivate function buttonScript'):]
        button = button[:button.index('\nend buttonScript')]
        names += re.findall(r'\b(eb[A-Z]\w+)\b', button)
        names += re.findall(r'"(\w+)"', re.search(r'set the cJavascriptHandlers of stack kStack to (.*)', builder()).group(1))
        names += re.findall(r'"(eb[A-Z]\w+)"', read('tests', 'lcs', 'webplayer', 'ember-bricks.livecodescript'))
        return sorted(set(names))

    def test_the_ways_into_the_game(self):
        entries = self.entries()
        for name in ('preOpenStack', 'resizeStack', 'backKey', 'rawKeyDown', 'mouseUp', 'ebFrame', 'ebPageHidden',
                     'ebPress', 'ebButtonLook', 'ebPasted', 'ebState', 'ebNewRun', 'ebGoTitle', 'ebTestLevel'):
            self.assertIn(name, entries)
        handlers = script_handlers(game_script())
        for name in entries:
            self.assertIn(name, handlers)
            self.assertFalse(handlers[name][0].startswith('private'), name)

    def test_no_handler_leaves_the_screen_locked(self):
        self.assertEqual(screen_faults(game_script()), [])

    def test_what_comes_into_the_game_changes_the_window_behind_a_locked_screen(self):
        found = unlocked_changes(game_script(), self.entries())
        told = ['%s: %s, line %d' % (name, ' > '.join(path), line) for name, (path, line) in sorted(found.items())
                if name not in self.ALLOWED]
        self.assertEqual(told, [])
        # (and none is allowed that has no need to be)
        self.assertEqual(sorted(found), sorted(self.ALLOWED))

    def test_a_level_begins_with_one_drawing(self):
        # the handlers that begin a level or put a screen up, each alone
        script = game_script()
        self.assertEqual(unlocked_changes(script, ['ebNewRun', 'ebStartLevel', 'ebNextLevel', 'ebGoTitle', 'ebPause',
                                                   'ebResume', 'ebLaunch', 'ebDuelLeave', 'ebLayout', 'ebShowScreen']), {})

    def mutated(self, old, new):
        script = game_script()
        self.assertEqual(script.count(old), 1, old)
        return script.replace(old, new)

    def test_the_measure_sees_a_button_that_does_not_lock(self):
        script = self.mutated('   lock screen\n   ebPressed pName\n   unlock screen\n', '   ebPressed pName\n')
        found = unlocked_changes(script, self.entries())
        self.assertIn('ebPress', found)
        self.assertEqual(found['ebPress'][0][:2], ['ebPress', 'ebPressed'])
        # (the keys press the buttons)
        self.assertIn('rawKeyDown', found)

    def test_the_measure_sees_a_level_that_begins_unlocked(self):
        script = self.mutated('   -- (one drawing of the arena and its wall, not one of each brick)\n   lock screen\n',
                              '')
        script = script.replace('   ebDrawAll\n   unlock screen\n   ebKeepAwake true\n', '   ebDrawAll\n   ebKeepAwake true\n')
        self.assertEqual(screen_faults(script), [])
        self.assertEqual(sorted(unlocked_changes(script, ['ebNewRun', 'ebGoTitle'])), ['ebNewRun'])

    def test_the_measure_sees_a_pause_that_does_not_lock(self):
        script = game_script()
        pause = script[script.index('\ncommand ebPause'):script.index('\nend ebPause')]
        script = script.replace(pause, pause.replace('   lock screen\n', '').replace('   unlock screen\n', ''))
        found = unlocked_changes(script, self.entries())
        for name in ('ebPause', 'backKey', 'rawKeyDown', 'ebPageHidden', 'suspendStack', 'resizeStack'):
            self.assertIn(name, found)

    def test_the_measure_sees_a_screen_left_locked(self):
        script = game_script()
        self.assertEqual([fault[0] for fault in screen_faults(script.replace(
            '   ebDrawAll\n   unlock screen\n   ebKeepAwake true\n', '   ebDrawAll\n   ebKeepAwake true\n'))], ['ebNewRun'])
        left = self.mutated('   ebShowScreen "pause"\n   unlock screen\nend ebPause',
                            '   ebShowScreen "pause"\n   exit ebPause\n   unlock screen\nend ebPause')
        self.assertEqual([(fault[0], fault[2]) for fault in screen_faults(left)],
                         [('ebPause', 'leaves with the screen locked: exit ebPause')])
        twice = self.mutated('   ebShowScreen "pause"\n   unlock screen\nend ebPause',
                             '   ebShowScreen "pause"\n   unlock screen\n   unlock screen\nend ebPause')
        self.assertEqual([(fault[0], fault[2]) for fault in screen_faults(twice)],
                         [('ebPause', 'unlocks a screen it did not lock')])

    def test_script_handlers(self):
        text = ('local sA\n\non mouseUp\n   set the text of field "a -- b" to "x" -- said\n   helper 1\nend mouseUp\n\n'
                'private command helper pN\n   lock screen\n   set the label of button "B" to pN\n   unlock screen\n'
                '   set the rect of me to 0,0,1,1\nend helper\n\nfunction two\n   return 2 # two\nend two\n')
        handlers = script_handlers(text)
        self.assertEqual({name: kind for name, (kind, lines) in handlers.items()},
                         {'mouseUp': 'on', 'helper': 'private command', 'two': 'function'})
        self.assertEqual(handlers['mouseUp'][1], [(4, '   set the text of field "" to ""'), (5, '   helper 1')])
        self.assertEqual(handlers['two'][1], [(16, '   return 2')])
        self.assertEqual(screen_faults(text), [])
        # the field is changed with the screen unlocked; the button is
        # not, and the stack's own rect is the window, not what it shows
        self.assertEqual(unlocked_changes(text, ['mouseUp', 'helper', 'two']), {'mouseUp': (['mouseUp'], 4)})
        text = text.replace('   lock screen\n', '').replace('   unlock screen\n', '')
        self.assertEqual(unlocked_changes(text, ['mouseUp', 'helper', 'two']),
                         {'mouseUp': (['mouseUp'], 4), 'helper': (['helper'], 9)})
        text = text.replace('   set the text of field "a -- b" to "x" -- said\n', '')
        self.assertEqual(unlocked_changes(text, ['mouseUp']), {'mouseUp': (['mouseUp', 'helper'], 8)})


class Codes(unittest.TestCase):
    """A code is checked before it is unpacked: the engine's decompress
    makes room for as many bytes as the last four of what it is given say
    (libfoundation/src/foundation-filters.cpp), and half a code says
    anything at all."""

    def test_nothing_is_unpacked_that_was_not_measured(self):
        script = game_script()
        # one place unpacks, and it reads the length first
        self.assertEqual(len(re.findall(r'\bdecompress\(', script)), 1)
        unpack = script[script.index('\nprivate function ebDuelUnpack'):script.index('\nend ebDuelUnpack')]
        self.assertLess(unpack.index('if tLength < 1 or tLength > kDuelMost then'), unpack.index('decompress('))
        self.assertIn('ebDuelNumber(byte -4 to -1 of pData)', unpack)
        self.assertIn('ebDuelSum(tText) is not ebDuelNumber(byte -8 to -5 of pData)', unpack)
        self.assertLessEqual(int(constant('kDuelMost')), 100000)

    def test_the_engine_still_takes_the_length_from_the_data(self):
        # (were it to read the data first, the reason given in the script
        # would be the past)
        engine = read('libfoundation', 'src', 'foundation-filters.cpp')
        body = engine[engine.index('bool MCFiltersDecompress('):]
        body = body[:body.index('\n}\n')]
        self.assertLess(body.index('memcpy(&size, &sptr[t_src_len - 4], 4);'), body.index('t_buffer.New(size)'))
        self.assertLess(body.index('t_buffer.New(size)'), body.index('inflate('))

    def test_the_sum_is_a_crc_32(self):
        # the game's table and sum, worked here as the script works them,
        # give what zlib gives
        import zlib
        script = game_script()
        self.assertIn('put 3988292384 bitXor (tValue div 2) into tValue', script)
        self.assertIn('put sCrc[(tSum bitXor byteToNum(tByte)) mod 256] bitXor (tSum div 256) into tSum', script)
        self.assertIn('return tSum bitXor 4294967295', script)
        self.assertEqual(3988292384, 0xEDB88320)
        table = []
        for i in range(256):
            value = i
            for _ in range(8):
                value = 3988292384 ^ (value // 2) if value % 2 == 1 else value // 2
            table.append(value)
        for data in (b'', b'v=0\r\n', bytes(range(256)) * 3):
            total = 4294967295
            for byte in data:
                total = table[(total ^ byte) % 256] ^ (total // 256)
            self.assertEqual(total ^ 4294967295, zlib.crc32(data))


class ThePointer(unittest.TestCase):
    """The mouse's pointer is hidden over the arena while a level is
    played. The engine has one cursor for all of its windows, the IDE's
    among them, and a desktop's tests have no mouse and no window, so the
    script is read for who takes the cursor and that it is given back."""

    def code(self, name, script=None):
        return '\n'.join(code for number, code in script_handlers(script or game_script())[name][1])

    def test_only_the_pointers_handlers_touch_the_engines_cursor(self):
        handlers = script_handlers(game_script())
        touching = sorted(name for name, (kind, lines) in handlers.items()
                          if any(re.search(r'\b(lockCursor|cursor)\b', code, re.I) and re.match(r'\s*(set|lock|unlock)\b', code)
                                 for number, code in lines))
        self.assertEqual(touching, ['ebPointer', 'ebPointerShow'])
        # one hides, the other only lets go
        self.assertIn('set the lockCursor to true', self.code('ebPointer'))
        self.assertIn('set the cursor to none', self.code('ebPointer'))
        self.assertNotIn('to true', self.code('ebPointerShow'))
        self.assertIn('set the lockCursor to false', self.code('ebPointerShow'))
        for name in ('ebPointer', 'ebPointerShow', 'ebPointerHides'):
            self.assertTrue(handlers[name][0].startswith('private'), name)

    def test_a_cursor_the_game_did_not_take_is_not_let_go(self):
        show = self.code('ebPointerShow')
        self.assertLess(show.index('if sPtrOff is true then'), show.index('set the lockCursor to false'))
        hide = self.code('ebPointer')
        # (a cursor another script holds locked is left alone)
        self.assertLess(hide.index('if sPtrOff is not true and the lockCursor then'), hide.index('put true into sPtrOff'))
        self.assertLess(hide.index('put true into sPtrOff'), hide.index('set the lockCursor to true'))

    def test_every_frame_and_every_change_of_screen_says_how_the_pointer_is(self):
        # (a frame's ebAdvance is the tests' clock too; a pause stops the
        # frames, and is a change of screen)
        self.assertEqual(self.code('ebAdvance').rstrip().split('\n')[-1].strip(), 'ebPointer')
        self.assertEqual(self.code('ebShowScreen').rstrip().split('\n')[-1].strip(), 'ebPointer')
        self.assertIn('ebAdvance ', self.code('ebFrame'))
        # whatever changes the screen the game is on shows that screen,
        # after the change (the stack closing gives the pointer back
        # itself, and opening goes to the title)
        changing = []
        for name, (kind, lines) in script_handlers(game_script()).items():
            code = self.code(name)
            if 'into sMode' not in code or name in ('closeStack', 'ebInit'):
                continue
            changing.append(name)
            self.assertIn('ebShowScreen ', code, name)
            self.assertLess(code.rindex('into sMode'), code.rindex('ebShowScreen '), name)
        for name in ('ebPause', 'ebResume', 'ebGoTitle', 'ebNewRun', 'ebNextLevel', 'ebShowClear', 'ebShowOver',
                     'ebDuelOpen', 'ebDuelEnd'):
            self.assertIn(name, changing)
        self.assertIn('ebGoTitle', self.code('ebInit'))

    def test_the_pointer_is_hidden_only_in_a_level_over_the_arena_with_a_mouse(self):
        hides = self.code('ebPointerHides')
        for condition in ('sMode is not ""', 'sPointer is not ""', 'sPlatform is ""', 'the tool is not ""',
                          'the mouseStack is not the short name of me', 'tLoc is within sArena'):
            self.assertIn(condition, hides, condition)
        script = game_script()
        self.assertIn('if sMode is not "play" or sPointer is not "mouse" or sPlatform is "mobile" or sArena is empty then',
                      script)
        self.assertIn('if the tool is not "browse tool" then', script)
        # a test's mouse is read in place of the real one, never beside it
        self.assertLess(hides.index('if sManual then'), hides.index('the mouseLoc'))

    def test_a_hidden_pointer_is_watched_for_frames_that_stop(self):
        hide = self.code('ebPointer')
        self.assertIn('send "" to me in kPointerFor milliseconds', hide)
        self.assertIn('send "ebPointerWatch" to me in kPointerFor milliseconds', game_script())
        self.assertIn('put the milliseconds into sPtrAt', hide)
        watch = self.code('ebPointerWatch')
        self.assertIn('if the milliseconds - sPtrAt >= kPointerFor then', watch)
        self.assertLess(watch.index('if the milliseconds - sPtrAt >= kPointerFor then'), watch.index('ebPointerShow'))
        self.assertEqual(script_handlers(game_script())['ebPointerWatch'][0], 'on')
        # sooner than the half second with no frame that pauses a level,
        # and longer than a slow frame
        self.assertTrue(100 <= int(constant('kPointerFor')) < 500)
        # (the watch that is given up is cancelled)
        self.assertIn('cancel sPtrWatch', self.code('ebPointerShow'))

    def test_the_stack_closing_gives_the_pointer_back_first(self):
        close = self.code('closeStack')
        self.assertIn('ebPointerShow', close)
        for later in ('ebNetStop', 'ebDuelClose', 'mwStop'):
            self.assertLess(close.index('ebPointerShow'), close.index(later), later)
        # and a test begins with it shown, and no mouse
        begin = self.code('ebTestBegin')
        self.assertIn('ebPointerShow', begin)
        self.assertIn('put empty into sFakeMouse', begin)

    def test_the_check_plays_a_level_with_a_mouse_in_both_browsers(self):
        check = read('tools', 'ci', 'ember_bricks_check.py')
        main = check[check.index('\ndef main('):]
        self.assertIn('problems += check_pointer(p, args.browser, url, args.timeout, args.shots)', main)
        # (not only where a check can give a page a clipboard)
        pointer = main[main.index('if args.no_pointer:'):main.index('problems += check_pointer(')]
        self.assertNotIn('DUEL_BROWSERS', pointer)
        web = read('.github', 'workflows', 'web.yml')
        step = re.search(r"- name: Play Ember Bricks on phones.*?(?=\n      - name:|\Z)", web, re.S)
        self.assertNotIn('--no-pointer', step.group(0))
        # the pointer is what the page shows where the mouse is, and what
        # the game says of it
        body = check[check.index('\ndef check_pointer('):check.index('\ndef check_lobby(')]
        self.assertIn('me.page.mouse.move(x, y', body)
        self.assertIn('me.page.evaluate(CURSOR_AT, [x, y])', body)
        self.assertIn('getComputedStyle(e).cursor', ember_bricks_check.CURSOR_AT)
        self.assertIn("s.get('hidden') == 'true' and c['cursor'] == 'none'", body)
        # with a mouse, not a finger
        self.assertNotIn('has_touch', ember_bricks_check.DUEL_HOST)
        self.assertIn("Player(playwright, browser, browser_name, 'desktop', DUEL_HOST,", body)


class EngineTests(unittest.TestCase):

    def test_the_tests_use_the_games_hooks(self):
        tests = read('tests', 'lcs', 'webplayer', 'ember-bricks.livecodescript')
        script = game_script()
        hooks = set(re.findall(r'"(eb[A-Z]\w+)"', tests))
        self.assertTrue({'ebTestBegin', 'ebTestStep', 'ebTestLevel', 'ebTestBall', 'ebTestPaddle', 'ebTestDrop',
                         'ebTestSet', 'ebTestDuel', 'ebDuelSent', 'ebDuelReceive', 'ebState', 'ebPress',
                         'ebPasted', 'ebDuelEncode', 'ebDuelDecode', 'ebTestNet', 'ebNetHear', 'ebNetSent',
                         'ebNetName', 'ebNetCode', 'ebNetRelay', 'ebNetLines', 'ebTestSlept',
                         'ebPointerWatch'} <= hooks, hooks)
        for name in hooks:
            self.assertRegex(script, r'\n(?:on|command|function) %s\b' % name, name)
        self.assertGreaterEqual(len(re.findall(r'^on Test(?!Setup|Teardown)', tests, re.M)), 88)

    def test_the_layout_is_asked_only_of_a_window_that_was_made_the_size(self):
        # the tests of the game run in a phone's app too, where no window
        # can be made another size: a line about the layout outside
        # checkLayout was asked of the phone's own screen, and failed
        tests = read('tests', 'lcs', 'webplayer', 'ember-bricks.livecodescript')
        for name in ('TestTheScreensFitAPhone', 'TestTheScreensFitAPhoneOnItsSide', 'TestTheScreensFitAWindow',
                     'TestTheScreensFitTheScreenTheyAreOn'):
            body = tests[tests.index('\non %s\n' % name):tests.index('\nend %s\n' % name)]
            lines = [line.strip() for line in body.split('\n')[2:] if line.strip()]
            self.assertTrue(lines and all(line.startswith('checkLayout ') for line in lines), (name, lines))
        check = tests[tests.index('\nprivate command checkLayout'):tests.index('\nend checkLayout')]
        self.assertLess(check.index('TestSkip tAt'), check.index('TestAssert'))
        self.assertIn('checkLayout the width of stack kStack, the height of stack kStack, empty', tests)

    def test_no_description_of_a_test_starts_with_a_digit(self):
        # the test runner refuses one that does
        tests = read('tests', 'lcs', 'webplayer', 'ember-bricks.livecodescript')
        self.assertEqual(re.findall(r'TestAssert "\d[^"]*"', tests), [])


if __name__ == '__main__':
    unittest.main()
