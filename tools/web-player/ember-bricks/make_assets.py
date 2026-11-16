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

"""Make Ember Bricks' sounds.

  python3 tools/web-player/ember-bricks/make_assets.py [--check]

Every sound of the game is made here, from sine, square and triangle waves
and noise: nothing is recorded and nothing comes from anyone else, so the
sounds are OXT-Beyond's own. They are written to sounds/ beside this
script as WAV files, mono 22050 Hz 16-bit (what a browser's Web Audio, the
desktop engines' play and Android's sound channels all take), and the same
sound is made every time: the noise comes from a generator with a fixed
seed.

--check writes nothing, and fails if a file in sounds/ is not what this
script makes now (or is missing, or is one it does not make).

The font, Atkinson Hyperlegible (fonts/), is not made here: its two files
are Puzzle Almanac's, byte for byte (Google Fonts' copy, with the
Macintosh name records that ../puzzle-almanac/make_assets.py adds for the
web engine's font loader). SOURCES.md says where each file is from.

Python 3.8 or later, standard library only.
"""

import argparse
import io
import math
import os
import random
import struct
import sys
import wave

HERE = os.path.dirname(os.path.abspath(__file__))
SOUNDS = os.path.join(HERE, 'sounds')
RATE = 22050


# ------------------------------------------------------------------ waves

def sine(phase):
    return math.sin(2 * math.pi * phase)


def square(phase):
    # (softened: the first three odd harmonics, which rings less harshly
    # than a true square through a phone's speaker)
    p = 2 * math.pi * phase
    return (math.sin(p) + math.sin(3 * p) / 3 + math.sin(5 * p) / 5) * 0.85


def triangle(phase):
    p = phase % 1.0
    return 4 * abs(p - 0.5) - 1


WAVES = {'sine': sine, 'square': square, 'triangle': triangle}


def tone(seconds, start_hz, end_hz=None, shape='sine', attack=0.004, decay=None, volume=1.0, curve=1.0):
    """A tone that slides from start_hz to end_hz and dies away.

    decay is the time its loudness takes to fall to about a third (by
    default a third of its length); curve bends the slide (above 1, most
    of it comes at the end).
    """
    if end_hz is None:
        end_hz = start_hz
    if decay is None:
        decay = seconds / 3.0
    wave_of = WAVES[shape]
    count = int(seconds * RATE)
    out = []
    phase = 0.0
    for i in range(count):
        t = i / RATE
        along = (i / max(1, count - 1)) ** curve
        hz = start_hz + (end_hz - start_hz) * along
        phase += hz / RATE
        loud = min(1.0, t / attack) * math.exp(-t / decay)
        out.append(wave_of(phase) * loud * volume)
    return out


def noise(seconds, rng, attack=0.002, decay=None, volume=1.0, smooth=0.0):
    """Noise that dies away; smooth (0 to 1) takes its hiss off."""
    if decay is None:
        decay = seconds / 3.0
    count = int(seconds * RATE)
    out = []
    last = 0.0
    for i in range(count):
        t = i / RATE
        last = last * smooth + (rng.random() * 2 - 1) * (1 - smooth)
        out.append(last * min(1.0, t / attack) * math.exp(-t / decay) * volume)
    return out


def silence(seconds):
    return [0.0] * int(seconds * RATE)


def mix(*parts):
    """Sounds played together."""
    out = [0.0] * max(len(p) for p in parts)
    for part in parts:
        for i, v in enumerate(part):
            out[i] += v
    return out


def seq(*parts):
    """Sounds played one after the other."""
    out = []
    for part in parts:
        out.extend(part)
    return out


def at(seconds, part):
    """A sound that starts later."""
    return silence(seconds) + part


def finish(samples, peak=0.82):
    """As loud as peak at its loudest, and faded out over its last 6 ms, so
    that it ends without a click."""
    top = max(1e-9, max(abs(v) for v in samples))
    fade = int(0.006 * RATE)
    count = len(samples)
    out = []
    for i, v in enumerate(samples):
        v = v / top * peak
        if count - i <= fade:
            v *= (count - i) / fade
        out.append(v)
    return out


def note(name):
    """The frequency of a note: 'C5', 'F#4', 'Bb3'."""
    steps = {'C': -9, 'D': -7, 'E': -5, 'F': -4, 'G': -2, 'A': 0, 'B': 2}
    step = steps[name[0]]
    rest = name[1:]
    if rest[0] == '#':
        step += 1
        rest = rest[1:]
    elif rest[0] == 'b':
        step -= 1
        rest = rest[1:]
    return 440.0 * 2 ** ((step + 12 * (int(rest) - 4)) / 12.0)


def arp(names, each, shape='square', decay=None, volume=1.0, last=None):
    """Notes one after the other, each `each` seconds (the last one `last`)."""
    parts = []
    for i, name in enumerate(names):
        length = each
        if last is not None and i == len(names) - 1:
            length = last
        parts.append(tone(length, note(name), shape=shape, decay=decay if decay else length / 2.5, volume=volume))
    return seq(*parts)


# ----------------------------------------------------------------- sounds

def make_all():
    """{name: samples}: every sound of the game."""
    rng = random.Random(20261116)
    s = {}

    # the ball: off the paddle, off a wall, and into a brick, a note higher
    # for each step of the heat (brick-1 is cold, brick-5 white hot)
    s['paddle'] = mix(tone(0.09, 210, 150, 'sine', decay=0.03),
                      tone(0.05, 420, 300, 'triangle', decay=0.015, volume=0.4))
    s['wall'] = tone(0.045, 330, 300, 'triangle', decay=0.012, volume=0.8)
    for i, name in enumerate(['E5', 'G5', 'A5', 'C6', 'E6']):
        s['brick-%d' % (i + 1)] = mix(tone(0.085, note(name), shape='square', decay=0.028),
                                      tone(0.05, note(name) * 2, shape='sine', decay=0.015, volume=0.35))
    # a brick that takes more than one hit, and steel, which takes them all
    s['tough'] = mix(tone(0.13, 1180, shape='sine', decay=0.04),
                     tone(0.13, 1777, shape='sine', decay=0.03, volume=0.6),
                     noise(0.03, rng, decay=0.008, volume=0.3))
    s['steel'] = mix(tone(0.11, 760, 720, 'triangle', decay=0.03),
                     tone(0.08, 2280, shape='sine', decay=0.012, volume=0.25))
    s['bomb'] = mix(noise(0.55, rng, decay=0.14, smooth=0.86),
                    tone(0.5, 130, 38, 'sine', decay=0.16, volume=1.1),
                    noise(0.08, rng, decay=0.02, volume=0.5))

    # what falls: a spark caught, a hazard caught, a life
    s['power'] = arp(['C5', 'E5', 'G5', 'C6'], 0.055, 'square', last=0.16)
    s['hazard'] = seq(tone(0.11, note('Eb4'), shape='square', decay=0.05),
                      tone(0.2, note('A3'), note('G3'), 'square', decay=0.08))
    s['life'] = arp(['G5', 'C6', 'E6', 'G6', 'C7'], 0.07, 'triangle', last=0.3)
    s['shield'] = tone(0.2, 300, 620, 'sine', decay=0.08, curve=0.5)
    s['laser'] = mix(tone(0.1, 1500, 420, 'square', decay=0.035, curve=0.6, volume=0.8),
                     noise(0.02, rng, decay=0.006, volume=0.25))
    s['blaze'] = mix(tone(0.4, 220, 880, 'triangle', decay=0.2, curve=0.6),
                     noise(0.4, rng, attack=0.15, decay=0.2, volume=0.25, smooth=0.5))

    # the run: a ball away, a ball lost, a level cleared, the end
    s['launch'] = tone(0.12, 240, 560, 'triangle', decay=0.06, curve=0.7)
    s['lost'] = mix(tone(0.5, 420, 90, 'square', decay=0.2, curve=0.8),
                    noise(0.12, rng, decay=0.04, volume=0.2, smooth=0.6))
    s['clear'] = seq(arp(['C5', 'E5', 'G5', 'C6', 'E6'], 0.085, 'square'),
                     mix(tone(0.55, note('C6'), shape='square', decay=0.25),
                         tone(0.55, note('E6'), shape='triangle', decay=0.25, volume=0.7),
                         tone(0.55, note('G6'), shape='sine', decay=0.25, volume=0.6)))
    s['over'] = seq(tone(0.2, note('G4'), shape='square', decay=0.1),
                    tone(0.2, note('Eb4'), shape='square', decay=0.1),
                    tone(0.2, note('C4'), shape='square', decay=0.1),
                    tone(0.6, note('G3'), note('F#3'), 'square', decay=0.3))
    s['best'] = seq(arp(['C5', 'G5', 'C6', 'G5', 'C6', 'E6'], 0.075, 'triangle'),
                    mix(tone(0.5, note('G6'), shape='triangle', decay=0.25),
                        tone(0.5, note('C6'), shape='sine', decay=0.25, volume=0.6)))
    s['heat'] = mix(tone(0.3, 660, 1320, 'sine', decay=0.14, curve=0.5),
                    tone(0.3, 990, 1980, 'sine', decay=0.1, volume=0.4, curve=0.5))

    # the screens and the duel
    s['click'] = mix(tone(0.035, 900, 700, 'triangle', decay=0.01),
                     noise(0.01, rng, decay=0.003, volume=0.2))
    s['tick'] = tone(0.09, note('A5'), shape='square', decay=0.03)
    s['go'] = mix(tone(0.32, note('A6'), shape='square', decay=0.14),
                  tone(0.32, note('E6'), shape='triangle', decay=0.14, volume=0.6))
    s['attack'] = seq(tone(0.09, note('D5'), shape='square', decay=0.05),
                      tone(0.09, note('Ab4'), shape='square', decay=0.05),
                      tone(0.09, note('D5'), shape='square', decay=0.05),
                      tone(0.16, note('Ab4'), shape='square', decay=0.08))
    s['join'] = arp(['E5', 'A5', 'E6'], 0.08, 'triangle', last=0.2)

    return {name: finish(samples) for name, samples in s.items()}


def wav_bytes(samples):
    buf = io.BytesIO()
    with wave.open(buf, 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b''.join(struct.pack('<h', max(-32767, min(32767, int(round(v * 32767))))) for v in samples))
    return buf.getvalue()


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('--check', action='store_true', help='write nothing; fail if sounds/ is not what is made now')
    args = ap.parse_args()

    made = {name + '.wav': wav_bytes(samples) for name, samples in make_all().items()}
    if args.check:
        wrong = []
        have = sorted(f for f in os.listdir(SOUNDS) if f.endswith('.wav')) if os.path.isdir(SOUNDS) else []
        for name in sorted(made):
            path = os.path.join(SOUNDS, name)
            if not os.path.isfile(path):
                wrong.append('%s is missing' % name)
            else:
                with open(path, 'rb') as f:
                    if f.read() != made[name]:
                        wrong.append('%s is not what make_assets.py makes' % name)
        for name in have:
            if name not in made:
                wrong.append('%s is not made by make_assets.py' % name)
        if wrong:
            print('\n'.join(wrong))
            return 1
        print('%d sounds, as made' % len(made))
        return 0

    os.makedirs(SOUNDS, exist_ok=True)
    total = 0
    for name in sorted(made):
        with open(os.path.join(SOUNDS, name), 'wb') as f:
            f.write(made[name])
        total += len(made[name])
    print('%d sounds, %d bytes' % (len(made), total))
    return 0


if __name__ == '__main__':
    sys.exit(main())
