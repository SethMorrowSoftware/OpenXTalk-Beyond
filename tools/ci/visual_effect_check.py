#!/usr/bin/env python3
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

"""Visual effects as the screen shows them, on macOS: the forum's report
on 0.2.7 with macOS 15 (2026-11-19) that visual effect transitions did not
play, the card just changed. On macOS 11 and later the engine asked AppKit
for each frame's draw and cleared the callback that draws the frame before
the draw came, so every frame was drawn as the card already was
(engine/src/desktop-stack.cpp, view_platform_updatewindowwithcallback).

  python3 tools/ci/visual_effect_check.py --app OXT-Beyond.app --out DIR
      [--effects "dissolve|wipe right"] [--rate 4000] [--report-only]

Runs tools/ci/visual-effect-check.livecodescript as the development
engine's home stack (copied to <out>/tools/Startup.rev, REV_TOOLS_PATH
pointing there). It opens a window whose cards are black and white in
turn and plays one effect after another between them, each very slowly
(the effectRate, --rate, 4 s by default), writing where the window is and
when each effect starts and ends. Meanwhile the area of the window is
taken from the screen over and over (screencapture -R), and each picture
is judged by its pixels: the card the effect comes from (FROM), the card
it goes to (TO), or neither (BETWEEN: a dissolve's grey, a wipe's two
halves). An effect plays when, from its start to just after its end:

  - the first picture is FROM (else the window was not seen: the check
    cannot judge it),
  - at least one picture is BETWEEN,
  - no BETWEEN comes after a TO (the end card shown, then the effect's
    frames again: the flicker of frames drawn by turns with and without
    the effect),
  - the last picture is TO.

Each effect's pictures are printed in a line (F, B, T and the seconds
since its start) and one from its middle into the log as
tools/ci/print_images.py reads it. Exit status 0 when every effect
played, 1 when one did not, 2 when the check itself could not run (the
engine did not start the effects, the window was never seen). With
--report-only, a fault found is reported and the exit status is 0 (a
release's run, whose fault is known). Only the Python 3 standard library
is used.
"""

import argparse
import base64
import os
import shutil
import struct
import subprocess
import sys
import time
import zlib

HERE = os.path.dirname(os.path.abspath(__file__))
SCRIPT = os.path.join(HERE, 'visual-effect-check.livecodescript')

# How far in from the window's edges the pictures are taken, in points
INSET = 16
# After an effect's END line, how long its pictures go on (the script
# waits 1.5 s there before the next START)
AFTER_END = 1.0
# The share of a picture's pixels that must be of a card's colour for the
# picture to be that card
WHOLE = 0.97

FROM, TO, BETWEEN, UNKNOWN = 'F', 'T', 'B', '?'


def log(text=''):
    print(text)
    sys.stdout.flush()


# ---------------------------------------------------------------- pictures

def read_png(data):
    """(width, height, rows) of a PNG file's bytes, each row a list of
    (r, g, b) tuples. Only what screencapture writes: 8 or 16 bits per
    sample, grey, RGB, grey with alpha or RGBA, not interlaced."""
    if data[:8] != b'\x89PNG\r\n\x1a\n':
        raise ValueError('not a PNG file')
    pos = 8
    width = height = depth = colour = None
    idat = []
    while pos < len(data):
        length, kind = struct.unpack('>I4s', data[pos:pos + 8])
        body = data[pos + 8:pos + 8 + length]
        pos += 12 + length
        if kind == b'IHDR':
            width, height, depth, colour, _, _, interlace = struct.unpack('>IIBBBBB', body)
            if interlace:
                raise ValueError('an interlaced PNG file')
        elif kind == b'IDAT':
            idat.append(body)
        elif kind == b'IEND':
            break
    channels = {0: 1, 2: 3, 4: 2, 6: 4}.get(colour)
    if channels is None or depth not in (8, 16):
        raise ValueError('a PNG file of colour type %s, %s bits' % (colour, depth))
    size = depth // 8
    bpp = channels * size
    stride = width * bpp
    raw = zlib.decompress(b''.join(idat))
    rows = []
    prev = bytearray(stride)
    for y in range(height):
        start = y * (stride + 1)
        kind = raw[start]
        line = bytearray(raw[start + 1:start + 1 + stride])
        undo_filter(kind, line, prev, bpp)
        pixels = []
        for x in range(width):
            p = x * bpp
            samples = [line[p + i * size] for i in range(channels)]
            if channels in (1, 2):
                pixels.append((samples[0],) * 3)
            else:
                pixels.append(tuple(samples[:3]))
        rows.append(pixels)
        prev = line
    return width, height, rows


def undo_filter(kind, line, prev, bpp):
    """Reverses a PNG row's filter in place."""
    for i in range(len(line)):
        a = line[i - bpp] if i >= bpp else 0
        b = prev[i]
        c = prev[i - bpp] if i >= bpp else 0
        if kind == 1:
            line[i] = (line[i] + a) & 0xff
        elif kind == 2:
            line[i] = (line[i] + b) & 0xff
        elif kind == 3:
            line[i] = (line[i] + (a + b) // 2) & 0xff
        elif kind == 4:
            p = a + b - c
            pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
            line[i] = (line[i] + (a if pa <= pb and pa <= pc else b if pb <= pc else c)) & 0xff
        elif kind != 0:
            raise ValueError('a PNG row filter %d' % kind)


def colour_of(pixel):
    """'black', 'white' or None for a pixel between the two."""
    r, g, b = pixel
    level = (r * 299 + g * 587 + b * 114) // 1000
    if level < 48:
        return 'black'
    if level > 207:
        return 'white'
    return None


def judge_picture(width, height, rows, source, target, grid=16):
    """FROM when nearly all of a grid of the picture's pixels are the
    colour of the card the effect comes from, TO when they are the colour
    of the one it goes to, otherwise BETWEEN."""
    if width < 1 or height < 1:
        return UNKNOWN
    counts = {}
    total = 0
    for gy in range(grid):
        y = min(height - 1, (2 * gy + 1) * height // (2 * grid))
        for gx in range(grid):
            x = min(width - 1, (2 * gx + 1) * width // (2 * grid))
            c = colour_of(rows[y][x])
            counts[c] = counts.get(c, 0) + 1
            total += 1
    if counts.get(source, 0) >= WHOLE * total:
        return FROM
    if counts.get(target, 0) >= WHOLE * total:
        return TO
    return BETWEEN


def judge_effect(states):
    """Whether an effect played, from its pictures' states in the order
    taken: (verdict, why), the verdict 'played', 'not played' or 'unseen'."""
    states = [s for s in states if s != UNKNOWN]
    if not states:
        return 'unseen', 'no picture was taken'
    if states[0] != FROM:
        return 'unseen', 'the first picture is not the card the effect starts from'
    if BETWEEN not in states:
        return 'not played', 'no picture between the two cards: the card just changed'
    first_to = states.index(TO) if TO in states else len(states)
    if BETWEEN in states[first_to:]:
        return 'not played', 'the end card was shown, then frames of the effect again'
    if states[-1] != TO:
        return 'not played', 'the last picture is not the card the effect goes to'
    return 'played', '%d of %d pictures between the two cards' % (states.count(BETWEEN), len(states))


# ------------------------------------------------------------------ marks

def read_marks(path):
    """The lines of marks.txt as lists of fields (a line cut short, read
    while the script writes the file, is left out)."""
    try:
        with open(path, encoding='utf-8', errors='replace') as f:
            text = f.read()
    except OSError:
        return []
    if not text.endswith('\n'):
        text = text[:text.rfind('\n') + 1]
    return [line.split('\t') for line in text.splitlines() if line]


def parse_rect(text):
    """(left, top, right, bottom) from "l,t,r,b", or None."""
    try:
        left, top, right, bottom = [int(float(v)) for v in text.split(',')]
    except ValueError:
        return None
    if right <= left or bottom <= top:
        return None
    return left, top, right, bottom


def capture_rect(rect):
    """The area of the screen to take: the window's, INSET in."""
    left, top, right, bottom = rect
    inset = min(INSET, (right - left) // 4, (bottom - top) // 4)
    return left + inset, top + inset, right - left - 2 * inset, bottom - top - 2 * inset


def screencapture(area, path):
    """Takes the area (x, y, width, height, in points) of the screen into
    a PNG file; whether it was written."""
    x, y, w, h = area
    try:
        subprocess.run(['screencapture', '-x', '-t', 'png', '-R', '%d,%d,%d,%d' % (x, y, w, h), path],
                       stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=20)
    except subprocess.TimeoutExpired:
        return False
    return os.path.isfile(path)


def print_image(name, path):
    """Prints a PNG file into the log as tools/ci/print_images.py reads it."""
    with open(path, 'rb') as f:
        data = base64.b64encode(f.read()).decode('ascii')
    parts = [data[i:i + 4000] for i in range(0, len(data), 4000)] or ['']
    for i, part in enumerate(parts):
        print('IMAGE %s %d/%d %s' % (name, i + 1, len(parts), part))


# -------------------------------------------------------------------- run

def app_engine(app):
    """The engine of an app: Contents/MacOS/OXT-Beyond, or the one file
    in Contents/MacOS when an older release names it otherwise."""
    folder = os.path.join(app, 'Contents', 'MacOS')
    engine = os.path.join(folder, 'OXT-Beyond')
    if os.path.isfile(engine) or not os.path.isdir(folder):
        return engine
    names = sorted(n for n in os.listdir(folder) if os.path.isfile(os.path.join(folder, n)))
    return os.path.join(folder, names[0]) if len(names) == 1 else engine


class Effect(object):
    def __init__(self, name, source, target, started):
        self.name = name
        self.source = source
        self.target = target
        self.started = started
        self.ended = None
        self.took = None
        # (seconds since started, state, picture path)
        self.pictures = []


def run(args, capture=screencapture):
    out = os.path.abspath(args.out)
    if os.path.isdir(out):
        shutil.rmtree(out)
    tools = os.path.join(out, 'tools')
    marks_dir = os.path.join(out, 'marks')
    shots = os.path.join(out, 'shots')
    for folder in (tools, marks_dir, shots):
        os.makedirs(folder)
    shutil.copyfile(SCRIPT, os.path.join(tools, 'Startup.rev'))
    marks_path = os.path.join(marks_dir, 'marks.txt')

    env = dict(os.environ)
    env['REV_TOOLS_PATH'] = tools
    env['OXT_VE_OUT'] = marks_dir
    env['OXT_VE_RATE'] = str(args.rate)
    if args.effects:
        env['OXT_VE_EFFECTS'] = args.effects

    engine = args.engine or app_engine(args.app)
    effects = []
    seen = 0
    area = None
    done = False
    status = 'did not finish in %d s' % args.timeout
    count = 0
    started = time.time()
    with open(os.path.join(out, 'engine-output.txt'), 'wb') as output:
        proc = subprocess.Popen([engine], cwd=tools, env=env, stdout=output, stderr=subprocess.STDOUT)
        try:
            while time.time() - started < args.timeout:
                now = time.time()
                marks = read_marks(marks_path)
                for fields in marks[seen:]:
                    kind = fields[0]
                    if kind == 'RECT' and len(fields) > 1:
                        rect = parse_rect(fields[1])
                        if rect:
                            area = capture_rect(rect)
                            log('The window: %s (pictures of %s)' % (fields[1], ','.join(map(str, area))))
                    elif kind == 'START' and len(fields) >= 4:
                        effects.append(Effect(fields[1], fields[2], fields[3], now))
                        log('%6.1f s  START %s (%s to %s)' % (now - started, fields[1], fields[2], fields[3]))
                    elif kind == 'END' and len(fields) >= 2 and effects:
                        effects[-1].ended = now
                        effects[-1].took = fields[2] if len(fields) > 2 else '?'
                        log('%6.1f s  END %s (%s ms in the engine)' % (now - started, fields[1], effects[-1].took))
                    elif kind == 'DONE':
                        done = True
                    else:
                        log('%6.1f s  %s' % (now - started, ' '.join(fields)))
                # The script writes the whole of marks.txt each time (put
                # sMarks into url), so a read can find it emptied or half
                # written, with fewer lines than a read before: those were
                # seen already, and seen never goes back. (It once did, and
                # the check took two effects a second time, unseen.)
                seen = max(seen, len(marks))
                current = effects[-1] if effects else None
                if current is not None and current.ended is not None and now - current.ended > AFTER_END:
                    current = None
                if done and current is None:
                    status = 'reported done after %.0f s' % (now - started)
                    break
                if proc.poll() is not None and current is None:
                    status = 'ended with exit status %d after %.0f s' % (proc.returncode, now - started)
                    break
                if current is not None and area is not None:
                    count += 1
                    path = os.path.join(shots, '%03d.png' % count)
                    taken = time.time()
                    # judged after the run, so that the pictures come
                    # as often as screencapture can take them
                    current.pictures.append((taken - current.started, UNKNOWN,
                                             path if capture(area, path) else None))
                else:
                    time.sleep(0.1)
        finally:
            if proc.poll() is None:
                proc.kill()
                try:
                    proc.wait(timeout=30)
                except subprocess.TimeoutExpired:
                    log('The engine did not end when killed')

    log('Engine: %s' % status)
    log('--- marks.txt')
    for fields in read_marks(marks_path):
        log('\t'.join(fields))
    log('--- the engine\'s output (first 3000 bytes)')
    with open(os.path.join(out, 'engine-output.txt'), 'rb') as f:
        log(f.read(3000).decode('utf-8', 'replace'))
    return report(effects, done, out, args.report_only)


def judge_pictures(effect):
    """Judges each of the effect's pictures (UNKNOWN for one not taken or
    not read)."""
    judged = []
    for taken, _, path in effect.pictures:
        state = UNKNOWN
        if path:
            try:
                with open(path, 'rb') as f:
                    w, h, rows = read_png(f.read())
                state = judge_picture(w, h, rows, effect.source, effect.target)
            except (OSError, ValueError, zlib.error, struct.error) as e:
                log('(%s: %s)' % (os.path.basename(path), e))
        judged.append((taken, state, path))
    effect.pictures = judged


def report(effects, done, out, report_only=False):
    """Prints each effect's pictures and verdict: the exit status."""
    for effect in effects:
        judge_pictures(effect)
    log('--- the effects (F the card it comes from, B between the two, T the card it goes to,'
        ' with the seconds since its START line)')
    verdicts = []
    for effect in effects:
        verdict, why = judge_effect([s for _, s, _ in effect.pictures])
        verdicts.append(verdict)
        line = ' '.join('%s%.1f' % (s, t) for t, s, _ in effect.pictures)
        log('%-22s %-10s %s' % (effect.name, verdict, why))
        log('    %s' % (line or '(no pictures)'))
        middle = [p for _, s, p in effect.pictures if s == BETWEEN]
        if not middle and effect.pictures:
            middle = [effect.pictures[len(effect.pictures) // 2][2]]
        if middle and middle[len(middle) // 2] and os.path.isfile(middle[len(middle) // 2]):
            print_image('%s/%s.png' % (os.path.basename(out), effect.name.replace(' ', '-')),
                        middle[len(middle) // 2])
    sys.stdout.flush()
    if not effects:
        log('::error::the visual effect check started no effect')
        return 2
    if all(v == 'unseen' for v in verdicts):
        log('::error::the visual effect check never saw the window')
        return 2
    failed = [e.name for e, v in zip(effects, verdicts) if v != 'played']
    if not done:
        failed.append('(the script did not finish)')
    if failed:
        text = 'visual effects that did not play: %s' % ', '.join(failed)
        if report_only:
            log('::warning::%s' % text)
            return 0
        log('::error::%s' % text)
        return 1
    log('Every effect played.')
    return 0


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    ap.add_argument('--app', help='OXT-Beyond.app')
    ap.add_argument('--engine', help='the engine to run, instead of the app\'s')
    ap.add_argument('--out', required=True, help='a folder for the run (emptied first)')
    ap.add_argument('--effects', default='', help='the effects, separated by "|" (default: the script\'s)')
    ap.add_argument('--rate', type=int, default=4000, help='the effectRate, in milliseconds')
    ap.add_argument('--timeout', type=int, default=240, help='seconds for the whole run')
    ap.add_argument('--report-only', action='store_true',
                    help='report a fault found without failing (a release with a known fault)')
    args = ap.parse_args(argv)
    if not args.app and not args.engine:
        ap.error('--app or --engine is required')
    if sys.platform != 'darwin' and not args.engine:
        log('::error::the visual effect check takes the screen with screencapture, on macOS')
        return 2
    return run(args)


if __name__ == '__main__':
    sys.exit(main())
