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

"""Check the Linux engine at a desktop's HiDPI scale and at 1x.

  python3 tools/ci/hidpi_check.py --engine FILE [--log FILE] [--shots DIR]
      [--timeout SECONDS]

On a desktop scaled to 200% the engine draws its windows at twice their
size in points (lnxdc.cpp, MCLinuxReadDesktopScale), and text with the
font at twice its size (libgraphics/src/lnxtext.cpp). The check starts
its own X server (Xvfb) three times and runs a standalone engine (the
runtime's Standalone, or the bin folder's standalone-community) with
tools/ci/hidpi-check.livecodescript on it:

  1. 1280 x 1024 with GDK_SCALE=1: the desktop does not scale, and the
     engine must see the screen, its scale and usePixelScaling as it
     always did (1x, false and not settable).
  2. 2560 x 2048 with GDK_SCALE=2: the screenRect is in points
     (0,0,1280,1024), the screenPixelScale and systemPixelScale are 2,
     the pixelScale 1 and usePixelScaling true; turning it off gives
     the screen's pixels back.
  3. 2560 x 2048 with no GDK_SCALE and an XSETTINGS manager (xsettingsd)
     publishing Gdk/WindowScalingFactor 2, as GNOME and the other
     desktops do: the same as 2. Skipped when xsettingsd is missing.

In each run the script lays out one line of text in fields of two fonts
(DejaVu Sans Mono and DejaVu Sans) at six sizes, and says where the
engine measures each line to start and end. A picture of the screen
(ImageMagick's import) must have the line's glyphs between those places,
at the scale: Pango rounds each glyph's advance to a whole pixel, so a
line measured at one size and drawn at twice it can end tens of pixels
away from where the caret and the next run of text are put.

Needs Xvfb, ImageMagick and the DejaVu fonts. Exit status 0 when every
check passed, 1 otherwise. Under GitHub Actions a failure is an
annotation and the results go into the job summary.
"""

import argparse
import os
import select
import shutil
import subprocess
import sys
import tempfile
import time

HERE = os.path.dirname(os.path.abspath(__file__))
SCRIPT = os.path.join(HERE, 'hidpi-check.livecodescript')

# How far (in the screen's pixels) the last glyph's ink may end from where
# the line is measured to end: its side bearing, and a pixel of rounding
# each way. The fault this looks for is tens of pixels.
INK_TOLERANCE = 4


def log(msg=''):
    print(msg, flush=True)


def start_xvfb(width, height):
    xvfb = shutil.which('Xvfb')
    if not xvfb:
        raise RuntimeError('Xvfb is not installed')
    r, w = os.pipe()
    proc = subprocess.Popen([xvfb, '-displayfd', str(w), '-screen', '0', '%dx%dx24' % (width, height),
                             '-nolisten', 'tcp'],
                            pass_fds=(w,), stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    os.close(w)
    number = b''
    while not number.endswith(b'\n'):
        ready, _, _ = select.select([r], [], [], 30)
        if not ready:
            proc.kill()
            raise RuntimeError('Xvfb did not start')
        chunk = os.read(r, 16)
        if not chunk:
            raise RuntimeError('Xvfb did not start')
        number += chunk
    os.close(r)
    return proc, ':' + number.decode().strip()


def start_xsettingsd(display_name, scale, work):
    """An XSETTINGS manager publishing the desktop's window scale, as GNOME's
    gsd-xsettings does"""
    exe = shutil.which('xsettingsd')
    if not exe:
        return None
    conf = os.path.join(work, 'xsettingsd.conf')
    with open(conf, 'w') as f:
        f.write('Gdk/WindowScalingFactor %d\nGdk/UnscaledDPI %d\nXft/DPI %d\n'
                % (scale, 96 * 1024, 96 * 1024 * scale))
    env = dict(os.environ, DISPLAY=display_name)
    proc = subprocess.Popen([exe, '-c', conf], env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    # Give it time to take the _XSETTINGS_S0 selection
    time.sleep(2)
    if proc.poll() is not None:
        raise RuntimeError('xsettingsd ended at once (exit status %s)' % proc.returncode)
    return proc


def read_ppm(data):
    """(width, height, rows of RGB bytes) of a binary PPM (P6, maxval 255)"""
    fields, pos = [], 0
    while len(fields) < 4:
        while data[pos:pos + 1].isspace():
            pos += 1
        if data[pos:pos + 1] == b'#':
            pos = data.index(b'\n', pos) + 1
            continue
        start = pos
        while not data[pos:pos + 1].isspace():
            pos += 1
        fields.append(data[start:pos])
    if fields[0] != b'P6' or int(fields[3]) != 255:
        raise RuntimeError('not an 8-bit PPM: %r' % fields)
    width, height = int(fields[1]), int(fields[2])
    pixels = data[pos + 1:]
    return width, height, [pixels[y * width * 3:(y + 1) * width * 3] for y in range(height)]


def take_screen(display_name, path):
    """The whole screen as a PNG at path, and its pixels"""
    subprocess.run(['import', '-display', display_name, '-window', 'root', path], check=True,
                   stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, timeout=60)
    ppm = subprocess.run(['convert', path, '-depth', '8', 'ppm:-'], check=True, stdout=subprocess.PIPE,
                         timeout=60).stdout
    return read_ppm(ppm)


def ink_columns(screen, left, top, right, bottom):
    """The first and last column (in the screen's pixels) of dark pixels in
    the box, or None"""
    width, height, rows = screen
    first = last = None
    for y in range(max(top, 0), min(bottom, height)):
        row = rows[y]
        for x in range(max(left, 0), min(right, width)):
            r, g, b = row[3 * x], row[3 * x + 1], row[3 * x + 2]
            if r + g + b < 3 * 128:
                if first is None or x < first:
                    first = x
                if last is None or x > last:
                    last = x
    return (first, last) if first is not None else None


def run_engine(engine, display_name, env_extra, work, timeout, on_ready):
    result_log = os.path.join(work, 'engine.log')
    shot_flag = os.path.join(work, 'shot.done')
    for p in (result_log, shot_flag):
        if os.path.exists(p):
            os.remove(p)
    env = dict(os.environ)
    env.pop('GDK_SCALE', None)
    env.update({'DISPLAY': display_name, 'OXT_HIDPI_LOG': result_log, 'OXT_HIDPI_SHOT': shot_flag})
    env.update(env_extra)
    proc = subprocess.Popen([engine, SCRIPT], cwd=work, env=env, stdout=subprocess.PIPE,
                            stderr=subprocess.STDOUT)

    def lines():
        if not os.path.exists(result_log):
            return []
        with open(result_log, encoding='utf-8', errors='replace') as f:
            return [x.rstrip('\r\n') for x in f if x.strip()]

    end = time.time() + timeout
    shot = None
    while time.time() < end and proc.poll() is None:
        current = lines()
        if 'READY' in current and shot is None:
            time.sleep(0.5)
            shot = on_ready(current)
            open(shot_flag, 'w').close()
        if 'QUIT' in current:
            break
        time.sleep(0.2)
    try:
        output, _ = proc.communicate(timeout=max(5, end - time.time()))
        code = proc.returncode
    except subprocess.TimeoutExpired:
        proc.kill()
        output, _ = proc.communicate()
        code = None
    return code, output.decode('utf-8', 'replace'), lines(), shot


def parse(result):
    """The engine's log as a dictionary of its values"""
    info = {'fields': [], 'nofont': []}
    for line in result:
        word, _, rest = line.partition(' ')
        if word in ('SCREEN', 'WORKING', 'SCALE'):
            when, _, value = rest.partition(' ')
            info['%s %s' % (word, when)] = value
        elif word == 'FIELD':
            # FIELD number|font|size|left top right bottom
            number, font, size, place = rest.split('|')
            info['fields'].append((number, font, size, [float(x) for x in place.split()]))
        elif word == 'NOFONT':
            info['nofont'].append(rest)
        elif word in ('STACK', 'ERROR', 'NOUNSCALE', 'INFO'):
            info.setdefault(word, []).append(rest)
    return info


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    ap.add_argument('--engine', required=True, help='the standalone engine to run')
    ap.add_argument('--log', help='write the results to this file too')
    ap.add_argument('--shots', help='keep the pictures of the screen in this folder')
    ap.add_argument('--timeout', type=int, default=90, help='seconds each engine run may take')
    args = ap.parse_args(argv)

    if not sys.platform.startswith('linux'):
        log('The HiDPI check is for Linux only')
        return 0
    engine = os.path.abspath(args.engine)
    if args.shots:
        os.makedirs(args.shots, exist_ok=True)

    lines, problems = [], []

    def check(name, ok, detail=''):
        lines.append('%s %s%s' % ('PASS' if ok else 'FAIL', name, (': ' + detail) if detail and not ok else ''))
        if not ok:
            problems.append('%s%s' % (name, (': ' + detail) if detail else ''))

    runs = [
        ('1x', 1, (1280, 1024), {'GDK_SCALE': '1'}, False),
        ('GDK_SCALE=2', 2, (2560, 2048), {'GDK_SCALE': '2'}, False),
        ('XSETTINGS scale 2', 2, (2560, 2048), {}, True),
    ]
    work = tempfile.mkdtemp(prefix='oxt-hidpi-')
    try:
        for label, scale, (width, height), env_extra, xsettings in runs:
            xvfb, display_name = start_xvfb(width, height)
            manager = None
            try:
                if xsettings:
                    manager = start_xsettingsd(display_name, scale, work)
                    if manager is None:
                        lines.append('SKIP %s: xsettingsd is not installed' % label)
                        continue
                log('%s: X server %s (%d x %d), engine %s' % (label, display_name, width, height, engine))
                shot_path = os.path.join(args.shots or work, 'hidpi-%s.png' % label.replace(' ', '-').replace('=', ''))

                def on_ready(current, shot_path=shot_path):
                    return take_screen(display_name, shot_path)

                code, output, result, screen = run_engine(engine, display_name, env_extra, work,
                                                          args.timeout, on_ready)
                info = parse(result)
                lines.extend('INFO %s: %s' % (label, x) for x in info.get('INFO', []))
                check('%s: the engine ran the check and quit' % label,
                      code is not None and 'QUIT' in result and not info.get('ERROR'),
                      'exit status %s, errors %r, output: %s' % (code, info.get('ERROR'), output[-2000:]))
                points = (width // scale, height // scale)
                check('%s: the screenRect is in points' % label,
                      info.get('SCREEN start') == '0,0,%d,%d' % points,
                      'got %r, expected 0,0,%d,%d' % ((info.get('SCREEN start'),) + points))
                scales = (info.get('SCALE start') or '').split()
                if scale == 1:
                    check('%s: the scales are 1 and usePixelScaling false, as before' % label,
                          scales[:4] == ['1', '1', '1', 'false'], 'got %r' % scales)
                    check('%s: usePixelScaling cannot be set, as before' % label,
                          bool(info.get('NOUNSCALE')), 'it could be set')
                else:
                    check('%s: the screenPixelScale and systemPixelScale are %d, the pixelScale 1, '
                          'usePixelScaling true' % (label, scale),
                          scales[:4] == [str(scale), str(scale), '1', 'true'], 'got %r' % scales)
                    check('%s: usePixelScaling false gives the screen\'s pixels' % label,
                          info.get('SCREEN unscaled') == '0,0,%d,%d' % (width, height),
                          'got %r (%r)' % (info.get('SCREEN unscaled'), info.get('NOUNSCALE')))

                for font in info['nofont']:
                    lines.append('SKIP %s: the font %s is not installed' % (label, font))
                check('%s: the engine laid out the fields' % label, bool(info['fields']) and screen is not None,
                      'fields %r, screen %s' % (info['fields'], 'taken' if screen else 'not taken'))
                if screen is None:
                    continue
                for number, font, size, (left, top, right, bottom) in info['fields']:
                    box = (int(left * scale) - 40, int(top * scale), int(right * scale) + 40, int(bottom * scale))
                    ink = ink_columns(screen, *box)
                    name = '%s: %s %s, the line\'s glyphs end where it is measured to' % (label, font, size)
                    if ink is None:
                        check(name, False, 'no text drawn at %r (screen pixels)' % (box,))
                        continue
                    first, last = ink
                    expected_last = right * scale
                    detail = ('measured %.2f to %.2f points, so %.1f to %.1f pixels; ink %d to %d'
                              % (left, right, left * scale, expected_last, first, last))
                    lines.append('INFO %s %s %s: %s' % (label, font, size, detail))
                    check(name, abs(last + 1 - expected_last) <= INK_TOLERANCE, detail)
            finally:
                if manager is not None:
                    manager.kill()
                    manager.wait()
                xvfb.kill()
                xvfb.wait()
    except Exception as e:  # noqa: BLE001 - the check reports what failed
        problems.append(str(e))
        lines.append('FAIL ' + str(e))
    finally:
        shutil.rmtree(work, ignore_errors=True)

    log('\n'.join(lines))
    if args.log:
        with open(args.log, 'w', encoding='utf-8') as f:
            f.write('\n'.join(lines) + '\n')
    if os.environ.get('GITHUB_ACTIONS') == 'true':
        for p in problems:
            print('::error title=HiDPI check::%s' % p.replace('\n', ' '))
        summary = os.environ.get('GITHUB_STEP_SUMMARY')
        if summary:
            with open(summary, 'a', encoding='utf-8') as f:
                f.write('### HiDPI check\n\n```\n%s\n```\n' % '\n'.join(lines))
    log('HiDPI check %s' % ('passed' if not problems else 'FAILED: %d problem(s)' % len(problems)))
    return 1 if problems else 0


if __name__ == '__main__':
    sys.exit(main())
