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
"""Beyond Beats (tools/web-player/stacks/Beyond Beats.oxtstack) held to the
files it is made from, without a browser or an engine:

- the committed stack is built from beyond-beats-stack.livecodescript and
  beyond-beats/audio-core.js: the stack file holds the script and the
  core, as they are (a change there that was never built fails here)
- the kit is the same sixteen sounds, in the same order, in the core, the
  stack's script and its builder; there is a colour for every channel
- every control btLayout places is on the card, which is the size the
  builder makes it, and the browser check clicks where the stack's Play
  button and pads are
- the core answers "ok" as its last expression, and keeps to ASCII, as
  the stack's script does
- it is offered: in the Stack Player's samples with its picture, checked
  by build_player.py --check, and in the player's README; Beat Box, which
  it grew from, is still there as it was

  python3 -m unittest discover -s tools/ci/tests
"""

import os
import re
import sys
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
CI = os.path.dirname(HERE)
REPO = os.path.dirname(os.path.dirname(CI))
sys.path.insert(0, CI)
import beyond_beats_check  # noqa: E402

PLAYER = os.path.join(REPO, 'tools', 'web-player')
STACK = os.path.join(PLAYER, 'stacks', 'Beyond Beats.oxtstack')


def read(*parts):
    with open(os.path.join(REPO, *parts), encoding='utf-8') as f:
        return f.read()


def stack_script():
    return read('tools', 'web-player', 'beyond-beats-stack.livecodescript')


def builder():
    return read('tools', 'web-player', 'beyond-beats.livecodescript')


def core():
    return read('tools', 'web-player', 'beyond-beats', 'audio-core.js')


def constant(name, text):
    """A constant of a script, as written (a string without its quotes)"""
    m = re.search(r'^constant %s = (.*)$' % re.escape(name), text, re.M)
    assert m, name
    return m.group(1).strip().strip('"')


def stack_bytes():
    with open(STACK, 'rb') as f:
        return f.read()


class BuiltFromItsFiles(unittest.TestCase):

    def test_the_stack_holds_the_script(self):
        data = stack_bytes()
        self.assertTrue(data.startswith(b'REVO'))
        script = stack_script().split('\n', 1)[1].rstrip('\n')
        self.assertIn(script.encode('utf-8'), data,
                      'the committed stack is not built from beyond-beats-stack.livecodescript: '
                      'build it again (<engine> -ui tools/web-player/beyond-beats.livecodescript)')

    def test_the_stack_holds_the_audio_core(self):
        self.assertIn(core().rstrip('\n').encode('utf-8'), stack_bytes(),
                      'the committed stack is not built from beyond-beats/audio-core.js: build it again')
        self.assertIn('set the cAudioCore of stack kStack to textFile("beyond-beats/audio-core.js")', builder())
        self.assertIn('do the cAudioCore of me as "JavaScript"', stack_script())

    def test_the_measure_sees_a_stale_stack(self):
        script = stack_script().split('\n', 1)[1]
        changed = script.replace('constant kMaxPatterns = 16', 'constant kMaxPatterns = 15')
        self.assertNotEqual(changed, script)
        self.assertNotIn(changed.rstrip('\n').encode('utf-8'), stack_bytes())

    def test_the_builder_reads_the_script_and_saves_the_stack(self):
        text = builder()
        self.assertIn('textFile("beyond-beats-stack.livecodescript", true)', text)
        self.assertIn('put "stacks/Beyond Beats.oxtstack" into the last item of tFile', text)
        self.assertIn('$OXT_BEYOND_BEATS', text)
        self.assertTrue(stack_script().startswith('script "Beyond Beats"\n'))


class OneKit(unittest.TestCase):

    def core_kit(self):
        m = re.search(r"var KIT = \[(.*?)\];", core(), re.S)
        self.assertTrue(m)
        return re.findall(r"'([^']+)'", m.group(1))

    def test_the_kit_is_the_same_everywhere(self):
        kit = self.core_kit()
        self.assertEqual(len(kit), 16)
        self.assertEqual(constant('kKit', stack_script()).split(','), kit)
        self.assertEqual(constant('kKit', builder()).split(','), kit)
        self.assertEqual(int(constant('kKitSize', stack_script())), len(kit))
        self.assertEqual(beyond_beats_check.stack_kit(), kit)

    def test_every_sound_has_a_maker(self):
        makers = re.search(r'var MAKERS = \[(.*)\n  \];', core(), re.S).group(1)
        # each maker is "[seconds, function (n, r) {"
        self.assertEqual(len(re.findall(r'^\s*\[[0-9.]+, function \(n, r\)', makers, re.M)), 16)

    def test_a_colour_for_every_channel(self):
        script = stack_script()
        channels = int(constant('kMaxChannels', script))
        self.assertEqual(channels, int(constant('kMaxChannels', builder())))
        colours = constant('kColors', script).split(',')
        self.assertEqual(len(colours), channels)
        self.assertEqual(len(set(colours)), channels)
        for c in colours:
            self.assertRegex(c, r'^#[0-9A-F]{6}$')


class Layout(unittest.TestCase):

    def test_the_window_the_stack_is_built_with(self):
        text = builder()
        self.assertIn('set the cWindow of stack kStack to kWidth & comma & kHeight', text)
        self.assertEqual((constant('kWidth', text), constant('kHeight', text)), ('960', '600'))

    def test_every_control_is_on_the_card(self):
        layout = stack_script().split('command btLayout', 1)[1].split('end btLayout', 1)[0]
        rects = re.findall(r'set the rect of \w+ "?([^"]*?)"? to (\d+), (\d+), (\d+), (\d+)$', layout, re.M)
        self.assertGreater(len(rects), 30)
        for name, *box in rects:
            left, top, right, bottom = map(int, box)
            self.assertTrue(0 <= left < right <= 960 and 0 <= top < bottom <= 600, '%s %s' % (name, box))

    def test_the_grid_fits_the_rack(self):
        script = stack_script()
        grid_left, grid_width = int(constant('kGridLeft', script)), int(constant('kGridWidth', script))
        row_top, row_h = int(constant('kRowTop', script)), int(constant('kRowH', script))
        channels = int(constant('kMaxChannels', script))
        # the rack is 192..952 across and 68..560 down
        self.assertLessEqual(grid_left + grid_width, 952)
        self.assertLessEqual(row_top + channels * row_h, 560)

    def test_the_check_clicks_where_the_stack_is(self):
        script = stack_script()
        self.assertEqual(beyond_beats_check.GRID_LEFT, int(constant('kGridLeft', script)))
        self.assertEqual(beyond_beats_check.GRID_WIDTH, int(constant('kGridWidth', script)))
        self.assertEqual(beyond_beats_check.ROW_TOP, int(constant('kRowTop', script)))
        self.assertEqual(beyond_beats_check.ROW_H, int(constant('kRowH', script)))
        self.assertEqual(beyond_beats_check.PAD_H, int(constant('kPadH', script)))
        m = re.search(r'set the rect of button "Play" to (\d+), (\d+), (\d+), (\d+)', script)
        left, top, right, bottom = map(int, m.groups())
        x, y = beyond_beats_check.PLAY
        self.assertTrue(left < x < right and top < y < bottom)


class TheCore(unittest.TestCase):

    def test_it_answers_ok(self):
        last = [line for line in core().strip().split('\n') if line.strip()][-1]
        self.assertIn("? 'ok' : 'none'", last)

    def test_ascii_only(self):
        for name, text in (('audio-core.js', core()), ('beyond-beats-stack.livecodescript', stack_script()),
                           ('beyond-beats.livecodescript', builder())):
            bad = [c for c in text if ord(c) > 126 or (ord(c) < 32 and c not in '\n\t')]
            self.assertEqual(bad, [], name)

    def test_it_never_calls_the_stack(self):
        # the page tells the stack nothing: the stack asks
        self.assertNotIn('liveCode', core())
        self.assertNotIn('findStackWithName', core())


class Offered(unittest.TestCase):

    def test_a_sample_with_its_picture(self):
        text = read('tools', 'web-player', 'build_player.py')
        self.assertIn("'files': ['Beyond Beats.oxtstack'], 'image': 'Beyond Beats.webp'", text)
        self.assertTrue(os.path.isfile(os.path.join(PLAYER, 'stacks', 'Beyond Beats.webp')))
        # Beat Box, the short example, is still there as it was
        self.assertIn("'files': ['Beat Box.oxtstack'], 'image': 'Beat Box.webp'", text)
        self.assertTrue(os.path.isfile(os.path.join(PLAYER, 'stacks', 'Beat Box.oxtstack')))

    def test_the_player_checks_it(self):
        text = read('tools', 'web-player', 'build_player.py')
        self.assertIn('beyond_beats_check.check_core(p,', text)
        self.assertIn("'?play=Beyond%20Beats'", text)

    def test_the_readme_says_so(self):
        text = read('tools', 'web-player', 'README.md')
        self.assertIn('## Beyond Beats', text)
        self.assertIn('**Beyond Beats**', text)

    def test_the_engine_tests_drive_it(self):
        tests = read('tests', 'lcs', 'webplayer', 'beyond-beats.livecodescript')
        handlers = set(re.findall(r'^(?:command|function|on) (bt\w+)', stack_script(), re.M))
        called = set(re.findall(r'"(bt\w+)"', tests))
        self.assertTrue(called)
        self.assertEqual(called - handlers, set(), 'the tests call handlers the stack does not have')


if __name__ == '__main__':
    unittest.main()
