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

"""A stack's window at the opacity its blendLevel gives it: the forum's
report on 2026-11-21 (bwmilby, p=26650) that on a Mac the IDE's Message
Box never appeared. As the IDE starts it opens the Message Box invisible
at a blendLevel of 99, closes it and sets the blendLevel to 0 twice. The
second set lost the first (engine/src/exec-interface-stack.cpp,
MCStack::SetBlendLevel), and the window the stack kept stayed at the
opacity it was made with: see-through. Until 0.2.8-dp.2's Message Box
fix (one window when it opens, not two) every open made its window
again, which hid that.

  python3 tools/ci/window_opacity_check.py --app OXT-Beyond.app --out DIR
  python3 tools/ci/window_opacity_check.py --engine standalone --out DIR
      [--report-only]

Runs tools/ci/window-opacity-check.livecodescript: on a Mac as the
development engine's home stack (copied to <out>/tools/Startup.rev,
REV_TOOLS_PATH pointing there), on Linux as the standalone engine's stack
on an Xvfb screen of its own. The script shows a window of one colour in
four ways, and after each says where it is (a SHOT line in log.txt) and
waits for this script to look:

  seen         at blendLevel 0: must be shown, else the check cannot see
               the window
  see-through  at blendLevel 99: must be clear, else the check cannot
               tell a window's opacity
  set-twice    set to 0 twice with the screen locked: must be shown
  reopened     the Message Box's way (made invisible as a palette at 99,
               closed, set to 0 twice while closed, opened as a palette
               again): must be shown

On a Mac the window's area is taken from the screen (screencapture -R)
and judged by its pixels: shown when nearly all are the stack's colour,
clear when nearly none are. Linux under Xvfb draws no window see-through,
so there the window's _NET_WM_WINDOW_OPACITY, which the engine sets
through GDK for a compositing window manager to draw by, is read with
xprop: shown when there is none (opaque) and clear when it is near 0.
0.2.8-dp.2's standalone engine on Linux left both set-twice and reopened
at the opacity of blendLevel 99 (2026-11-21). The IDE probably escaped
it on Linux, where its Message Box has the toplevel style
(revInternal__InitialiseMessageBox) and so is not opened again in the
palette window it was made as.

Exit status 0 when every window was as expected, 1 when set-twice or
reopened was not, 2 when the check itself could not run (no window seen,
an opacity it cannot tell, a script error). With --report-only, a fault
found is reported and the exit status is 0 (a release's run, whose fault
is known). Only the Python 3 standard library is used.
"""

import argparse
import os
import shutil
import struct
import subprocess
import sys
import time
import zlib

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import visual_effect_check as vec  # noqa: E402

SCRIPT = os.path.join(HERE, 'window-opacity-check.livecodescript')
# The stack's colour in the script (kColour)
COLOUR = (0, 255, 0)
# The share of a picture's pixels of the stack's colour at which it is
# shown, and at or below which it is clear
SHOWN_SHARE = 0.97
CLEAR_SHARE = 0.03
# An opacity read from the window at or above which it is shown, and at
# or below which it is clear
SHOWN_OPACITY = 0.99
CLEAR_OPACITY = 0.05
# Pictures taken of each window on a Mac, and the seconds between them:
# the last is judged, the others say whether it was still changing
PICTURES = 3
BETWEEN = 0.3

SHOWN, CLEAR, PARTLY, UNKNOWN = 'shown', 'clear', 'partly', 'unknown'
# The windows the check itself needs to be as expected to judge the others
CONTROLS = {'seen': SHOWN, 'see-through': CLEAR}


def log(text=''):
    print(text)
    sys.stdout.flush()


# --------------------------------------------------------------- judging

def is_colour(pixel):
    """Whether a pixel is the stack's colour (pure green), allowing for a
    screen's colour profile."""
    r, g, b = pixel
    return g >= 160 and r <= 100 and b <= 100


def colour_share(width, height, rows, grid=16):
    """The share of a grid of the picture's pixels that are the stack's
    colour."""
    if width < 1 or height < 1:
        return 0.0
    count = total = 0
    for gy in range(grid):
        y = min(height - 1, (2 * gy + 1) * height // (2 * grid))
        for gx in range(grid):
            x = min(width - 1, (2 * gx + 1) * width // (2 * grid))
            count += 1 if is_colour(rows[y][x]) else 0
            total += 1
    return count / float(total)


def state_of_share(share):
    if share >= SHOWN_SHARE:
        return SHOWN
    if share <= CLEAR_SHARE:
        return CLEAR
    return PARTLY


def parse_xprop_opacity(text):
    """The opacity (0 to 1) in xprop's answer for _NET_WM_WINDOW_OPACITY:
    1.0 when the window has none (opaque), None when the answer is not
    one xprop gives."""
    text = text.strip()
    if 'not found' in text or 'no such atom' in text:
        return 1.0
    if '=' not in text:
        return None
    try:
        value = int(text.split('=', 1)[1].split(',')[0].strip(), 0)
    except ValueError:
        return None
    return value / float(0xffffffff)


def state_of_opacity(opacity):
    if opacity is None:
        return UNKNOWN
    if opacity >= SHOWN_OPACITY:
        return SHOWN
    if opacity <= CLEAR_OPACITY:
        return CLEAR
    return PARTLY


def verdict(shots, done, errors, report_only=False):
    """The exit status from the shots ((name, expected, state, detail) in
    the order taken), whether the script said DONE and its ERROR lines."""
    log('--- the windows (expected, then seen)')
    states = {}
    for name, expected, state, detail in shots:
        states[name] = state
        log('%-12s %-6s %-8s %s' % (name, expected, state, detail))
    for line in errors:
        log('::error::the script: %s' % line)
    for name, expected in CONTROLS.items():
        if states.get(name) != expected:
            if name == 'seen':
                log('::error::the window opacity check never saw the window (%s)' % states.get(name, 'no picture'))
            else:
                log('::error::the window opacity check cannot tell a window\'s opacity: at blendLevel 99'
                    ' it is %s' % states.get(name, 'not looked at'))
            return 2
    if errors:
        return 2
    failed = [name for name, expected, state, _ in shots if name not in CONTROLS and state != expected]
    if not done:
        failed.append('(the script did not finish)')
    if failed:
        text = 'windows not at the opacity of their blendLevel: %s' % ', '.join(failed)
        if report_only:
            log('::warning::%s' % text)
            return 0
        log('::error::%s' % text)
        return 1
    log('Every window was at the opacity of its blendLevel.')
    return 0


# ---------------------------------------------------------------- looking

def look_mac(shots_dir, capture=vec.screencapture):
    """Takes the window's area from the screen: (state, detail, picture)."""
    def look(name, rect, window_id):
        area = vec.capture_rect(rect)
        states = []
        picture = None
        for i in range(PICTURES):
            if i:
                time.sleep(BETWEEN)
            path = os.path.join(shots_dir, '%s-%d.png' % (name, i + 1))
            state = UNKNOWN
            if capture(area, path):
                try:
                    with open(path, 'rb') as f:
                        state = state_of_share(colour_share(*vec.read_png(f.read())))
                    picture = path
                except (OSError, ValueError, zlib.error, struct.error) as e:
                    log('(%s: %s)' % (os.path.basename(path), e))
            states.append(state)
        return states[-1], 'pictures: %s' % ' '.join(states), picture
    return look


def look_linux(env):
    """Reads the window's _NET_WM_WINDOW_OPACITY with xprop."""
    def look(name, rect, window_id):
        try:
            proc = subprocess.run(['xprop', '-id', str(window_id), '_NET_WM_WINDOW_OPACITY'], env=env,
                                  stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=20)
            text = proc.stdout.decode('utf-8', 'replace').strip()
        except (OSError, subprocess.TimeoutExpired) as e:
            return UNKNOWN, 'xprop: %s' % e, None
        opacity = parse_xprop_opacity(text)
        return state_of_opacity(opacity), 'xprop: %s' % (text or '(nothing)'), None
    return look


# -------------------------------------------------------------------- run

def start_xvfb():
    """An Xvfb screen of its own: (process, display)."""
    read_fd, write_fd = os.pipe()
    proc = subprocess.Popen(['Xvfb', '-displayfd', str(write_fd), '-screen', '0', '1280x1024x24', '-nolisten', 'tcp'],
                            pass_fds=(write_fd,), stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    os.close(write_fd)
    number = b''
    started = time.time()
    while time.time() - started < 20:
        chunk = os.read(read_fd, 16)
        if not chunk:
            break
        number += chunk
        if number.endswith(b'\n'):
            break
    os.close(read_fd)
    number = number.strip().decode('ascii', 'replace')
    if not number.isdigit():
        proc.kill()
        return None, None
    return proc, ':' + number


def read_lines(path):
    """The lines of log.txt as lists of fields (a line cut short, read
    while the script writes it, is left out)."""
    return vec.read_marks(path)


def run(args, look=None, env=None):
    out = os.path.abspath(args.out)
    if os.path.isdir(out):
        shutil.rmtree(out)
    work = os.path.join(out, 'work')
    shots_dir = os.path.join(out, 'shots')
    for folder in (work, shots_dir):
        os.makedirs(folder)
    log_path = os.path.join(work, 'log.txt')

    env = dict(os.environ if env is None else env)
    env['OXT_WO_DIR'] = work
    xvfb = None
    if args.app:
        tools = os.path.join(out, 'tools')
        os.makedirs(tools)
        shutil.copyfile(SCRIPT, os.path.join(tools, 'Startup.rev'))
        env['REV_TOOLS_PATH'] = tools
        command = [args.engine or vec.app_engine(args.app)]
        cwd = tools
    else:
        command = [args.engine, SCRIPT]
        cwd = work
    if look is None:
        if sys.platform == 'darwin':
            look = look_mac(shots_dir)
        else:
            xvfb, display = start_xvfb()
            if xvfb is None:
                log('::error::Xvfb did not start')
                return 2
            env['DISPLAY'] = display
            log('Xvfb on %s' % display)
            look = look_linux(env)

    shots = []
    errors = []
    pictures = []
    done = False
    seen = 0
    status = 'did not finish in %d s' % args.timeout
    started = time.time()
    try:
        with open(os.path.join(out, 'engine-output.txt'), 'wb') as output:
            proc = subprocess.Popen(command, cwd=cwd, env=env, stdout=output, stderr=subprocess.STDOUT)
            try:
                while time.time() - started < args.timeout:
                    lines = read_lines(log_path)
                    # log.txt only grows (each line is appended), but a
                    # read may find a line half written: seen never goes back
                    for fields in lines[seen:]:
                        kind = fields[0]
                        if kind == 'SHOT' and len(fields) >= 5:
                            name, expected = fields[1], fields[2]
                            rect = vec.parse_rect(fields[3])
                            if rect is None:
                                state, detail, picture = UNKNOWN, 'no rect (%s)' % fields[3], None
                            else:
                                state, detail, picture = look(name, rect, fields[4])
                            shots.append((name, expected, state, '%s; window %s at %s' % (detail, fields[4], fields[3])))
                            if picture:
                                pictures.append((name, picture))
                            log('%6.1f s  %s: %s (expected %s)' % (time.time() - started, name, state, expected))
                            open(os.path.join(work, 'go-' + name), 'w').close()
                        elif kind == 'ERROR':
                            errors.append(' '.join(fields[1:]))
                        elif kind == 'DONE':
                            done = True
                        else:
                            log('%6.1f s  %s' % (time.time() - started, ' '.join(fields)))
                    seen = max(seen, len(lines))
                    if proc.poll() is not None:
                        status = 'ended with exit status %d after %.0f s' % (proc.returncode, time.time() - started)
                        # the lines it wrote last
                        for fields in read_lines(log_path)[seen:]:
                            if fields[0] == 'DONE':
                                done = True
                            elif fields[0] == 'ERROR':
                                errors.append(' '.join(fields[1:]))
                        break
                    time.sleep(0.1)
            finally:
                if proc.poll() is None:
                    proc.kill()
                    try:
                        proc.wait(timeout=30)
                    except subprocess.TimeoutExpired:
                        log('The engine did not end when killed')
    finally:
        if xvfb is not None:
            xvfb.kill()

    log('Engine: %s' % status)
    log('--- log.txt')
    for fields in read_lines(log_path):
        log('\t'.join(fields))
    log('--- the engine\'s output (first 3000 bytes)')
    with open(os.path.join(out, 'engine-output.txt'), 'rb') as f:
        log(f.read(3000).decode('utf-8', 'replace'))
    for name, path in pictures:
        vec.print_image('%s/%s.png' % (os.path.basename(out), name), path)
    return verdict(shots, done, errors, args.report_only)


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    ap.add_argument('--app', help='OXT-Beyond.app (a Mac)')
    ap.add_argument('--engine', help='the standalone engine (Linux), or the engine to run instead of the app\'s')
    ap.add_argument('--out', required=True, help='a folder for the run (emptied first)')
    ap.add_argument('--timeout', type=int, default=120, help='seconds for the whole run')
    ap.add_argument('--report-only', action='store_true',
                    help='report a fault found without failing (a release with a known fault)')
    args = ap.parse_args(argv)
    if not args.app and not args.engine:
        ap.error('--app or --engine is required')
    if sys.platform == 'darwin':
        if not args.app:
            ap.error('on a Mac the check runs the app (--app)')
    elif sys.platform.startswith('linux'):
        if args.app:
            ap.error('on Linux the check runs the standalone engine (--engine)')
        missing = [t for t in ('Xvfb', 'xprop') if shutil.which(t) is None]
        if missing:
            log('::error::the window opacity check needs %s' % ' and '.join(missing))
            return 2
    else:
        log('::error::the window opacity check runs on a Mac and on Linux')
        return 2
    return run(args)


if __name__ == '__main__':
    sys.exit(main())
