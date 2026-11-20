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

"""Beyond Beats in a browser: its audio core, and the stack playing in the
Stack Player.

  python3 tools/ci/beyond_beats_check.py [--player DIR] [--shots DIR]

The engine tests (tests/lcs/webplayer/beyond-beats.livecodescript) check
the song, the screen and the file on a desktop engine, which has no Web
Audio. This checks the rest, in headless Chromium:

The audio core (tools/web-player/beyond-beats/audio-core.js), alone in a
blank page, with the song rendered offline and measured sample by sample:

  1. run as the stack runs it, it answers "ok", and run again it keeps the
     core it made
  2. the kit: the sixteen sounds the stack names, each made the same way
     every time, its loudest sample at 0.9, ending in silence
  3. timing: each hit starts on its step to the sample, at the tempo; and
     swing moves every second sixteenth, and only those, later by its share
     of half a step
  4. the mixer: a muted channel is silent, a solo silences the others, a
     volume of 50 is a quarter of the power of 100, a pan hard left leaves
     the right side silent (and the other way), and a soft step is softer
     by its velocity
  5. the limiter: twelve kicks at once at full volume never pass 0.99
  6. a song made safe: a tempo out of range, letters in a row, a short row
     or a missing one
  7. live: started, the steps it books follow one another a step apart on
     the audio clock, the step it says is sounding moves, and stopped it
     says -1

The stack in a Stack Player (with --player, a built player's folder; or
from build_player.py --check, check_player): it opens without a script
error, Play starts the page's core at the stack's tempo with its song
(ten channels, four patterns, twelve blocks in the playlist), a click on
a pad is in the page's pattern at once, the playlist, piano roll and
mixer show while it plays, Song mode plays the whole playlist, and Stop
stops it.

It prints "BEYOND BEATS CHECK OK" or the checks that failed.
"""

import argparse
import functools
import http.server
import os
import shutil
import sys
import tempfile
import threading
import time

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
CORE = os.path.join(REPO, 'tools', 'web-player', 'beyond-beats', 'audio-core.js')
STACK = os.path.join(REPO, 'tools', 'web-player', 'stacks', 'Beyond Beats.oxtstack')
TITLE = 'Beyond Beats'

# the stack's Play button and pads, in its card's points (btLayout)
PLAY = (224, 30)
MODE_SONG = (362, 30)
CHORDS = (100, 181)
PIANO_PREV = (216, 113)
TABS = {'rack': (246, 86), 'piano': (338, 86), 'song': (426, 86), 'mixer': (503, 86)}
GRID_LEFT, GRID_WIDTH, ROW_TOP, ROW_H, PAD_H = 500, 444, 122, 34, 28


def log(msg=''):
    print(msg, flush=True)


def core_source():
    with open(CORE, encoding='utf-8') as f:
        return f.read()


def pad_point(row, step, steps=16):
    """The middle of a pad (row and step from 1), in the card's points"""
    left = GRID_LEFT + round((step - 1) * GRID_WIDTH / steps)
    right = GRID_LEFT + round(step * GRID_WIDTH / steps) - 3
    top = ROW_TOP + (row - 1) * ROW_H
    return (left + right) / 2, top + PAD_H / 2


# Measures made in the page: the core's render, sample by sample.
MEASURE = r"""
async (src) => {
  const first = eval(src), again = eval(src);
  const B = window.beyondBeats, out = {first: first, again: again, same: window.beyondBeats === B};
  const rate = 44100;
  const ch = (sound, vol, pan, mute, solo) => [sound, vol === undefined ? 100 : vol, pan || 0, mute || 0, solo || 0];
  const empty = '0000000000000000';
  const rms = (a, from, to) => { let s = 0; for (let i = from; i < to; i++) s += a[i] * a[i]; return Math.sqrt(s / Math.max(1, to - from)); };
  const peak = (a) => { let p = 0; for (let i = 0; i < a.length; i++) p = Math.max(p, Math.abs(a[i])); return p; };
  // the first sample of each hit: louder than 0.01 after 50 ms of quiet
  const onsets = (a) => { const o = []; let quiet = 1e9; for (let i = 0; i < a.length; i++) {
      if (Math.abs(a[i]) > 0.01) { if (quiet > 0.05 * rate) o.push(i); quiet = 0; } else quiet++; } return o; };
  // the last sample louder than 0.001
  const lastLoud = (a) => { for (let i = a.length - 1; i >= 0; i--) if (Math.abs(a[i]) > 0.001) return i; return -1; };
  // the frequency of a sine, from its rising zero crossings (each placed
  // between its two samples) from `from` to `to`
  const crossings = (a, from, to) => { const t = []; from = Math.round(from); to = Math.round(to);
      for (let i = from; i < to; i++) if (a[i] <= 0 && a[i + 1] > 0) t.push(i + a[i] / (a[i] - a[i + 1]));
      return t.length < 3 ? 0 : (t.length - 1) * rate / (t[t.length - 1] - t[0]); };
  // the pitch of a note with harmonics: the shortest lag at which 4096
  // samples from `from` match themselves best (normalised), refined
  // between its neighbours
  const pitch = (a, from) => { from = Math.round(from); const N = 4096, c = [];
      for (let lag = 0; lag < 1400; lag++) { let s = 0, e1 = 0, e2 = 0;
        for (let i = from; i < from + N; i++) { s += a[i] * a[i + lag]; e1 += a[i] * a[i]; e2 += a[i + lag] * a[i + lag]; }
        c.push(s / Math.sqrt(e1 * e2 + 1e-30)); }
      let k = 1; while (k < c.length && c[k] > 0) k++;
      let best = 0; for (let i = k; i < c.length; i++) best = Math.max(best, c[i]);
      for (let i = k + 1; i < c.length - 1; i++) if (c[i] >= 0.9 * best && c[i] >= c[i - 1] && c[i] >= c[i + 1]) {
        const d = (c[i - 1] - c[i + 1]) / (2 * (c[i - 1] - 2 * c[i] + c[i + 1]));
        return rate / (i + d); }
      return 0; };

  // the kit
  out.kit = B.kit.slice();
  out.sounds = B.kit.map((name, i) => {
    const a = B.makeSound(i, rate), b = B.makeSound(i, rate);
    let same = a.length === b.length, finite = true;
    for (let k = 0; k < a.length; k++) { if (a[k] !== b[k]) same = false; if (!isFinite(a[k])) finite = false; }
    return {name: name, length: a.length, peak: peak(a), same: same, finite: finite, last: Math.abs(a[a.length - 1])};
  });

  // timing: a clave (a short click) on steps 1, 5, 9 and 13 at 120, and
  // on every step at 100 with a swing of 60
  let r = await B.render({bpm: 120, swing: 0, steps: 16, ch: [ch(13)], rows: ['9000900090009000']}, 1, rate, true);
  out.straight = onsets(r.left);
  r = await B.render({bpm: 100, swing: 60, steps: 16, ch: [ch(13)], rows: ['9090909090909090']}, 1, rate, true);
  out.swungEven = onsets(r.left);
  r = await B.render({bpm: 100, swing: 60, steps: 16, ch: [ch(13)], rows: ['0909090909090909']}, 1, rate, true);
  out.swungOdd = onsets(r.left);

  // the mixer
  const kick = (vol, pan, mute, solo, row) => ({bpm: 120, swing: 0, steps: 16,
      ch: [ch(0, vol, pan, mute, solo), ch(13, 100, 0, 0, 0)], rows: [row || '9000000000000000', empty]});
  r = await B.render(kick(100), 1, rate, true); out.full = rms(r.left, 0, rate);
  r = await B.render(kick(50), 1, rate, true); out.half = rms(r.left, 0, rate);
  r = await B.render(kick(100, 0, 0, 0, '3000000000000000'), 1, rate, true); out.soft = rms(r.left, 0, rate);
  r = await B.render(kick(100, 0, 1), 1, rate, true); out.muted = peak(r.left) + peak(r.right);
  r = await B.render({bpm: 120, swing: 0, steps: 16, ch: [ch(0), ch(13, 100, 0, 0, 1)],
                      rows: ['9000000000000000', empty]}, 1, rate, true);
  out.soloOther = peak(r.left) + peak(r.right);
  r = await B.render(kick(100, -100), 1, rate, true); out.leftL = peak(r.left); out.leftR = peak(r.right);
  r = await B.render(kick(100, 100), 1, rate, true); out.rightL = peak(r.left); out.rightR = peak(r.right);

  // the limiter: twelve kicks on one step
  const many = {bpm: 120, swing: 0, steps: 16, ch: [], rows: []};
  for (let i = 0; i < 12; i++) { many.ch.push(ch(i % 2 ? 1 : 0)); many.rows.push('9000000000000000'); }
  r = await B.render(many, 1, rate, false); out.limited = Math.max(peak(r.left), peak(r.right));

  // a song made safe
  out.clean = B.cleanSong({bpm: 9999, swing: -3, steps: 16, ch: [[99, 300, -500, 1, 0], [2]], rows: ['9x7']});
  out.clean2 = B.cleanSong({bpm: 100, mode: 'song', cur: 7, from: -4, master: [500, 1, 9, 95],
      ch: [[16, 50, 0, 0, 0, -10, 140, 50, 99]],
      pats: [{steps: 16, rows: ['9'], notes: [[[0, 99, 200, 0], [16, 2, 60, 7], [3, 2, 64, 5], 'x']]},
             {steps: 99, rows: []}],
      song: [[0, 0], [1, 1], [2, 5], [-1, 0], [3, 1.5]]});
  out.cutoffs = [B.cutoff(0), B.cutoff(100)];

  // song mode: pattern A (a bar) at bar 1 and bar 5, pattern B (two bars,
  // a clave on each) at bar 2; and the song started from bar 2
  const pa = {steps: 16, rows: ['9000000000000000']}, pb = {steps: 32, rows: ['90000000000000009000000000000000']};
  const arranged = {bpm: 120, swing: 0, mode: 'song', ch: [ch(13)], pats: [pa, pb], song: [[0, 0], [1, 1], [4, 0]]};
  out.timeline = B.timeline(B.cleanSong(arranged)).length;
  r = await B.render(arranged, 1, rate, true);
  out.songOnsets = onsets(r.left);
  out.songSeconds = r.seconds;
  r = await B.render(Object.assign({}, arranged, {from: 16}), 1, rate, true);
  out.fromOnsets = onsets(r.left);
  // pattern mode plays the pattern chosen, alone
  r = await B.render({bpm: 120, swing: 0, mode: 'pattern', cur: 1, ch: [ch(13)], pats: [pa, pb], song: [[0, 0]]}, 1, rate, true);
  out.curOnsets = onsets(r.left);

  // pitch: a synth note at its pitch, a step at the synth's own note
  // (moved by the channel's tune), a sample higher by an octave at C5
  const synthAt = (sound, tune, row, notes) => ({bpm: 120, swing: 0, steps: 16,
      ch: [[sound, 100, 0, 0, 0, 100, 0, 0, tune || 0]], pats: [{steps: 16, rows: [row || empty], notes: [notes || []]}]});
  out.pitch = {};
  r = await B.render(synthAt(20, 0, empty, [[0, 4, 69, 9]]), 1, rate, true); out.pitch.keys69 = pitch(r.left, 0.1 * rate);
  r = await B.render(synthAt(20, 0, empty, [[0, 4, 57, 9]]), 1, rate, true); out.pitch.keys57 = pitch(r.left, 0.1 * rate);
  r = await B.render(synthAt(17, 0, '9000000000000000'), 1, rate, true); out.pitch.bassStep = pitch(r.left, 0.05 * rate);
  r = await B.render(synthAt(16, 12, '9000000000000000'), 1, rate, true); out.pitch.leadTuned = pitch(r.left, 0.05 * rate);
  r = await B.render(synthAt(13, 0, empty, [[0, 1, 60, 9]]), 1, rate, true); out.pitch.clave60 = crossings(r.left, 0.002 * rate, 0.03 * rate);
  r = await B.render(synthAt(13, 0, empty, [[0, 1, 72, 9]]), 1, rate, true); out.pitch.clave72 = crossings(r.left, 0.002 * rate, 0.02 * rate);
  out.noteLog = r.log.map((e) => e[3]);
  r = await B.render(synthAt(13, -12, '9000000000000000'), 1, rate, true); out.pitch.claveDown = crossings(r.left, 0.002 * rate, 0.05 * rate);
  // a synth note sounds for as long as it is held, then its release
  r = await B.render(synthAt(20, 0, empty, [[0, 2, 60, 9]]), 1, rate, true, 2); out.held2 = lastLoud(r.left) / rate;
  r = await B.render(synthAt(20, 0, empty, [[0, 8, 60, 9]]), 1, rate, true, 2); out.held8 = lastLoud(r.left) / rate;
  // a pad shorter than its attack still ends
  r = await B.render(synthAt(18, 0, empty, [[0, 1, 60, 9]]), 1, rate, true, 2);
  out.padShort = {peak: peak(r.left), last: lastLoud(r.left) / rate};
  // every synth: finite, heard, and under 1 alone
  out.synths = [];
  for (let k = 0; k < B.synths.length; k++) {
    r = await B.render(synthAt(16 + k, 0, '9000000090000000', [[4, 2, 64, 9]]), 1, rate, true);
    let finite = true; for (let i = 0; i < r.left.length; i++) if (!isFinite(r.left[i])) finite = false;
    out.synths.push({name: B.synths[k], peak: peak(r.left), finite: finite});
  }

  // the channel's filter: the crash with it open and nearly shut
  const crash = (cut, rev, dly, master) => ({bpm: 120, swing: 0, steps: 16, master: master,
      ch: [[7, 100, 0, 0, 0, cut, rev || 0, dly || 0, 0]], rows: ['9000000000000000']});
  r = await B.render(crash(100), 1, rate, true); out.open = rms(r.left, 0, rate);
  r = await B.render(crash(20), 1, rate, true); out.shut = rms(r.left, 0, rate);
  // the master's volume
  r = await B.render(crash(100, 0, 0, [40, 0, 3, 35]), 1, rate, true); out.masterHalf = rms(r.left, 0, rate);
  // the reverb: a clap (0.4 s) with no send, then a send to a room and to
  // a hall; what is left after the clap and after the room has died
  const clap = (rev, size) => ({bpm: 120, swing: 0, steps: 16, master: [80, size, 3, 0],
      ch: [[4, 100, 0, 0, 0, 100, rev, 0, 0]], rows: ['9000000000000000']});
  r = await B.render(clap(0, 0), 1, rate, true, 2); out.dryTail = rms(r.left, 0.6 * rate, 1.0 * rate);
  out.dryClap = rms(r.left, 0, 0.4 * rate);
  r = await B.render(clap(60, 0), 1, rate, true, 2);
  out.roomTail = rms(r.left, 0.6 * rate, 1.0 * rate); out.roomLate = rms(r.left, 1.8 * rate, 2.4 * rate);
  r = await B.render(clap(60, 1), 1, rate, true, 2);
  out.hallLate = rms(r.left, 1.8 * rate, 2.4 * rate);
  // the delay: a clave sent to a delay of 3 steps (0.375 s at 120), with
  // no feedback (one echo) and with half (echoes that fade)
  const echo = (fb) => ({bpm: 120, swing: 0, steps: 16, master: [80, 0, 3, fb],
      ch: [[13, 100, 0, 0, 0, 100, 0, 50, 0]], rows: ['9000000000000000']});
  r = await B.render(echo(0), 1, rate, true, 1);
  out.echoOnsets = onsets(r.left);
  out.echoPeaks = out.echoOnsets.map((o) => peak(r.left.subarray(o, o + 0.1 * rate)));
  r = await B.render(echo(50), 1, rate, true, 1);
  out.fbOnsets = onsets(r.left);
  out.fbPeaks = out.fbOnsets.map((o) => peak(r.left.subarray(o, o + 0.1 * rate)));

  // a sample of the user's own: a WAV of a 1 kHz sine, made here, loaded
  // into slot 1 and played at C4 and C5; a slot given nonsense fails
  const n = Math.round(0.3 * rate), sine = new Float32Array(n);
  for (let i = 0; i < n; i++) sine[i] = 0.5 * Math.sin(2 * Math.PI * 1000 * i / rate) * (1 - i / n);
  const file = new Uint8Array(B.wav(sine, sine, rate));
  let bin = ''; for (let i = 0; i < file.length; i++) bin += String.fromCharCode(file[i]);
  out.wavHead = bin.slice(0, 4) + bin.slice(8, 16) + ':' + new DataView(file.buffer).getUint32(24, true) + ':' + file.length;
  out.loaded = [B.loadSample(1, btoa(bin)), B.loadSample(2, btoa('this is not a sound')), B.loadSample(0, '')];
  for (let i = 0; i < 100 && (B.sampleState(1) === 'wait' || B.sampleState(2) === 'wait'); i++) await new Promise((ok) => setTimeout(ok, 20));
  out.sampleStates = [B.sampleState(1), B.sampleState(2), B.sampleState(3)];
  r = await B.render(synthAt(21, 0, '9000000000000000'), 1, rate, true); out.pitch.user60 = crossings(r.left, 0.01 * rate, 0.2 * rate);
  r = await B.render(synthAt(21, 0, empty, [[0, 1, 72, 9]]), 1, rate, true); out.pitch.user72 = crossings(r.left, 0.01 * rate, 0.1 * rate);
  r = await B.render(synthAt(22, 0, '9000000000000000'), 1, rate, true); out.failedSlot = peak(r.left);
  B.clearSample(1);
  out.cleared = B.sampleState(1);

  // live: the steps it books, on the audio clock
  B.set({bpm: 150, swing: 0, steps: 16, ch: [ch(0)], rows: ['9999999999999999']});
  B.log = [];
  out.started = B.start();
  out.state = B.state();
  const seen = [];
  for (let i = 0; i < 12; i++) { await new Promise((ok) => setTimeout(ok, 60)); seen.push(B.now()); }
  out.seen = seen;
  out.booked = B.log.map((e) => e[2]);
  out.levels = B.levels();
  out.poll = B.poll();
  out.hits = [B.hit(0, 9), B.hit(0, 9, 72), B.hit(3, 9)];
  B.stop();
  out.stopped = B.now();
  B.log = null;
  return out;
}
"""


def check_core(p, browser_name, expect):
    """The audio core alone in a blank page (1 to 7 above)."""
    rate = 44100
    browser = getattr(p, browser_name).launch(
        executable_path=os.environ.get('OXT_CHROMIUM') or None,
        args=['--autoplay-policy=no-user-gesture-required'] if browser_name == 'chromium' else [])
    try:
        page = browser.new_page()
        errors = []
        page.on('pageerror', lambda e: errors.append(str(e)))
        page.set_content('<!doctype html><title>core</title><body></body>')
        m = page.evaluate(MEASURE, core_source())
        expect('core-runs', m['first'] == 'ok' and m['again'] == 'ok' and m['same'],
               '%s, %s' % (m['first'], m['again']))

        # 2 the kit, as the stack names it
        expect('kit-names', m['kit'] == stack_kit(), '%s' % m['kit'])
        bad = [s['name'] for s in m['sounds']
               if not (s['same'] and s['finite'] and abs(s['peak'] - 0.9) < 1e-4 and s['last'] < 1e-6 and s['length'] > 0)]
        expect('kit-sounds', not bad and len(m['sounds']) == 16, ', '.join(bad))

        # 3 timing: 120 beats a minute is a step of 0.125 s; at 100, 0.15
        step120 = rate * 60 / 120 / 4
        want = [round(k * step120) for k in (0, 4, 8, 12)]
        expect('timing-straight', close(m['straight'], want, 2), '%s, want %s' % (m['straight'], want))
        step100 = rate * 60 / 100 / 4
        delay = 0.60 * step100 / 2
        want_even = [round(k * step100) for k in range(0, 16, 2)]
        want_odd = [round(k * step100 + delay) for k in range(1, 16, 2)]
        expect('swing-leaves-the-beat', close(m['swungEven'], want_even, 2), '%s, want %s' % (m['swungEven'], want_even))
        expect('swing-moves-the-off-steps', close(m['swungOdd'], want_odd, 2), '%s, want %s' % (m['swungOdd'], want_odd))

        # 4 the mixer
        expect('volume-is-squared', abs(m['half'] / m['full'] - 0.25) < 0.01, '%.4f' % (m['half'] / m['full']))
        expect('velocity', abs(m['soft'] / m['full'] - 3 / 9) < 0.01, '%.4f' % (m['soft'] / m['full']))
        expect('mute-is-silent', m['muted'] == 0, '%g' % m['muted'])
        expect('solo-silences-the-rest', m['soloOther'] == 0, '%g' % m['soloOther'])
        expect('pan-left', m['leftL'] > 0.5 and m['leftR'] < 1e-6, '%g, %g' % (m['leftL'], m['leftR']))
        expect('pan-right', m['rightR'] > 0.5 and m['rightL'] < 1e-6, '%g, %g' % (m['rightL'], m['rightR']))

        # 5 the limiter
        expect('limiter', 0.5 < m['limited'] <= 0.99, '%g' % m['limited'])

        # 6 a song made safe
        c = m['clean']
        expect('clean-song', c['bpm'] == 240 and c['swing'] == 0 and c['ch'][0][:3] == [28, 100, -100]
               and c['ch'][1] == [2, 78, 0, 0, 0, 100, 0, 0, 0] and c['rows'] == ['9070000000000000', '0' * 16]
               and c['mode'] == 'pattern' and c['master'] == [80, 0, 3, 35] and len(c['pats']) == 1
               and c['song'] == [], '%s' % c)
        c = m['clean2']
        expect('clean-song-v2', c['mode'] == 'song' and c['cur'] == 1 and c['from'] == 0 and c['master'] == [100, 1, 4, 90]
               and c['ch'] == [[16, 50, 0, 0, 0, 0, 100, 50, 24]]
               and c['pats'][0]['notes'] == [[[0, 16, 127, 1], [3, 2, 64, 5]]]
               and c['pats'][1]['steps'] == 64 and c['pats'][1]['rows'] == ['0' * 64]
               and c['song'] == [[0, 0], [1, 1]], '%s' % c)
        expect('filter-range', abs(m['cutoffs'][0] - 80) < 1e-6 and abs(m['cutoffs'][1] - 20000) < 1e-6, '%s' % m['cutoffs'])

        # 8 song mode
        step = rate * 60 / 120 / 4
        expect('song-length', m['timeline'] == 80, '%s steps' % m['timeline'])
        want = [round(k * step) for k in (0, 16, 32, 64)]
        expect('song-plays-the-arrangement', close(m['songOnsets'], want, 2) and abs(m['songSeconds'] - 10) < 1e-9,
               '%s, want %s; %s s' % (m['songOnsets'], want, m['songSeconds']))
        want = [round(k * step) for k in (0, 16, 48)]
        expect('song-starts-where-asked', close(m['fromOnsets'], want, 2), '%s, want %s' % (m['fromOnsets'], want))
        want = [round(k * step) for k in (0, 16)]
        expect('pattern-mode-plays-the-pattern', close(m['curOnsets'], want, 2), '%s, want %s' % (m['curOnsets'], want))

        # 9 notes and synths
        pt = m['pitch']

        def near(f, want, cents=10):
            return f > 0 and abs(1200 * __import__('math').log2(f / want)) < cents

        for name, want in (('keys69', 440), ('keys57', 220), ('bassStep', 65.406), ('leadTuned', 523.25),
                           ('clave60', 2500), ('clave72', 5000), ('claveDown', 1250), ('user60', 1000), ('user72', 2000)):
            expect('pitch-' + name, near(pt[name], want), '%.2f Hz, want %s' % (pt[name], want))
        expect('notes-logged', m['noteLog'] == [72], '%s' % m['noteLog'])
        held = m['held8'] - m['held2']
        expect('synth-holds-its-note', abs(held - 0.75) < 0.03 and 0.25 < m['held2'] < 0.6, '%.3f s longer; %.3f s'
               % (held, m['held2']))
        expect('synth-short-pad-ends', m['padShort']['peak'] > 0.01 and m['padShort']['last'] < 1.0, '%s' % m['padShort'])
        bad = [s['name'] for s in m['synths'] if not (s['finite'] and 0.05 < s['peak'] < 1)]
        expect('synths-sound', not bad and len(m['synths']) == 5, '%s' % m['synths'])

        # 10 the mixer's filter, the master, the reverb and the delay
        expect('filter-cuts', m['shut'] < 0.2 * m['open'], '%.4f of %.4f' % (m['shut'], m['open']))
        expect('master-volume', abs(m['masterHalf'] / m['open'] - 0.25) < 0.01, '%.4f' % (m['masterHalf'] / m['open']))
        # the room, 0.2 to 0.6 s after the clap: between 30 and 10 dB under
        # the clap
        tail = m['roomTail'] / m['dryClap']
        expect('reverb-tail', m['dryTail'] == 0 and 0.03 < tail < 0.3, '%g; %.3f of the clap' % (m['dryTail'], tail))
        expect('reverb-hall-is-longer', m['roomLate'] < 1e-4 and m['hallLate'] > 10 * max(m['roomLate'], 1e-6),
               '%g, %g' % (m['roomLate'], m['hallLate']))
        d = round(3 * step)
        eo, ep = m['echoOnsets'], m['echoPeaks']
        expect('delay-echoes', close(eo, [0, d], 3) and 0.3 < ep[1] / ep[0] < 0.8 if len(ep) == 2 else False,
               '%s %s' % (eo, ep))
        fo, fp = m['fbOnsets'], m['fbPeaks']
        # (an echo of an echo may come a block, 128 samples, late: the
        # browser runs a loop of nodes a block behind)
        expect('delay-feedback', len(fo) >= 3 and close(fo[:2], [0, d], 3) and abs(fo[2] - fo[1] - d) <= 3 + 128
               and fp[2] < fp[1] < fp[0], '%s %s' % (fo, fp))

        # 11 the user's samples, and WAV files
        expect('wav-file', m['wavHead'] == 'RIFFWAVEfmt :44100:%d' % (44 + round(0.3 * rate) * 4), m['wavHead'])
        expect('samples-load', m['loaded'] == ['ok', 'ok', 'none'] and m['sampleStates'] == ['ready', 'error', '']
               and m['failedSlot'] == 0 and m['cleared'] == '', '%s %s %s %s' % (m['loaded'], m['sampleStates'],
                                                                              m['failedSlot'], m['cleared']))

        # 7 live, on the audio clock: 150 beats a minute is 0.1 s a step
        booked = m['booked']
        gaps = [b - a for a, b in zip(booked, booked[1:])]
        expect('live-starts', m['started'] == 'ok' and m['state'] == 'running', '%s %s' % (m['started'], m['state']))
        expect('live-books-a-step-apart', len(booked) >= 6 and all(abs(g - 0.1) < 1e-9 for g in gaps),
               '%d booked, gaps %s' % (len(booked), gaps[:4]))
        moved = [s for s in m['seen'] if s >= 0]
        expect('live-playhead-moves', len(set(moved)) >= 3 and all(0 <= s < 16 for s in moved), '%s' % m['seen'])
        expect('live-stops', m['stopped'] == -1, '%s' % m['stopped'])
        lv = m['levels']
        expect('meters', len(lv) == 2 and lv[0] > 40 and lv[1] > 40, '%s' % lv)
        step_now, _, levels = m['poll'].partition('|')
        expect('poll', step_now.lstrip('-').isdigit() and len(levels.split(',')) == 2, m['poll'])
        expect('hit', m['hits'] == ['ok', 'ok', 'none'], '%s' % m['hits'])

        # 12 a WAV export: the browser is handed a file to save
        with page.expect_download() as info:
            started = page.evaluate('''() => { beyondBeats.set({bpm: 120, swing: 0, steps: 16,
                ch: [[0, 100, 0, 0, 0]], rows: ['9000900090009000']}); return beyondBeats.exportWav('loop.wav'); }''')
        download = info.value
        data = open(download.path(), 'rb').read()
        state = page.evaluate('beyondBeats.exportState()')
        # two seconds of a bar at 120 and a tail of two
        frames = round((2 + 2) * 44100)
        expect('export-wav', started == 'ok' and state == 'done' and download.suggested_filename == 'loop.wav'
               and data[:4] == b'RIFF' and data[8:12] == b'WAVE' and len(data) == 44 + frames * 4
               and max(abs(int.from_bytes(data[i:i + 2], 'little', signed=True)) for i in range(44, 44 + 4 * 4410, 2)) > 3000,
               '%s %s %s %d bytes' % (started, state, download.suggested_filename, len(data)))
        expect('core-no-page-errors', not errors, ' | '.join(errors))
    finally:
        browser.close()


def close(found, want, tolerance):
    return len(found) == len(want) and all(abs(a - b) <= tolerance for a, b in zip(found, want))


def stack_kit():
    """The kit's names as the stack's script names them (kKit)"""
    path = os.path.join(REPO, 'tools', 'web-player', 'beyond-beats-stack.livecodescript')
    with open(path, encoding='utf-8') as f:
        for line in f:
            if line.startswith('constant kKit = '):
                return line.split('=', 1)[1].strip().strip('"').split(',')
    return []


def check_player(p, browser, url, shots, expect, wait_for):
    """The stack playing in a Stack Player: url is the bare player's page
    with the query that opens Beyond Beats (?play=Beyond%20Beats, or
    ?stack=... for a stack beside a player that has no such sample)."""
    context = browser.new_context(viewport={'width': 1100, 'height': 720})
    page = context.new_page()
    lines = []
    page.on('console', lambda m: lines.append(m.text))
    page.goto(url)
    opened = wait_for(page, lambda: any(x.startswith('PLAYER opened ' + TITLE) for x in lines),
                      'opening Beyond Beats', 120)
    page.wait_for_timeout(2000)
    box = page.locator('#canvas').bounding_box()

    def click(x, y):
        page.mouse.click(box['x'] + x, box['y'] + y)

    if shots:
        page.screenshot(path=os.path.join(shots, '30-beyond-beats.png'))
    expect('beyond-beats-opens', opened, '')
    click(*PLAY)
    playing = wait_for(page, lambda: page.evaluate('!!(window.beyondBeats && beyondBeats.playing && beyondBeats.now() >= 0)'),
                       'Beyond Beats playing', 10)
    song = page.evaluate('window.beyondBeats ? beyondBeats.song : null') or {}
    pats = song.get('pats') or [{}]
    expect('beyond-beats-plays', playing and song.get('bpm') == 122 and len(song.get('ch', [])) == 10
           and len(pats) == 4 and (pats[0].get('rows') or [''])[0] == '9000900090009000'
           and len(song.get('song', [])) == 12, '%s' % song)
    page.wait_for_timeout(1500)
    if shots:
        page.screenshot(path=os.path.join(shots, '31-beyond-beats-playing.png'))
    # the snare's step 3, off in the demo: a click puts it in the page's pattern
    click(*pad_point(2, 3))
    page.wait_for_timeout(600)
    row = page.evaluate("window.beyondBeats ? beyondBeats.song.pats[0].rows[1] : ''")
    expect('beyond-beats-pad-heard', row[2:3] == '7', row)
    # each view, while it plays: the playlist, the piano roll, the mixer
    for view in ('song', 'piano', 'mixer'):
        click(*TABS[view])
        page.wait_for_timeout(900)
        if shots:
            page.screenshot(path=os.path.join(shots, '3%d-beyond-beats-%s.png' % (('song', 'piano', 'mixer').index(view) + 2, view)))
    # the fourth pattern from the list, and its chords in the piano roll
    # (< from the first channel goes round to the last, the Keys)
    click(*CHORDS)
    click(*TABS['piano'])
    click(*PIANO_PREV)
    page.wait_for_timeout(900)
    cur = page.evaluate('window.beyondBeats ? beyondBeats.song.cur : null')
    expect('beyond-beats-pattern-chosen', cur == 3, '%s' % cur)
    if shots:
        page.screenshot(path=os.path.join(shots, '35-beyond-beats-chords.png'))
    # Song mode: the page plays the playlist, from where it starts
    click(*MODE_SONG)
    page.wait_for_timeout(800)
    state = page.evaluate("window.beyondBeats ? [beyondBeats.song.mode, beyondBeats.playing, beyondBeats.at.length] : null")
    expect('beyond-beats-song-mode', state is not None and state[0] == 'song' and state[1] is True
           and state[2] == 128, '%s' % state)
    click(*TABS['rack'])
    page.wait_for_timeout(300)
    click(*PLAY)
    page.wait_for_timeout(600)
    stopped = page.evaluate('window.beyondBeats ? beyondBeats.playing : null')
    expect('beyond-beats-stops', stopped is False, '%s' % stopped)
    errors = [x for x in lines if x.startswith('PLAYER script error')]
    expect('beyond-beats-no-script-error', not errors, ' | '.join(errors))
    # what it saved is there to open with next time
    context.close()


def serve(folder):
    handler = functools.partial(http.server.SimpleHTTPRequestHandler, directory=folder)
    handler.log_message = lambda *a: None
    server = http.server.ThreadingHTTPServer(('127.0.0.1', 0), handler)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    return server


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    ap.add_argument('--player', help='a built Stack Player folder: the stack is played in it too')
    ap.add_argument('--shots', help='a folder for screenshots')
    ap.add_argument('--work', help='the work folder (default: a temporary folder)')
    args = ap.parse_args(argv)
    try:
        from playwright.sync_api import sync_playwright
    except ImportError:
        log('FAILED: the Python package playwright is missing')
        return 1
    if args.shots:
        os.makedirs(args.shots, exist_ok=True)
    problems = []

    def expect(name, ok, detail=''):
        if not ok:
            problems.append(name + (': ' + detail if detail else ''))
        log('  %s %s %s' % ('PASS' if ok else 'FAIL', name, detail))

    def wait_for(page, pred, what, seconds):
        end = time.time() + seconds
        while time.time() < end:
            if pred():
                return True
            page.wait_for_timeout(100)
        problems.append('%s: not within %d s' % (what, seconds))
        return False

    server = None
    with sync_playwright() as p:
        log('The audio core:')
        check_core(p, 'chromium', expect)
        if args.player:
            # the stack beside the player, opened by the bare player
            work = args.work or tempfile.mkdtemp(prefix='beyond-beats-check-')
            site = os.path.join(work, 'site')
            shutil.rmtree(site, ignore_errors=True)
            shutil.copytree(args.player, site)
            os.makedirs(os.path.join(site, 'stacks'), exist_ok=True)
            shutil.copy(STACK, os.path.join(site, 'stacks', 'beyond-beats.oxtstack'))
            server = serve(site)
            url = 'http://127.0.0.1:%d/play/?stack=../stacks/beyond-beats.oxtstack' % server.server_address[1]
            log('The stack in %s:' % args.player)
            browser = p.chromium.launch(executable_path=os.environ.get('OXT_CHROMIUM') or None,
                                        args=['--autoplay-policy=no-user-gesture-required'])
            try:
                check_player(p, browser, url, args.shots, expect, wait_for)
            finally:
                browser.close()
    if server:
        server.shutdown()
    if problems:
        log('BEYOND BEATS CHECK FAILED')
        for problem in problems:
            log('  %s' % problem)
        return 1
    log('BEYOND BEATS CHECK OK')
    return 0


if __name__ == '__main__':
    sys.exit(main())
