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

"""Check that OXT-Beyond Home opens without building its whole tour, and
that on a slow computer it leaves half the time to everything else, on
Linux.

  python3 tools/ci/home_speed_check.py --engine FILE [--drawing FILE]
      [--toolset FOLDER] [--log FILE] [--timeout SECONDS]

Some users run OXT-Beyond on low-powered computers (seth, 2026-11-09).
Up to 0.2.7-rc.6.19 Home (palettes/web home/revwebhome.livecodescript)
built all six pages of its tour as it opened, some 550 controls, though
the window shows the first; now it builds the first, and each other page
the first time it is shown (hmBuildPage). And each frame of its
animations was followed by 16 milliseconds whatever it had cost, so a
computer that takes 200 milliseconds to draw one was kept busy nine
tenths of the time; now Home waits as long as its frames take
(hmFrameDelay), and the Academy and Learn in Home (revLearnKit's
lkFrameDelay) do the same.

The check starts its own X server (Xvfb) and runs a standalone engine
(the runtime's Standalone) with tools/ci/home-speed-check.livecodescript,
which opens Home from the Toolset at its first page and reads:

  - the pages built as it opens: only the first;
  - each page, shown by the right arrow key: built, and shown;
  - every page built once all have been shown;
  - Home in front: frames a second (at least 15: a computer that draws a
    frame quickly is not slowed);
  - Home in front on a computer made slow, by soft glows over its hero
    that every frame draws again: at most 75 percent of a core (half, as
    paced; nine tenths and more before).

The check fails, rather than passing blind, when the glows did not make
a frame take 30 milliseconds or more (the pacing would not show).

Needs Xvfb. Exit status 0 when every check passed, 1 otherwise. Under
GitHub Actions a failure is an annotation and the results go into the
job summary.
"""

import argparse
import os
import select
import shutil
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
SCRIPT = os.path.join(HERE, 'home-speed-check.livecodescript')
TOOLSET = os.path.join(REPO, 'ide', 'Toolset')
DRAWING = os.path.join(REPO, 'extensions', 'script-libraries', 'drawing', 'drawing.livecodescript')

PAGES = ('home', 'speak', 'move', 'draw', 'web', 'app')
# frames a second Home must at least draw in front, unslowed
MIN_FRONT_FPS = 15
# the most of a core Home may keep busy on the slowed computer
MAX_SLOW_CPU = 75
# the least a slowed frame must cost for the pacing to show, in ms
MIN_SLOW_FRAME_MS = 30


def log(msg=''):
    print(msg, flush=True)


def numbers(fields, count):
    """The first count fields as floats, or None."""
    try:
        values = [float(x) for x in fields[:count]]
    except ValueError:
        return None
    return values if len(values) == count else None


def evaluate(result):
    """(name, ok, detail) for each check, from the script's lines."""
    rows = {}
    pages = {}
    errors = []
    for line in result:
        fields = line.split('\t')
        if fields[0] == 'PAGE' and len(fields) >= 5:
            pages[fields[1]] = fields[2:]
        elif fields[0] == 'ERROR':
            errors.append('\t'.join(fields[1:]))
        else:
            rows[fields[0]] = fields[1:]
    checks = []
    checks.append(('no script error', not errors, '; '.join(errors)))
    checks.append(('the script finished', 'DONE' in rows, 'no DONE line'))

    opened = rows.get('OPEN')
    if opened is None or len(opened) < 3:
        checks.append(('Home opens', False, 'no OPEN line'))
    else:
        built = [x for x in opened[2].split(',') if x]
        checks.append(('Home opens', True, ''))
        checks.append(('Home builds only its first page as it opens', built == ['home'],
                       'built at open: %s' % (', '.join(built) or 'none')))

    for page in PAGES[1:]:
        values = pages.get(page)
        if values is None:
            checks.append(('the %s page is shown' % page, False, 'no PAGE line'))
            continue
        checks.append(('the %s page is built when it is first shown' % page, values[0] == 'true',
                       'built: %s' % values[0]))
        checks.append(('the %s page is shown' % page, values[1] == 'true', 'visible: %s' % values[1]))

    built = rows.get('BUILT')
    every = [x for x in built[0].split(',') if x] if built else []
    checks.append(('every page is built once each has been shown', sorted(every) == sorted(PAGES),
                   'built: %s' % (', '.join(every) or 'none')))

    front = numbers(rows.get('FRONT', []), 2)
    if front is None:
        checks.append(('Home in front draws its frames as before', False, 'no FRONT line'))
    else:
        checks.append(('Home in front draws its frames as before', front[0] >= MIN_FRONT_FPS,
                       '%.1f frames a second, fewer than %d' % (front[0], MIN_FRONT_FPS)))

    slow = numbers(rows.get('SLOW', []), 2)
    if slow is None:
        checks.append(('Home on a slow computer leaves time to the rest', False, 'no SLOW line'))
    else:
        fps, cpu = slow
        frame_ms = (cpu * 10.0 / fps) if fps > 0 else float('inf')
        checks.append(('the glows make a frame slow enough to check', frame_ms >= MIN_SLOW_FRAME_MS,
                       'a frame took %.1f ms of CPU, less than %d' % (frame_ms, MIN_SLOW_FRAME_MS)))
        checks.append(('Home on a slow computer leaves time to the rest', cpu <= MAX_SLOW_CPU,
                       '%.1f%% of a core, more than %d%%' % (cpu, MAX_SLOW_CPU)))
    return checks


def start_xvfb():
    xvfb = shutil.which('Xvfb')
    if not xvfb:
        raise RuntimeError('Xvfb is not installed')
    r, w = os.pipe()
    proc = subprocess.Popen([xvfb, '-displayfd', str(w), '-screen', '0', '1600x1000x24', '-nolisten', 'tcp'],
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


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    ap.add_argument('--engine', required=True, help='the standalone engine to run')
    ap.add_argument('--toolset', default=TOOLSET, help='the IDE\'s Toolset folder (default: this tree\'s)')
    ap.add_argument('--drawing', default=DRAWING,
                    help='the Drawing library\'s script, which Home draws its icons with (default: this tree\'s)')
    ap.add_argument('--log', help='write the results to this file too')
    ap.add_argument('--timeout', type=int, default=180, help='seconds the engine may take')
    args = ap.parse_args(argv)

    if not sys.platform.startswith('linux'):
        log('The Home speed check is for Linux only')
        return 0
    engine = os.path.abspath(args.engine)

    lines, problems = [], []
    work = tempfile.mkdtemp(prefix='oxt-home-speed-')
    xvfb = None
    try:
        hub = os.path.join(args.toolset, 'palettes', 'home', 'revhub.livecodescript')
        if not os.path.isfile(hub):
            raise RuntimeError('Home is not in the Toolset: %s' % hub)
        if not os.path.isfile(args.drawing):
            raise RuntimeError('the Drawing library is not there: %s' % args.drawing)
        result_log = os.path.join(work, 'engine.log')
        xvfb, display_name = start_xvfb()
        log('X server %s, engine %s, Toolset %s' % (display_name, engine, args.toolset))
        env = dict(os.environ)
        env.pop('WAYLAND_DISPLAY', None)
        env.update({'DISPLAY': display_name, 'OXT_HOME_LOG': result_log,
                    'OXT_HOME_TOOLSET': os.path.abspath(args.toolset),
                    'OXT_HOME_DRAWING': os.path.abspath(args.drawing)})
        try:
            proc = subprocess.run([engine, SCRIPT], cwd=work, env=env, stdout=subprocess.PIPE,
                                  stderr=subprocess.STDOUT, timeout=args.timeout)
            code, output = proc.returncode, proc.stdout.decode('utf-8', 'replace')
        except subprocess.TimeoutExpired as e:
            code, output = None, (e.stdout or b'').decode('utf-8', 'replace')
        result = []
        if os.path.exists(result_log):
            with open(result_log, encoding='utf-8', errors='replace') as f:
                result = [x.rstrip('\r\n') for x in f if x.strip()]
        lines += ['INFO engine: ' + x.replace('\t', ' ') for x in result]
        if code is None:
            lines.append('INFO the engine timed out after %d seconds' % args.timeout)
        for name, ok, detail in evaluate(result):
            lines.append('%s %s%s' % ('PASS' if ok else 'FAIL', name, (': ' + detail) if detail and not ok else ''))
            if not ok:
                problems.append('%s%s' % (name, (': ' + detail) if detail else ''))
        if problems and output.strip():
            lines.append('INFO engine output: ' + output[-2000:])
    except RuntimeError as e:
        problems.append(str(e))
        lines.append('FAIL ' + str(e))
    finally:
        if xvfb is not None:
            xvfb.kill()
            xvfb.wait()
        shutil.rmtree(work, ignore_errors=True)

    log('\n'.join(lines))
    if args.log:
        with open(args.log, 'w', encoding='utf-8') as f:
            f.write('\n'.join(lines) + '\n')
    if os.environ.get('GITHUB_ACTIONS') == 'true':
        for p in problems:
            print('::error title=Home speed check::%s' % p.replace('\n', ' '))
        summary = os.environ.get('GITHUB_STEP_SUMMARY')
        if summary:
            with open(summary, 'a', encoding='utf-8') as f:
                f.write('### Home speed check (Linux)\n\n```\n%s\n```\n' % '\n'.join(lines))
    return 1 if problems else 0


if __name__ == '__main__':
    sys.exit(main())
