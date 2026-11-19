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

"""tools/ci/visual_effect_check.py: how it reads screencapture's PNG files,
how it judges a picture and an effect's pictures (an effect that plays, the
card that just changes of the report on 0.2.7 with macOS 15, and the
flicker of frames drawn by turns with and without the effect), and a whole
run with a made-up engine and made-up pictures. Also that the engine waits
for an effect frame's draw before it clears the callback that draws it
(engine/src/desktop-stack.cpp), the fix the check was written for.

  python3 -m unittest discover -s tools/ci/tests
"""

import contextlib
import io
import os
import re
import shutil
import stat
import struct
import sys
import tempfile
import time
import unittest
import zlib

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))

import visual_effect_check as vec  # noqa: E402

# The made-up screencapture reads marks.txt as it is; a test that makes the
# check's own reads catch the file being rewritten replaces vec.read_marks
READ_MARKS = vec.read_marks

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', '..'))
BLACK, WHITE, GREY = (0, 0, 0), (255, 255, 255), (128, 128, 128)


def chunk(kind, body):
    return struct.pack('>I', len(body)) + kind + body + struct.pack('>I', zlib.crc32(kind + body) & 0xffffffff)


def filtered(kind, line, prev, bpp):
    """A row with PNG filter kind applied (the encoder's side)."""
    out = bytearray(len(line))
    for i in range(len(line)):
        a = line[i - bpp] if i >= bpp else 0
        b = prev[i]
        c = prev[i - bpp] if i >= bpp else 0
        if kind == 0:
            pred = 0
        elif kind == 1:
            pred = a
        elif kind == 2:
            pred = b
        elif kind == 3:
            pred = (a + b) // 2
        else:
            p = a + b - c
            pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
            pred = a if pa <= pb and pa <= pc else b if pb <= pc else c
        out[i] = (line[i] - pred) & 0xff
    return out


def png(rows, alpha=True):
    """A PNG file of rows of (r, g, b), RGBA or RGB, each row with the
    next of the five filters in turn."""
    height, width = len(rows), len(rows[0])
    bpp = 4 if alpha else 3
    raw = bytearray()
    prev = bytearray(width * bpp)
    for y, row in enumerate(rows):
        line = bytearray()
        for r, g, b in row:
            line += bytes((r, g, b, 255) if alpha else (r, g, b))
        kind = y % 5
        raw.append(kind)
        raw += filtered(kind, line, prev, bpp)
        prev = line
    return (b'\x89PNG\r\n\x1a\n'
            + chunk(b'IHDR', struct.pack('>IIBBBBB', width, height, 8, 6 if alpha else 2, 0, 0, 0))
            + chunk(b'IDAT', zlib.compress(bytes(raw)))
            + chunk(b'IEND', b''))


def picture(kind, width=40, height=30, progress=0.5, source=BLACK, target=WHITE):
    """Rows of a picture: the source card, the target card, a dissolve's
    blend, or a wipe from the left, at progress."""
    if kind == 'from':
        return [[source] * width for _ in range(height)]
    if kind == 'to':
        return [[target] * width for _ in range(height)]
    if kind == 'dissolve':
        mix = tuple(int(s + (t - s) * progress) for s, t in zip(source, target))
        return [[mix] * width for _ in range(height)]
    edge = int(width * progress)
    return [[target] * edge + [source] * (width - edge) for _ in range(height)]


class Pictures(unittest.TestCase):
    def test_reads_rgba_and_rgb_with_every_filter(self):
        rows = [[((x * 7 + y) % 256, (x * 3) % 256, (y * 11) % 256) for x in range(13)] for y in range(11)]
        for alpha in (True, False):
            w, h, got = vec.read_png(png(rows, alpha))
            self.assertEqual((w, h), (13, 11))
            self.assertEqual(got, rows)

    def test_refuses_what_is_not_a_png_file(self):
        with self.assertRaises(ValueError):
            vec.read_png(b'GIF89a')

    def judge(self, rows):
        return vec.judge_picture(len(rows[0]), len(rows), rows, 'black', 'white')

    def test_the_two_cards(self):
        self.assertEqual(self.judge(picture('from')), vec.FROM)
        self.assertEqual(self.judge(picture('to')), vec.TO)

    def test_a_dissolve_and_a_wipe_are_between(self):
        self.assertEqual(self.judge(picture('dissolve', progress=0.5)), vec.BETWEEN)
        self.assertEqual(self.judge(picture('wipe', progress=0.3)), vec.BETWEEN)
        self.assertEqual(self.judge(picture('wipe', progress=0.8)), vec.BETWEEN)

    def test_white_to_black(self):
        rows = picture('from', source=WHITE)
        self.assertEqual(vec.judge_picture(40, 30, rows, 'white', 'black'), vec.FROM)
        rows = picture('to', target=BLACK)
        self.assertEqual(vec.judge_picture(40, 30, rows, 'white', 'black'), vec.TO)


class Effects(unittest.TestCase):
    F, B, T = vec.FROM, vec.BETWEEN, vec.TO

    def test_an_effect_that_plays(self):
        verdict, _ = vec.judge_effect([self.F, self.F, self.B, self.B, self.B, self.T, self.T])
        self.assertEqual(verdict, 'played')

    def test_the_card_that_just_changes(self):
        # the report on 0.2.7 with macOS 15: no frame between the cards
        verdict, why = vec.judge_effect([self.F, self.F, self.T, self.T, self.T])
        self.assertEqual(verdict, 'not played')
        self.assertIn('just changed', why)

    def test_frames_drawn_by_turns_with_and_without_the_effect(self):
        verdict, why = vec.judge_effect([self.F, self.B, self.T, self.B, self.T])
        self.assertEqual(verdict, 'not played')
        self.assertIn('again', why)

    def test_an_effect_that_never_ends(self):
        verdict, _ = vec.judge_effect([self.F, self.B, self.B])
        self.assertEqual(verdict, 'not played')

    def test_a_window_not_seen(self):
        self.assertEqual(vec.judge_effect([])[0], 'unseen')
        self.assertEqual(vec.judge_effect([vec.UNKNOWN, vec.UNKNOWN])[0], 'unseen')
        self.assertEqual(vec.judge_effect([self.T, self.T])[0], 'unseen')


class Marks(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.mkdtemp()

    def tearDown(self):
        shutil.rmtree(self.tmp)

    def test_a_line_cut_short_is_left_out(self):
        path = os.path.join(self.tmp, 'marks.txt')
        with open(path, 'w') as f:
            f.write('RECT\t160,160,560,460\nSTART\tdissolve\tbla')
        self.assertEqual(vec.read_marks(path), [['RECT', '160,160,560,460']])

    def test_rects(self):
        self.assertEqual(vec.parse_rect('160,160,560,460'), (160, 160, 560, 460))
        self.assertIsNone(vec.parse_rect('1,2,3'))
        self.assertIsNone(vec.parse_rect('5,5,5,9'))
        self.assertEqual(vec.capture_rect((160, 160, 560, 460)), (176, 176, 368, 268))


class AppEngine(unittest.TestCase):
    def test_the_engine_of_an_app(self):
        tmp = tempfile.mkdtemp()
        try:
            folder = os.path.join(tmp, 'A.app', 'Contents', 'MacOS')
            os.makedirs(folder)
            app = os.path.join(tmp, 'A.app')
            self.assertEqual(vec.app_engine(app), os.path.join(folder, 'OXT-Beyond'))
            open(os.path.join(folder, 'Other'), 'w').close()
            self.assertEqual(vec.app_engine(app), os.path.join(folder, 'Other'))
            open(os.path.join(folder, 'OXT-Beyond'), 'w').close()
            self.assertEqual(vec.app_engine(app), os.path.join(folder, 'OXT-Beyond'))
        finally:
            shutil.rmtree(tmp)


# A stand-in engine: what visual-effect-check.livecodescript writes, an
# effect at a time; the made-up pictures follow its START and END lines.
ENGINE = '''#!/bin/sh
m="$OXT_VE_OUT/marks.txt"
printf 'INFO\\tversion\\tmade up\\n' > "$m"
printf 'RECT\\t160,160,560,460\\n' >> "$m"
colour=black
next=white
IFS='|'
for e in $OXT_VE_EFFECTS; do
  printf 'START\\t%s\\t%s\\t%s\\n' "$e" "$colour" "$next" >> "$m"
  sleep 0.5
  : > "$OXT_VE_OUT/playing"
  sleep 1
  rm -f "$OXT_VE_OUT/playing"
  printf 'END\\t%s\\t1000\\n' "$e" >> "$m"
  : > "$OXT_VE_OUT/over"
  sleep 1.5
  rm -f "$OXT_VE_OUT/over"
  t=$colour; colour=$next; next=$t
done
printf 'DONE\\n' >> "$m"
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

    def capture(self, playing):
        """A made-up screencapture: the card shown, from the stand-in's
        state; playing(seconds into the effect) gives a picture's rows
        while an effect plays. The cards alternate black and white."""
        state = {'effect': None, 'since': 0, 'count': 0}
        marks_dir = os.path.join(self.out, 'marks')

        def capture(area, path):
            marks = READ_MARKS(os.path.join(marks_dir, 'marks.txt'))
            starts = [m for m in marks if m[0] == 'START']
            source = BLACK if starts[-1][2] == 'black' else WHITE
            target = WHITE if source == BLACK else BLACK
            if os.path.isfile(os.path.join(marks_dir, 'playing')):
                if state['effect'] != len(starts):
                    state['effect'], state['since'] = len(starts), time.time()
                rows = playing(time.time() - state['since'], source, target)
            elif len(marks) and marks[-1][0] in ('END', 'DONE'):
                rows = picture('to', target=target)
            else:
                rows = picture('from', source=source)
            with open(path, 'wb') as f:
                f.write(png(rows))
            time.sleep(0.1)
            return True
        return capture

    def run_check(self, playing, report_only=False):
        args = vec.argparse.Namespace(
            app=None, engine=self.engine, out=self.out, effects='dissolve|wipe right',
            rate=4000, timeout=60, report_only=report_only)
        with contextlib.redirect_stdout(io.StringIO()) as said:
            code = vec.run(args, capture=self.capture(playing))
        return code, said.getvalue()

    def test_effects_that_play(self):
        def playing(t, source, target):
            return picture('dissolve', progress=min(1.0, t), source=source, target=target)
        code, said = self.run_check(playing)
        self.assertEqual(code, 0, said)
        self.assertIn('Every effect played.', said)
        self.assertEqual(len(re.findall(r'IMAGE out/(dissolve|wipe-right)\.png 1/', said)), 2, said)

    def test_cards_that_just_change(self):
        # 0.2.7 on macOS 15: every frame drawn as the card already was
        def playing(t, source, target):
            return picture('to', target=target)
        code, said = self.run_check(playing)
        self.assertEqual(code, 1, said)
        self.assertIn('::error::visual effects that did not play: dissolve, wipe right', said)

    def test_a_read_while_the_script_writes_marks_again(self):
        # visual-effect-check.livecodescript writes the whole of marks.txt
        # each time (put sMarks into url), so a read can find the file
        # emptied or half written, with fewer lines than the reads before.
        # Those lines were seen already: on 19 November (#577's Mac arm64
        # test) a read of an emptied file made the check take dissolve and
        # wipe right a second time, with no pictures, and fail them.
        def playing(t, source, target):
            return picture('dissolve', progress=min(1.0, t), source=source, target=target)
        for kept in (0, 2, 3):
            with self.subTest(lines_found=kept):
                cut = {'done': False}

                def read_marks(path):
                    marks = READ_MARKS(path)
                    if not cut['done'] and any(m[0] == 'END' for m in marks):
                        cut['done'] = True
                        return marks[:kept]
                    return marks
                vec.read_marks = read_marks
                try:
                    code, said = self.run_check(playing)
                finally:
                    vec.read_marks = READ_MARKS
                self.assertTrue(cut['done'])
                self.assertEqual(code, 0, said)
                self.assertIn('Every effect played.', said)
                self.assertEqual(len(re.findall(r'START dissolve', said)), 1, said)
                self.assertEqual(len(re.findall(r'START wipe right', said)), 1, said)
                self.assertNotIn('unseen', said)

    def test_report_only(self):
        def playing(t, source, target):
            return picture('to', target=target)
        code, said = self.run_check(playing, report_only=True)
        self.assertEqual(code, 0, said)
        self.assertIn('::warning::visual effects that did not play', said)


class EngineFix(unittest.TestCase):
    """The fix itself: view_platform_updatewindowwithcallback waits for the
    draw it asked for (MCPlatformFlushWindowPendingDraws) before it clears
    the callback that renders the effect's frame."""

    def test_the_draw_is_waited_for_before_the_callback_is_cleared(self):
        with open(os.path.join(ROOT, 'engine', 'src', 'desktop-stack.cpp'), encoding='utf-8') as f:
            text = f.read()
        m = re.search(r'void MCStack::view_platform_updatewindowwithcallback\(.*?\n\}', text, re.S)
        self.assertIsNotNone(m)
        body = re.sub(r'//[^\n]*', '', m.group(0))
        update = body.index('view_platform_updatewindow(p_region);')
        flush = body.index('MCPlatformFlushWindowPendingDraws(window);')
        cleared = body.index('s_update_callback = nil;')
        self.assertLess(update, flush)
        self.assertLess(flush, cleared)

    def test_the_wait_is_a_no_op_without_a_pending_draw(self):
        # before macOS 11 DoUpdate draws at once and leaves nothing
        # pending: the flush returns without waiting, as it did before
        with open(os.path.join(ROOT, 'engine', 'src', 'mac-window.mm'), encoding='utf-8') as f:
            text = f.read()
        m = re.search(r'void MCMacPlatformWindow::FlushPendingDraws\(void\)\n\{.*?\n\}', text, re.S)
        self.assertIsNotNone(m)
        self.assertIn('if (MCmajorosversion < MCOSVersionMake(10,16,0))\n\t\treturn;', m.group(0))
        self.assertIn('if (!m_has_pending_draw || !m_waiting_for_draw)\n\t\treturn;', m.group(0))


if __name__ == '__main__':
    unittest.main()
