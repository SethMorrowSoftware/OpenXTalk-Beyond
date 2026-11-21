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

"""tools/ci/window_opacity_check.py: how it judges a picture of the window
(a Mac) and xprop's answer for its opacity (Linux), the verdict of a run
(the two windows it needs to judge at all, and the two it checks), a whole
run with a made-up engine, and that the script and the check agree. Also
the engine's fix the check was written for (the forum's report of
2026-11-21 that on a Mac the IDE's Message Box never appeared): a stack's
blendLevel set again before its window was updated no longer loses the
set before it, and every desktop and web window records the opacity it is
made with.

  python3 -m unittest discover -s tools/ci/tests
"""

import contextlib
import io
import os
import re
import shutil
import stat
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import window_opacity_check as woc  # noqa: E402
from test_visual_effect_check import png  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', '..'))
GREEN = (0, 255, 0)
# a Mac's green through a display colour profile
PROFILED_GREEN = (98, 222, 64)
DESKTOP = (40, 90, 160)


def rows(colour, width=40, height=30):
    return [[colour] * width for _ in range(height)]


def half(width=40, height=30):
    return [[GREEN] * (width // 2) + [DESKTOP] * (width - width // 2) for _ in range(height)]


class Pictures(unittest.TestCase):
    def state(self, picture):
        return woc.state_of_share(woc.colour_share(len(picture[0]), len(picture), picture))

    def test_the_window_shown(self):
        self.assertEqual(self.state(rows(GREEN)), woc.SHOWN)
        self.assertEqual(self.state(rows(PROFILED_GREEN)), woc.SHOWN)

    def test_the_desktop_through_a_window_at_99(self):
        self.assertEqual(self.state(rows(DESKTOP)), woc.CLEAR)
        # 2 of 255 of green over the desktop
        self.assertEqual(self.state(rows((40, 92, 159))), woc.CLEAR)

    def test_half_of_it(self):
        self.assertEqual(self.state(half()), woc.PARTLY)

    def test_a_picture_read_from_a_png_file(self):
        w, h, r = woc.vec.read_png(png(rows(GREEN)))
        self.assertEqual(woc.state_of_share(woc.colour_share(w, h, r)), woc.SHOWN)


class Xprop(unittest.TestCase):
    def test_answers(self):
        self.assertEqual(woc.parse_xprop_opacity('_NET_WM_WINDOW_OPACITY:  not found.'), 1.0)
        self.assertEqual(woc.parse_xprop_opacity('_NET_WM_WINDOW_OPACITY:  no such atom on any window.'), 1.0)
        # blendLevel 99: the engine's 2 of 255 (setopacity(1 * 255 / 100))
        clear = woc.parse_xprop_opacity('_NET_WM_WINDOW_OPACITY(CARDINAL) = 33686018')
        self.assertAlmostEqual(clear, 2 / 255.0, places=6)
        self.assertEqual(woc.state_of_opacity(clear), woc.CLEAR)
        self.assertEqual(woc.state_of_opacity(woc.parse_xprop_opacity('_NET_WM_WINDOW_OPACITY(CARDINAL) = 2147483647')),
                         woc.PARTLY)
        self.assertEqual(woc.state_of_opacity(1.0), woc.SHOWN)

    def test_what_xprop_does_not_answer(self):
        self.assertIsNone(woc.parse_xprop_opacity('xprop: error: Invalid window id format: x.'))
        self.assertIsNone(woc.parse_xprop_opacity('_NET_WM_WINDOW_OPACITY(CARDINAL) = many'))
        self.assertEqual(woc.state_of_opacity(None), woc.UNKNOWN)


def shot(name, expected, state):
    return (name, expected, state, 'made up')


ALL_SHOWN = [shot('seen', 'shown', 'shown'), shot('see-through', 'clear', 'clear'),
             shot('set-twice', 'shown', 'shown'), shot('reopened', 'shown', 'shown')]


class Verdict(unittest.TestCase):
    def verdict(self, shots, done=True, errors=(), report_only=False):
        with contextlib.redirect_stdout(io.StringIO()) as said:
            code = woc.verdict(shots, done, list(errors), report_only)
        return code, said.getvalue()

    def test_every_window_as_expected(self):
        code, said = self.verdict(ALL_SHOWN)
        self.assertEqual(code, 0, said)
        self.assertIn('Every window was at the opacity of its blendLevel.', said)

    def test_the_lost_set(self):
        # 0.2.8-dp.2 on Linux (the window's property) and, as the forum
        # reported it, on a Mac: both left at the opacity of 99
        shots = ALL_SHOWN[:2] + [shot('set-twice', 'shown', 'clear'), shot('reopened', 'shown', 'clear')]
        code, said = self.verdict(shots)
        self.assertEqual(code, 1, said)
        self.assertIn('::error::windows not at the opacity of their blendLevel: set-twice, reopened', said)

    def test_report_only(self):
        shots = ALL_SHOWN[:3] + [shot('reopened', 'shown', 'clear')]
        code, said = self.verdict(shots, report_only=True)
        self.assertEqual(code, 0, said)
        self.assertIn('::warning::windows not at the opacity of their blendLevel: reopened', said)

    def test_a_window_never_seen(self):
        shots = [shot('seen', 'shown', 'clear')] + ALL_SHOWN[1:]
        code, said = self.verdict(shots)
        self.assertEqual(code, 2, said)
        self.assertIn('never saw the window', said)

    def test_an_opacity_the_screen_does_not_show(self):
        # a screen that draws a window at 99 as it draws one at 0 cannot
        # tell a lost set from a kept one: every window would pass
        shots = [ALL_SHOWN[0], shot('see-through', 'clear', 'shown')] + ALL_SHOWN[2:]
        code, said = self.verdict(shots)
        self.assertEqual(code, 2, said)
        self.assertIn('cannot tell a window\'s opacity', said)

    def test_not_finished_and_script_errors(self):
        code, said = self.verdict(ALL_SHOWN[:3], done=False)
        self.assertEqual(code, 1, said)
        self.assertIn('(the script did not finish)', said)
        code, said = self.verdict(ALL_SHOWN, errors=['script line 3: no such object'])
        self.assertEqual(code, 2, said)
        self.assertIn('::error::the script: script line 3: no such object', said)


# A stand-in engine: the lines window-opacity-check.livecodescript writes,
# each SHOT waiting for its go- file, as the script does
ENGINE = '''#!/bin/sh
l="$OXT_WO_DIR/log.txt"
printf 'INFO\\tversion\\tmade up\\n' >> "$l"
for s in seen:shown see-through:clear set-twice:shown reopened:shown; do
  name=${s%%:*}
  printf 'SHOT\\t%s\\t%s\\t200,200,600,500\\t%s\\n' "$name" "${s#*:}" "$name-window" >> "$l"
  n=0
  while [ ! -e "$OXT_WO_DIR/go-$name" ]; do
    n=$((n + 1)); [ $n -gt 100 ] && { printf 'ERROR\\t%s\\tno go\\n' "$name" >> "$l"; exit 0; }
    sleep 0.1
  done
done
printf 'DONE\\n' >> "$l"
'''


@unittest.skipIf(os.name == 'nt', 'the stand-in engine is a shell script')
class Run(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.mkdtemp()
        self.engine = os.path.join(self.tmp, 'engine')
        with open(self.engine, 'w') as f:
            f.write(ENGINE)
        os.chmod(self.engine, os.stat(self.engine).st_mode | stat.S_IXUSR)
        self.out = os.path.join(self.tmp, 'out')

    def tearDown(self):
        shutil.rmtree(self.tmp)

    def run_check(self, states, report_only=False):
        looked = []

        def look(name, rect, window_id):
            looked.append((name, rect, window_id))
            return states.get(name, woc.SHOWN), 'made up', None
        args = woc.argparse.Namespace(app=None, engine=self.engine, out=self.out, timeout=60,
                                      report_only=report_only)
        with contextlib.redirect_stdout(io.StringIO()) as said:
            code = woc.run(args, look=look, env=dict(os.environ))
        return code, said.getvalue(), looked

    def test_windows_at_their_opacity(self):
        code, said, looked = self.run_check({'see-through': woc.CLEAR})
        self.assertEqual(code, 0, said)
        self.assertEqual([n for n, _, _ in looked], ['seen', 'see-through', 'set-twice', 'reopened'])
        self.assertEqual(looked[0][1], (200, 200, 600, 500))
        self.assertEqual(looked[3][2], 'reopened-window')
        # each window looked at once, the script let go on after each
        for name in ('seen', 'see-through', 'set-twice', 'reopened'):
            self.assertTrue(os.path.isfile(os.path.join(self.out, 'work', 'go-' + name)))

    def test_windows_left_see_through(self):
        code, said, _ = self.run_check({'see-through': woc.CLEAR, 'set-twice': woc.CLEAR,
                                        'reopened': woc.CLEAR})
        self.assertEqual(code, 1, said)
        self.assertIn('set-twice, reopened', said)

    def test_report_only(self):
        code, said, _ = self.run_check({'see-through': woc.CLEAR, 'reopened': woc.CLEAR}, report_only=True)
        self.assertEqual(code, 0, said)
        self.assertIn('::warning::', said)


class Script(unittest.TestCase):
    """The script and the check agree on the windows and the colour."""

    def setUp(self):
        with open(woc.SCRIPT, encoding='utf-8') as f:
            self.text = f.read()

    def test_the_windows(self):
        shots = re.findall(r'^\s*shot "([^"]+)", "([^"]+)"', self.text, re.M)
        self.assertEqual(shots, [('seen', 'shown'), ('see-through', 'clear'), ('set-twice', 'shown'),
                                 ('reopened', 'shown')])
        for name, expected in woc.CONTROLS.items():
            self.assertIn((name, expected), shots)

    def test_the_colour(self):
        m = re.search(r'^constant kColour = "(\d+),(\d+),(\d+)"', self.text, re.M)
        self.assertIsNotNone(m)
        self.assertEqual(tuple(int(v) for v in m.groups()), woc.COLOUR)
        self.assertTrue(woc.is_colour(woc.COLOUR))

    def test_the_message_box_way(self):
        # the reopened window is made by "go invisible ... as palette" at
        # blendLevel 99, closed, set to 0 twice while closed and opened as
        # a palette: the Message Box's start and its open from the menu
        body = self.text[self.text.index('-- 4.'):self.text.index('end runOpacityCheck')]
        steps = [line.strip() for line in body.splitlines()
                 if line.strip() and not line.strip().startswith('--')]
        self.assertEqual(steps, [
            'makeStack kPalette',
            'close stack kPalette',
            'set the blendLevel of stack kPalette to 99',
            'go invisible stack kPalette as palette',
            'close stack kPalette',
            'set the visible of stack kPalette to true',
            'set the blendLevel of stack kPalette to 0',
            'set the blendLevel of stack kPalette to 0',
            'palette stack kPalette',
            'wait 1 second with messages',
            'shot "reopened", "shown", kPalette',
            'close stack kPalette',
        ])


def read(*parts):
    with open(os.path.join(ROOT, *parts), encoding='utf-8') as f:
        return f.read()


def code_of(text):
    """C++ without its comments."""
    text = re.sub(r'/\*.*?\*/', '', text, flags=re.S)
    return re.sub(r'//[^\n]*', '', text)


def function(text, signature):
    m = re.search(re.escape(signature) + r'.*?\n\}', text, re.S)
    if m is None:
        raise AssertionError('no %s' % signature)
    return code_of(m.group(0))


class EngineFix(unittest.TestCase):
    """old_blendlevel is the opacity the stack's window was last given;
    applyupdates gives the window the blendLevel when the two differ."""

    def test_a_set_does_not_move_it_on_the_desktop_or_the_web(self):
        body = function(read('engine', 'src', 'exec-interface-stack.cpp'),
                        'void MCStack::SetBlendLevel(MCExecContext& ctxt, uinteger_t p_level)')
        # moved on only where nothing gives the window its opacity after
        m = re.search(r'#if !\(defined\(_DESKTOP\) \|\| defined\(__EMSCRIPTEN__\)\)\s*'
                      r'old_blendlevel = blendlevel;\s*#endif', body)
        self.assertIsNotNone(m, body)
        self.assertEqual(body.count('old_blendlevel'), 1, body)

    def test_applyupdates_gives_the_window_the_blendlevel(self):
        body = function(read('engine', 'src', 'stack2.cpp'), 'void MCStack::applyupdates(void)')
        self.assertIn('if (window != nil && old_blendlevel != blendlevel)', body)

    def test_each_window_records_the_opacity_it_is_made_with(self):
        mac = function(read('engine', 'src', 'desktop-stack.cpp'), 'void MCStack::realize(void)')
        given = mac.index('setopacity(blendlevel * 255 / 100);')
        self.assertLess(given, mac.index('old_blendlevel = blendlevel;'))

        web = function(read('engine', 'src', 'em-stack.cpp'), 'MCStack::realize()')
        self.assertLess(web.index('setopacity(blendlevel * 255 / 100);'), web.index('old_blendlevel = blendlevel;'))

        win = function(read('engine', 'src', 'w32stack.cpp'), 'void MCStack::realize()')
        self.assertLess(win.index('setopacity(blendlevel * 255 / 100);'),
                        win.index('if (m_window_shape == NULL || m_window_shape -> is_sharp)\n\t\t\told_blendlevel = blendlevel;'))

        # Linux gives a new window no opacity: it is opaque until
        # applyupdates gives it the blendLevel
        lnx = function(read('engine', 'src', 'lnxstack.cpp'), 'void MCStack::realize()')
        self.assertLess(lnx.index('window = gdk_window_new('), lnx.index('old_blendlevel = 100;'))
        self.assertNotIn('setopacity', lnx)


if __name__ == '__main__':
    unittest.main()
