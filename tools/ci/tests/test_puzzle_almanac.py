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
"""Puzzle Almanac (tools/web-player/stacks/Puzzle Almanac.oxtstack) held to
the files it is made from, without a browser or an engine:

- the committed stack is built from puzzle-almanac-stack.livecodescript and
  puzzle-almanac/data: the stack file holds the script, the puzzles, the
  hidden words and the words a try may be, as they are (a change there that
  was never built fails here)
- every picture of art/art.txt is there, drawn at two or three times its
  size; every picture the game names is there; every sound it plays is a
  WAV, and every WAV is played; the font carries the Macintosh name record
  the web engine's font loader reads (without it the font does not load in
  a browser); each licence is there, and SOURCES.md names each file
- the puzzles: as many of each size as make_puzzles.py says, each with one
  answer, found by singles alone; the hidden words are words a try may be,
  of four to six letters, each with what it means
- the day's puzzle: a port of the game's own transform here gives the
  puzzles and words the engine test pins for day 310, and the day's puzzle
  of any day in years has one answer, found by singles alone
- no statement of the game is too long for an iPhone's Safari
- the game is offered: in the Stack Player's samples with its picture, in
  Home's gallery with an icon, and in the notices
- its phone check calls only handlers its stack has and asks for, and
  runs in Chromium and WebKit in web.yml
- the engine tests drive the game through the hooks it has, and a board is
  compared digit for digit (paSameDigits), never with a bare "is"

  python3 -m unittest discover -s tools/ci/tests
"""

import datetime
import math
import os
import re
import struct
import sys
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
CI = os.path.dirname(HERE)
REPO = os.path.dirname(os.path.dirname(CI))
sys.path.insert(0, CI)
import puzzle_almanac_check  # noqa: E402
import mobile_web_check  # noqa: E402

PLAYER = os.path.join(REPO, 'tools', 'web-player')
ASSETS = os.path.join(PLAYER, 'puzzle-almanac')
STACK = os.path.join(PLAYER, 'stacks', 'Puzzle Almanac.oxtstack')
sys.path.insert(0, ASSETS)
import make_puzzles  # noqa: E402


def read(*parts):
    with open(os.path.join(REPO, *parts), encoding='utf-8') as f:
        return f.read()


def game_script():
    return read('tools', 'web-player', 'puzzle-almanac-stack.livecodescript')


def builder():
    return read('tools', 'web-player', 'puzzle-almanac.livecodescript')


def engine_tests():
    return read('tests', 'lcs', 'webplayer', 'puzzle-almanac.livecodescript')


def data(name):
    return read('tools', 'web-player', 'puzzle-almanac', 'data', name)


def stack_data():
    with open(STACK, 'rb') as f:
        return f.read()


def art_list():
    """[(name, file, width, height)] of art/art.txt"""
    out = []
    for line in read('tools', 'web-player', 'puzzle-almanac', 'art', 'art.txt').split('\n'):
        if line and not line.startswith('#'):
            name, file, width, height = line.split('\t')
            out.append((name, file, int(width), int(height)))
    return out


def png_size(path):
    with open(path, 'rb') as f:
        head = f.read(24)
    assert head[:8] == b'\x89PNG\r\n\x1a\n', path
    return struct.unpack('>II', head[16:24])


def bank():
    """{size: [(puzzle, answer)]} of numbers.txt, in its order (the game's
    sBank, paReadData)"""
    out = {}
    for line in data('numbers.txt').split('\n'):
        items = line.split(':')
        if len(items) == 3:
            out.setdefault(int(items[0]), []).append((items[1], items[2]))
    return out


def answers():
    """{length: [(word, meaning)]} of answers.txt without its notes, in its
    order (the builder's cAnswers, the game's sAnswers)"""
    out = {}
    for line in data('answers.txt').split('\n'):
        if not line or line.startswith('#'):
            continue
        word, meaning = line.split('\t')
        if 4 <= len(word) <= 6:
            out.setdefault(len(word), []).append((word, meaning))
    return out


def engine_constant(name):
    found = re.search(r'^constant %s = "([^"]*)"' % name, engine_tests(), re.M)
    assert found, name
    return found.group(1)


def font_names(path):
    """{(platform, encoding, language, name id): bytes} of a font's name table"""
    with open(path, 'rb') as f:
        font = f.read()
    tables = struct.unpack('>H', font[4:6])[0]
    for k in range(tables):
        tag, _, offset, _ = struct.unpack('>4sIII', font[12 + 16 * k:28 + 16 * k])
        if tag == b'name':
            break
    else:
        raise AssertionError('no name table in %s' % path)
    _, count, strings = struct.unpack('>HHH', font[offset:offset + 6])
    out = {}
    for k in range(count):
        p, e, l, n, length, at = struct.unpack('>HHHHHH', font[offset + 6 + 12 * k:offset + 18 + 12 * k])
        start = offset + strings + at
        out[(p, e, l, n)] = font[start:start + length]
    return out, font


# ---------------------------------------------------------------------------
# The game's day's puzzle, ported (puzzle-almanac-stack.livecodescript:
# paRand, paOrder, paTransform, paBoxRows, paDailyNumbers, paDailyWord)

class Port:
    """The game's own random-number maker (Park and Miller's) and what it
    makes of a day: if this port and the game ever disagree, the engine
    test's day 310 and this one's do too"""

    def __init__(self):
        self.rand = 1

    def next(self, below):
        self.rand = (self.rand * 16807) % 2147483647
        return self.rand % below

    def order(self, count):
        items = list(range(count))
        for i in range(count, 1, -1):
            j = self.next(i) + 1
            items[i - 1], items[j - 1] = items[j - 1], items[i - 1]
        return items

    def transform(self, puzzle, answer, n, seed):
        box_rows = 3 if n == 9 else 2
        box_cols = n // box_rows
        self.rand = seed % 2147483646 + 1
        rows = [band * box_rows + inner for band in self.order(n // box_rows) for inner in self.order(box_rows)]
        cols = [band * box_cols + inner for band in self.order(n // box_cols) for inner in self.order(box_cols)]
        names = self.order(n)
        turn = self.next(2)
        out_puzzle, out_answer = '', ''
        for r in range(n):
            for c in range(n):
                if turn == 1:
                    tr, tc = rows[n - 1 - r], cols[n - 1 - c]
                else:
                    tr, tc = rows[r], cols[c]
                at = tr * n + tc
                v = int(puzzle[at])
                out_puzzle += str(names[v - 1] + 1) if v else '0'
                out_answer += str(names[int(answer[at]) - 1] + 1)
        return out_puzzle, out_answer


def daily_numbers(n, day, the_bank=None):
    the_bank = the_bank or bank()
    lines = the_bank[n]
    puzzle, answer = lines[(day * 7 + n) % len(lines)]
    return Port().transform(puzzle, answer, n, day * 97 + n)


def daily_word(length, day, the_answers=None):
    the_answers = the_answers or answers()
    lines = the_answers[length]
    step = next(s for s in (37, 41, 43, 47, 53, 59, 61) if math.gcd(s, len(lines)) == 1)
    return lines[(day * step + 11) % len(lines)]


def shape(n):
    return make_puzzles.Shape(n, *make_puzzles.SIZES[n][:2])


def digits(text):
    return [int(ch) for ch in text]


# ---------------------------------------------------------------------------


class BuiltFromItsScript(unittest.TestCase):

    def test_the_stack_holds_the_script(self):
        stack = stack_data()
        self.assertTrue(stack.startswith(b'REVO'))
        script = game_script().split('\n', 1)[1].rstrip('\n')
        self.assertIn(script.encode('utf-8'), stack,
                      'the committed stack is not built from puzzle-almanac-stack.livecodescript: '
                      'build it again (<engine> -ui tools/web-player/puzzle-almanac.livecodescript)')

    def test_the_stack_holds_the_puzzles_and_the_words(self):
        # numbers.txt and words.txt as they are; answers.txt without its
        # notes, a line at a time (the builder leaves its # lines out)
        stack = stack_data()
        for name in ('numbers.txt', 'words.txt'):
            self.assertIn(data(name).rstrip('\n').encode('utf-8'), stack,
                          'build the stack again: %s changed' % name)
        kept = [line for line in data('answers.txt').split('\n') if line and not line.startswith('#')]
        self.assertIn('\n'.join(kept).encode('utf-8'), stack, 'build the stack again: answers.txt changed')
        self.assertNotIn(b'# Puzzle Almanac: the hidden words', stack)

    def test_the_measure_sees_a_stale_stack(self):
        script = game_script().split('\n', 1)[1]
        changed = script.replace('paSound "coins", 0.8', 'paSound "coins", 0.7')
        self.assertNotEqual(changed, script)
        self.assertNotIn(changed.rstrip('\n').encode('utf-8'), stack_data())

    def test_the_builder_reads_the_script_and_saves_the_stack(self):
        text = builder()
        self.assertIn('puzzle-almanac-stack.livecodescript', text)
        self.assertIn('put "stacks/Puzzle Almanac.oxtstack" into the last item of tFile', text)
        self.assertIn('$OXT_PUZZLE_ALMANAC', text)
        for name in ('data/numbers.txt', 'data/words.txt', 'data/answers.txt'):
            self.assertIn('"%s"' % name, text)
        self.assertTrue(game_script().startswith('script "Puzzle Almanac"\n'))

    def test_the_page_can_ask_the_game(self):
        # the game's page (tools/pages/games/puzzle-almanac/) and its phone
        # check ask paState; the page tells it when it is hidden
        self.assertIn('set the cJavascriptHandlers of stack tName to "paPageHidden" & return & "paState"',
                      builder())
        for name in ('paPageHidden', 'paState'):
            self.assertRegex(game_script(), r'\n(?:on|function) %s\b' % name)


class Assets(unittest.TestCase):

    def test_every_picture_is_there_drawn_larger(self):
        pictures = art_list()
        self.assertEqual(len(pictures), 37)
        for name, file, width, height in pictures:
            with self.subTest(picture=name):
                path = os.path.join(ASSETS, 'art', file)
                self.assertTrue(os.path.isfile(path), path)
                w, h = png_size(path)
                self.assertGreaterEqual(w, 2 * width - 2)
                self.assertGreaterEqual(h, 2 * height - 2)
                self.assertLessEqual(w, 3 * width + 2)
                self.assertLessEqual(h, 3 * height + 2)

    def test_every_file_of_art_is_listed(self):
        listed = {file for _, file, _, _ in art_list()}
        there = {f for f in os.listdir(os.path.join(ASSETS, 'art')) if f != 'art.txt'}
        self.assertEqual(listed, there)

    def test_every_picture_the_game_names_is_there(self):
        names = {name for name, _, _, _ in art_list()}
        script = game_script()
        animals = re.search(r'^constant kAnimals = "([^"]*)"', script, re.M).group(1).split(',')
        self.assertEqual(len(animals), 30)
        self.assertEqual(len(set(animals)), 30)
        named = {'animal-' + a for a in animals}
        named |= set(re.findall(r'sPic\["([a-z-]+)"\]', script))
        named |= set(re.findall(r'put "((?:tile|sparkle)-[a-z]+)" into tPicture', script))
        named |= set(re.findall(r'paFit "([a-z-]+)"', script))
        named |= set(re.findall(r'makeSprite [^\n]*?, "([a-z-]+)", "', builder()))
        self.assertTrue({'star', 'sparkle-gold', 'sparkle-blue', 'tile-marble', 'tile-gold', 'tile-blue',
                         'tile-stone', 'animal-owl'} <= named, named)
        self.assertEqual(named, names, 'every picture is used, and every one used is there')

    def test_every_sound_the_game_plays_is_a_wav(self):
        script = game_script()
        played = set(re.findall(r'paSound "([a-z-]+)", ', script))
        played |= {'say-' + w for w in re.findall(r'paSay "([a-z]+)"', script)}
        played |= {'say-%d' % k for k in range(1, 10)}           # paSay pV: the number placed
        self.assertIn('paSay pV', script)
        self.assertIn('paSound "say-" & pWhat, 1', script)
        there = {f[:-4] for f in os.listdir(os.path.join(ASSETS, 'sounds')) if f.endswith('.wav')}
        self.assertEqual(played, there, 'every sound is played, and every one played is there')
        for name in there:
            with open(os.path.join(ASSETS, 'sounds', name + '.wav'), 'rb') as f:
                head = f.read(12)
            self.assertEqual((head[:4], head[8:12]), (b'RIFF', b'WAVE'), name)

    def test_the_font_has_the_name_the_web_engine_reads(self):
        # The web and Android engines' FreeType loader takes a font's family
        # from its Macintosh name record 4 (MCFreeTypeGetFontInfoFromData);
        # Atkinson Hyperlegible came with Windows records alone, and loaded
        # in no browser. make_assets.py adds the Macintosh ones
        pages = os.path.join(REPO, 'tools', 'pages', 'games', 'puzzle-almanac')
        for style in ('Regular', 'Bold'):
            full = ('Atkinson Hyperlegible %s' % style).encode('ascii')
            for folder in (os.path.join(ASSETS, 'fonts'), pages):
                path = os.path.join(folder, 'AtkinsonHyperlegible-%s.ttf' % style)
                with self.subTest(font=path):
                    names, font = font_names(path)
                    # each Macintosh record says what the Windows one does
                    for name_id in (1, 2, 4, 6):
                        self.assertEqual(names.get((1, 0, 0, name_id)),
                                         names[(3, 1, 0x409, name_id)].decode('utf-16-be').encode('mac-roman'))
                    self.assertEqual(names.get((1, 0, 0, 4)), full)
                    self.assertEqual(names.get((1, 0, 0, 1)), b'Atkinson Hyperlegible')
                    # the whole file sums as a font's must (head's checkSumAdjustment)
                    padded = font + b'\0' * (-len(font) % 4)
                    total = sum(struct.unpack('>%dI' % (len(padded) // 4), padded)) & 0xFFFFFFFF
                    self.assertEqual(total, 0xB1B0AFBA)
        self.assertIn('"Atkinson Hyperlegible"', game_script())

    def test_the_licences_and_sources(self):
        licences = sorted(os.listdir(os.path.join(ASSETS, 'licenses')))
        self.assertEqual(len(licences), 7, licences)
        for name in licences:
            text = read('tools', 'web-player', 'puzzle-almanac', 'licenses', name)
            if name.startswith('atkinson'):
                self.assertIn('SIL OPEN FONT LICENSE Version 1.1', text)
                # no Reserved Font Name, so the font with names added keeps its own
                self.assertTrue(text.startswith('Copyright 2020 Braille Institute of America, Inc.\n\n'))
            elif name.startswith('enable'):
                self.assertIn('Public Domain', text)
            else:
                self.assertIn('creativecommons.org/publicdomain/zero/1.0', text)
        sources = read('tools', 'web-player', 'puzzle-almanac', 'SOURCES.md')
        for folder in ('art', 'sounds', 'fonts'):
            for name in os.listdir(os.path.join(ASSETS, folder)):
                if name != 'art.txt':
                    self.assertIn('`%s/%s`' % (folder, name), sources)
        self.assertIn('`data/words.txt`', sources)
        for style in ('Regular', 'Bold'):
            self.assertRegex(sources, r'`fonts/AtkinsonHyperlegible-%s\.ttf` .*\| copied, with Macintosh name '
                                      r'records added \|' % style)

    def test_none_of_the_other_games_pictures(self):
        # a look of its own, from packs the other games do not use
        sources = read('tools', 'web-player', 'puzzle-almanac', 'SOURCES.md')
        packs = set(re.findall(r'^\| `[^`]+` \| Kenney, ([^|]+?) \|', sources, re.M))
        self.assertTrue(packs)
        pictures = {p for p in packs if not re.search(r'Audio|Voiceover', p)}
        for other in ('nova-rescue', 'wobble-forts'):
            theirs = read('tools', 'web-player', other, 'SOURCES.md')
            their_packs = set(re.findall(r'^\| `[^`]+` \| (?:Kenney, )?([^|]+?) \|', theirs, re.M))
            self.assertFalse(pictures & their_packs, (other, pictures & their_packs))


class Puzzles(unittest.TestCase):

    def test_as_many_of_each_size_as_make_puzzles_says(self):
        found = bank()
        self.assertEqual(sorted(found), [4, 6, 9])
        for n, (_, _, count, _) in make_puzzles.SIZES.items():
            self.assertEqual(len(found[n]), count, n)
            self.assertEqual(len({p for p, _ in found[n]}), count, 'each puzzle once')

    def test_each_has_one_answer_found_by_singles(self):
        for n, lines in bank().items():
            s = shape(n)
            min_given = make_puzzles.SIZES[n][3]
            for puzzle, answer in lines:
                with self.subTest(n=n, puzzle=puzzle):
                    self.assertEqual(len(puzzle), n * n)
                    self.assertEqual(len(answer), n * n)
                    self.assertRegex(answer, r'^[1-%d]+$' % n)
                    p, a = digits(puzzle), digits(answer)
                    self.assertTrue(all(v in (0, a[i]) for i, v in enumerate(p)), 'the puzzle is the answer\'s')
                    self.assertGreaterEqual(sum(1 for v in p if v), min_given)
                    for unit in s.units:
                        self.assertEqual(sorted(a[i] for i in unit), list(range(1, n + 1)))
                    self.assertEqual(make_puzzles.solve_by_singles(s, p), a)
            # (one answer: singles alone never choose, so they find the only one;
            # a full count on a sample says so the long way too)
            for puzzle, _ in lines[::40]:
                self.assertEqual(make_puzzles.count_answers(s, digits(puzzle)), 1)

    def test_the_singles_solver_is_not_a_full_one(self):
        # a 4 by 4 with two answers: a solver that guessed would fill it
        s = shape(4)
        two = digits('1200' '3400' '0000' '0000')
        self.assertEqual(make_puzzles.count_answers(s, two), 2)
        self.assertIn(0, make_puzzles.solve_by_singles(s, two))


class Words(unittest.TestCase):

    def test_the_hidden_words(self):
        words = set(data('words.txt').split('\n'))
        found = answers()
        self.assertEqual(sorted(found), [4, 5, 6])
        every = [w for length in found for w, _ in found[length]]
        self.assertGreaterEqual(len(every), 300)
        self.assertEqual(len(every), len(set(every)), 'each word once')
        for length, pairs in found.items():
            self.assertGreaterEqual(len(pairs), 80, length)
            for word, meaning in pairs:
                with self.subTest(word=word):
                    self.assertRegex(word, r'^[a-z]+$')
                    self.assertIn(word, words, 'a hidden word a try could not be')
                    self.assertRegex(meaning, r'^[A-Z][^\t]{3,}[.!?]$')
        # no line a game would read as a word of another length
        for line in data('answers.txt').split('\n'):
            if line and not line.startswith('#'):
                self.assertEqual(line.count('\t'), 1, line)
                self.assertIn(len(line.split('\t')[0]), (4, 5, 6), line)

    def test_the_words_a_try_may_be(self):
        words = [w for w in data('words.txt').split('\n') if w]
        self.assertGreater(len(words), 20000)
        self.assertEqual(words, sorted(set(words)))
        for word in words:
            self.assertRegex(word, r'^[a-z]{4,6}$')


class TheDaysPuzzles(unittest.TestCase):

    def test_day_310_is_today_in_the_engine_test(self):
        # kDayZero is 1 January 2026 at noon, a Thursday (dateItems: 5);
        # day 310 is 7 November 2026, which the engine test pins
        self.assertIn('constant kDayZero = "2026,1,1,12,0,0,5"', game_script())
        first = datetime.date(2026, 1, 1)
        self.assertEqual(first.isoweekday() % 7 + 1, 5)
        self.assertEqual(first + datetime.timedelta(days=310), datetime.date(2026, 11, 7))

    def test_the_port_gives_the_engines_day_310(self):
        for n in (4, 6, 9):
            puzzle, answer = engine_constant('kDay310Size%d' % n).split(':')
            self.assertEqual(daily_numbers(n, 310), (puzzle, answer), n)
        for length in (4, 5, 6):
            self.assertEqual(daily_word(length, 310)[0], engine_constant('kDay310Word%d' % length))

    def test_the_port_is_the_games(self):
        # the numbers the port uses are the game's
        script = game_script()
        for text in ('(sRand * 16807) mod 2147483647', 'paMod(pSeed, 2147483646) + 1',
                     'paMod(pDay * 7 + pN, tCount) + 1', 'pDay * 97 + pN', '"37,41,43,47,53,59,61"',
                     'paMod(pDay * tStep + 11, tCount) + 1', 'put paRand(2) into tTurn',
                     'repeat for each item tBand in paOrder(pN div tBoxRows)',
                     'repeat for each item tBand in paOrder(pN div tBoxCols)', 'put paOrder(pN) into tNames'):
            self.assertIn(text, script)

    def test_every_days_puzzle_has_one_answer_found_by_singles(self):
        # the transform renames, reorders and turns: none of that changes a
        # puzzle's having one answer, found by looking. Two years of days,
        # and a few far off, both ways
        the_bank = bank()
        shapes = {n: shape(n) for n in (4, 6, 9)}
        days = list(range(0, 730)) + [-400, -1, 5000, 36500]
        seen = {n: set() for n in shapes}
        for day in days:
            for n, s in shapes.items():
                puzzle, answer = daily_numbers(n, day, the_bank)
                with self.subTest(day=day, n=n):
                    p, a = digits(puzzle), digits(answer)
                    for unit in s.units:
                        self.assertEqual(sorted(a[i] for i in unit), list(range(1, n + 1)))
                    self.assertTrue(all(v in (0, a[i]) for i, v in enumerate(p)))
                    self.assertEqual(make_puzzles.solve_by_singles(s, p), a)
                seen[n].add(puzzle)
        for n in shapes:
            # day after day a puzzle of its own (the bank comes round again,
            # turned another way)
            self.assertGreater(len(seen[n]), len(days) * 0.95, n)

    def test_every_hidden_word_comes_before_any_comes_again(self):
        the_answers = answers()
        for length, pairs in the_answers.items():
            days = [daily_word(length, day, the_answers)[0] for day in range(len(pairs))]
            self.assertEqual(len(set(days)), len(pairs), length)
            self.assertEqual(daily_word(length, len(pairs), the_answers)[0], days[0])


class FitsAnIPhonesStack(unittest.TestCase):

    def test_no_statement_is_too_long(self):
        sys.path.insert(0, HERE)
        import test_mobile_web_check
        measure = test_mobile_web_check.FitsAnIPhonesStack().longest_statement
        for text in (game_script(), builder()):
            self.assertLessEqual(measure(text), 30)


class Offered(unittest.TestCase):

    def test_in_the_stack_players_samples(self):
        sys.path.insert(0, PLAYER)
        import build_player
        sample = [s for s in build_player.SAMPLES if s['title'] == 'Puzzle Almanac']
        self.assertEqual(len(sample), 1)
        self.assertEqual(sample[0]['files'], ['Puzzle Almanac.oxtstack'])
        self.assertEqual(sample[0]['image'], 'Puzzle Almanac.webp')
        self.assertEqual(sample[0]['source'], 'stacks')
        self.assertIn('Game', sample[0]['tags'])
        for name in ('Puzzle Almanac.oxtstack', 'Puzzle Almanac.webp'):
            self.assertTrue(os.path.isfile(os.path.join(PLAYER, 'stacks', name)), name)
        with open(os.path.join(PLAYER, 'stacks', 'Puzzle Almanac.webp'), 'rb') as f:
            head = f.read(12)
        self.assertEqual((head[:4], head[8:12]), (b'RIFF', b'WEBP'))

    def test_in_homes_gallery_with_an_icon(self):
        learn = read('ide', 'Toolset', 'palettes', 'learn', 'revlearn.livecodescript')
        kit = read('ide', 'Toolset', 'palettes', 'learn', 'revlearnkit.livecodescript')
        self.assertIn('Responsive Starter,Nova Rescue,Wobble Forts,', learn)
        self.assertRegex(learn, r'Nova Rescue,Wobble Forts," & \\\n\s+"Puzzle Almanac"\n')
        case = re.search(r'case "Puzzle Almanac"\n(.*?)\n      case', learn, re.S)
        self.assertIsNotNone(case)
        icon = re.search(r'\|([a-z0-9-]+)\|[a-z]+\|[^|"]+"', case.group(0)).group(1)
        self.assertEqual(icon, 'puzzle')
        self.assertIn('case "%s"' % icon, kit)

    def test_in_the_notices(self):
        notices = read('THIRD-PARTY-NOTICES.md')
        self.assertIn('`tools/web-player/puzzle-almanac/`', notices)
        self.assertIn('`tools/pages/games/puzzle-almanac/`', notices)
        self.assertIn('Atkinson Hyperlegible (`AtkinsonHyperlegible-Regular.ttf`', notices)
        self.assertIn('ENABLE', notices)


class Check(unittest.TestCase):

    def test_every_handler_the_check_calls_is_there_and_asked_for(self):
        check = read('tools', 'ci', 'puzzle_almanac_check.py')
        stack = read('tools', 'ci', 'puzzle-almanac-check.livecodescript')
        called = set(re.findall(r"call\(page, '(pc\w+)'", check))
        called |= set(re.findall(r"h\.(pc\w+)\b", check))
        self.assertEqual(called, set(puzzle_almanac_check.HANDLERS))
        defined = set(re.findall(r'^(?:function|command) (pc\w+)', stack, re.M))
        for name in sorted(called):
            self.assertIn(name, defined, 'puzzle-almanac-check.livecodescript has no %s' % name)
        self.assertIn('script "%s"' % puzzle_almanac_check.CHECK_NAME, stack)
        self.assertIn("findStackWithName('%s')" % puzzle_almanac_check.CHECK_NAME, puzzle_almanac_check.CALL)
        self.assertIn("findStackWithName('%s')" % puzzle_almanac_check.CHECK_NAME, puzzle_almanac_check.OPEN)

    def test_the_check_stack_hears_script_errors(self):
        stack = read('tools', 'ci', 'puzzle-almanac-check.livecodescript')
        self.assertIn('insert the script of me into back', stack)
        self.assertRegex(stack, r'on errorDialog pError\n   put pError & return')

    def test_the_check_finds_its_files(self):
        for path in (puzzle_almanac_check.GAME, puzzle_almanac_check.GAME_BUILDER,
                     puzzle_almanac_check.CHECK_STACK, mobile_web_check.DEPLOY_SCRIPT, mobile_web_check.LIBRARY):
            self.assertTrue(os.path.isfile(path), path)

    def test_the_game_has_what_the_check_reads(self):
        check = read('tools', 'ci', 'puzzle_almanac_check.py')
        script = game_script()
        keys = set(re.findall(r"s\.get\('([a-z ]+)'", check)) | set(re.findall(r"s\['([a-z ]+)'\]", check))
        keys |= set(re.findall(r"number\(s, '([a-z ]+)'", check))
        self.assertTrue({'screen', 'panel', 'stickers', 'award', 'board', 'answer', 'over', 'side'} <= keys, keys)
        for key in keys:
            self.assertIn('"%s:"' % key, script, key)
        # the controls it taps and measures
        names = set(re.findall(r"(?:tap\(|middle\(page, |'pcRect', )'([A-Z][A-Za-z0-9 ]+)'", check))
        self.assertTrue({'Numbers Card', 'Words Card', 'Done Home', 'Howto Done', 'Stickers Open'} <= names, names)
        made = builder()
        for name in names:
            word = re.match(r'(.*?) ?([A-Z]|\d+|Enter|Back)?$', name)
            self.assertTrue('"%s"' % name in made
                            or '"%s" &&' % word.group(1) in made
                            or re.search(r'"%s" && ' % re.escape(name.rsplit(' ', 1)[0]), made), name)

    def test_chromium_and_webkit_in_web_yml(self):
        web = read('.github', 'workflows', 'web.yml')
        step = re.search(r"- name: Play Puzzle Almanac on phones.*?(?=\n      - name:|\Z)", web, re.S)
        self.assertIsNotNone(step)
        self.assertIn("if: matrix.browser != 'firefox'", step.group(0))
        self.assertIn('tools/ci/puzzle_almanac_check.py', step.group(0))
        self.assertIn('--browser "$BROWSER"', step.group(0))
        self.assertIn('puzzle-almanac', step.group(0))
        self.assertEqual(sorted(puzzle_almanac_check.DEFAULT_DEVICES), ['chromium', 'webkit'])

    def test_parse_state(self):
        s = puzzle_almanac_check.parse_state('screen:home\nboard rect:10,20,30,40\nstickers:2\n\nnonsense')
        self.assertEqual(s, {'screen': 'home', 'board rect': '10,20,30,40', 'stickers': '2'})
        self.assertEqual(puzzle_almanac_check.number(s, 'stickers'), 2.0)
        self.assertIsNone(puzzle_almanac_check.number(s, 'today'))

    def test_rect(self):
        self.assertEqual(puzzle_almanac_check.rect('272,0,572,390'), [272, 0, 572, 390])
        self.assertEqual(puzzle_almanac_check.rect('-4,10.6,20,30'), [-4, 10, 20, 30])
        self.assertIsNone(puzzle_almanac_check.rect('hidden'))
        self.assertIsNone(puzzle_almanac_check.rect('1,2,3'))


class EngineTests(unittest.TestCase):

    def test_the_tests_use_the_games_hooks(self):
        tests = engine_tests()
        script = game_script()
        hooks = set(re.findall(r'"(pa[A-Z]\w+)"', tests))
        self.assertTrue({'paTestBegin', 'paTestStep', 'paState', 'paPress', 'paDailyNumbers', 'paDailyWord',
                         'paScore', 'paDayOf'} <= hooks, hooks)
        for name in hooks:
            self.assertRegex(script, r'\n(?:on|command|function) %s\b' % name, name)
        self.assertGreaterEqual(len(re.findall(r'^on Test(?!Setup|Teardown)', tests, re.M)), 40)

    def test_a_board_is_compared_digit_for_digit(self):
        # "is" compares two strings of digits as numbers, to 15 digits or
        # so: a 9 by 9 board right in its first rows only "is" its answer.
        # The game and its tests compare boards as text
        script = game_script()
        self.assertIn('return ("n" & pA) is ("n" & pB)', script)
        self.assertGreaterEqual(script.count('paSameDigits('), 2)
        for found in re.finditer(r'^[^-\n]*\b(?:sN\["(?:board|answer|given)"\]|pSaved\["board"\]|tGiven)'
                                 r' is (?:not )?(?:sN\[|tGiven|pSaved)', script, re.M):
            self.fail('a board compared with a bare "is": %s' % found.group(0).strip())
        tests = engine_tests()
        self.assertIn('("n" & pA) is ("n" & pB)', tests)
        self.assertGreaterEqual(tests.count('sameBoard('), 8)

    def test_the_tests_pin_the_day(self):
        tests = engine_tests()
        for n in (4, 6, 9):
            self.assertRegex(engine_constant('kDay310Size%d' % n), r'^[0-%d]{%d}:[1-%d]{%d}$' % (n, n * n, n, n * n))
        self.assertIn('answerOf("paDailyNumbers", 9, 310) is kDay310Size9', tests)


if __name__ == '__main__':
    unittest.main()
