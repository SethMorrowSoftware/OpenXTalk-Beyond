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
error, Play starts the page's core at the stack's tempo with its pattern
and the playhead follows, a click on a pad is in the page's pattern at
once, and Stop stops it.

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
PLAY = (239, 30)
GRID_LEFT, GRID_WIDTH, ROW_TOP, ROW_H, PAD_H = 500, 444, 108, 34, 28


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

  // live: the steps it books, on the audio clock
  B.set({bpm: 150, swing: 0, steps: 16, ch: [ch(0)], rows: ['9999999999999999']});
  B.log = [];
  out.started = B.start();
  out.state = B.state();
  const seen = [];
  for (let i = 0; i < 12; i++) { await new Promise((ok) => setTimeout(ok, 60)); seen.push(B.now()); }
  out.seen = seen;
  out.booked = B.log.map((e) => e[2]);
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
        expect('clean-song', c['bpm'] == 240 and c['swing'] == 0 and c['ch'][0][:3] == [15, 100, -100]
               and c['ch'][1] == [2, 78, 0, 0, 0] and c['rows'] == ['9070000000000000', '0' * 16], '%s' % c)

        # 7 live, on the audio clock: 150 beats a minute is 0.1 s a step
        booked = m['booked']
        gaps = [b - a for a, b in zip(booked, booked[1:])]
        expect('live-starts', m['started'] == 'ok' and m['state'] == 'running', '%s %s' % (m['started'], m['state']))
        expect('live-books-a-step-apart', len(booked) >= 6 and all(abs(g - 0.1) < 1e-9 for g in gaps),
               '%d booked, gaps %s' % (len(booked), gaps[:4]))
        moved = [s for s in m['seen'] if s >= 0]
        expect('live-playhead-moves', len(set(moved)) >= 3 and all(0 <= s < 16 for s in moved), '%s' % m['seen'])
        expect('live-stops', m['stopped'] == -1, '%s' % m['stopped'])
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
    expect('beyond-beats-plays', playing and song.get('bpm') == 122 and len(song.get('rows', [])) == 8
           and song.get('rows', [''])[0] == '9000900090009000', '%s' % song)
    page.wait_for_timeout(1500)
    if shots:
        page.screenshot(path=os.path.join(shots, '31-beyond-beats-playing.png'))
    # the snare's step 3, off in the demo: a click puts it in the page's pattern
    click(*pad_point(2, 3))
    page.wait_for_timeout(600)
    row = page.evaluate("window.beyondBeats ? beyondBeats.song.rows[1] : ''")
    expect('beyond-beats-pad-heard', row[2:3] == '7', row)
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
