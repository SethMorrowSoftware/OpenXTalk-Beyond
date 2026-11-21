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

"""Check on Linux that a group grabbed from the mouseDown of a menu button
in it does not crash the engine when the mouse button comes up.

  python tools/ci/grab_menu_check.py --engine FILE [--log FILE] [--shots DIR]

The standalone engine runs tools/ci/grab-menu-check.livecodescript on an
Xvfb screen of its own, once for each menuMode (popup, option, pulldown).
This script presses the mouse on the menu button with the system's mouse
(xdotool), moves it, lets go, clicks beside the menu and presses Escape.
LiveCode Community 9.6.3 and OXT-Beyond up to 0.2.8-dp.2 crash at the
release (signal 11 in MCGroup::mup). Each run passes when the group got
its mouseDown and the engine is still running, and writing its lines,
three seconds after. A last run drags a plain button that grabs itself,
which must follow the mouse as it always did.

A run more is for "popup button" with the mouse over none of the program's
stacks (the script pops the menu up from a timer, three seconds after its
stack opened, with the mouse far from it): up to 0.2.8-dp.2 and in LiveCode
Community that was error 583 and no menu. It passes when there was no
error and a click on the menu's first item, at the mouse, arrived as
menuPick.

Needs Xvfb and xdotool (ImageMagick's import for the pictures). Exit status
0 when every check passed, 1 otherwise.
"""

import argparse
import os
import shutil
import subprocess
import sys
import tempfile
import time

HERE = os.path.dirname(os.path.abspath(__file__))
SCRIPT = os.path.join(HERE, 'grab-menu-check.livecodescript')
MODES = ('popup', 'option', 'pulldown')
# Where the script puts things, in pixels of the screen
MENU_BUTTON = (225, 165)
PLAIN_BUTTON = (225, 265)
BESIDE = (450, 380)
# Far from the stack's window (100,100 to 500,400)
FAR = (800, 600)


def log(msg=''):
    print(msg, flush=True)


def x(cmd, env):
    try:
        proc = subprocess.run(cmd, env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=60)
    except (OSError, subprocess.SubprocessError) as e:
        return 'error: %s' % e
    return proc.stdout.decode('utf-8', 'replace').strip()


def start_xvfb():
    """(process, display name) of a new Xvfb on a free display."""
    r, w = os.pipe()
    proc = subprocess.Popen(['Xvfb', '-displayfd', str(w), '-screen', '0', '1024x768x24', '-nolisten', 'tcp'],
                            pass_fds=(w,), stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    os.close(w)
    number = b''
    end = time.time() + 30
    while time.time() < end and not number.endswith(b'\n'):
        chunk = os.read(r, 16)
        if not chunk:
            break
        number += chunk
    os.close(r)
    if not number.strip().isdigit():
        proc.kill()
        raise RuntimeError('Xvfb did not start')
    return proc, ':' + number.strip().decode()


def read_lines(path):
    try:
        with open(path, encoding='utf-8', errors='replace') as f:
            return f.read().splitlines()
    except OSError:
        return []


def wait_for(path, line, engine, seconds=60):
    end = time.time() + seconds
    while time.time() < end:
        if line in read_lines(path):
            return True
        if engine.poll() is not None:
            break
        time.sleep(0.3)
    return line in read_lines(path)


def verdict(lines_before, lines_after, exit_code, mode):
    """The checks of one menu run, as (ok, what, detail): from the script's
    lines when the mouse had been released, its lines three seconds later,
    and the engine's exit code then (None while it runs)."""
    name = 'grab from a %s menu button' % mode
    results = [('GROUP mouseDown' in lines_after, '%s: the group got mouseDown' % name,
                'no GROUP mouseDown line; the press did not reach the menu button')]
    alive_after = len([l for l in lines_after if l.startswith('ALIVE')]) \
        - len([l for l in lines_before if l.startswith('ALIVE')])
    if exit_code is not None:
        results.append((False, '%s: the engine runs on after the release' % name,
                        'the engine ended with exit code %s' % exit_code))
    else:
        results.append((alive_after >= 2, '%s: the engine runs on after the release' % name,
                        '%d lines in three seconds; the engine has stopped answering' % alive_after))
    return results


def drag_verdict(lines):
    """The checks of the plain button's drag."""
    places = [l[len('ALIVE '):] for l in lines if l.startswith('ALIVE ')]
    moved = len(set(places)) > 1
    return [('PLAIN mouseDown' in lines, 'grab of a plain button: it got mouseDown', 'no PLAIN mouseDown line'),
            (moved, 'grab of a plain button: it follows the mouse',
             'its loc stayed at %s' % (places[-1] if places else '(no lines)'))]


def popup_verdict(lines, exit_code):
    """The checks of the popup with no mouse stack."""
    name = 'popup button with the mouse over no stack'
    errors = [l for l in lines if l.startswith('POPUP ERROR')]
    return [('MOUSESTACK []' in lines, '%s: the mouse was over no stack' % name,
             'no "MOUSESTACK []" line; the check did not test what it is for'),
            ('POPUP opening' in lines and not errors, '%s: no error' % name,
             errors[0] if errors else 'the script did not reach the popup'),
            ('PICK One' in lines, '%s: the menu opened at the mouse and its pick arrived' % name,
             'no "PICK One" line'),
            (exit_code is None, '%s: the engine runs on' % name, 'the engine ended with exit code %s' % exit_code)]


def with_lines(results, lines, run):
    """The results, and when one failed, one more that is not a check: the
    lines the script wrote, which say how far the run got. The ALIVE lines
    are counted, not listed, but for the first and last."""
    if all(ok for ok, _, _ in results):
        return results
    alive = [l for l in lines if l.startswith('ALIVE')]
    kept = []
    last = None
    for l in lines:
        if l.startswith('ALIVE'):
            if l == last:
                continue
            last = l
        kept.append(l)
    return results + [(None, '%s: the script wrote (%d ALIVE lines)' % (run, len(alive)), ' | '.join(kept) or '(nothing)')]


def run_popup(engine_path, shots):
    work = tempfile.mkdtemp(prefix='oxt-grab-menu-')
    log_path = os.path.join(work, 'log.txt')
    xvfb = engine = None
    try:
        xvfb, display = start_xvfb()
        env = dict(os.environ, DISPLAY=display, OXT_GRAB_MENU_LOG=log_path, OXT_GRAB_MENU_MODE='nomouse')
        engine = subprocess.Popen([engine_path, SCRIPT], env=env, cwd=work,
                                  stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        if not wait_for(log_path, 'READY', engine):
            return [(False, 'nomouse: the stack opened', 'no READY line (engine exit code %s)' % engine.poll())]
        # away from the stack, well before its timer pops the menu up, and
        # it stays there. (Moved before the engine had started, on a new
        # Xvfb, the mouse stayed in the middle of the screen: the menu then
        # opened there, and the click here missed it.)
        where = ''
        for _ in range(10):
            x(['xdotool', 'mousemove', str(FAR[0]), str(FAR[1])], env)
            where = x(['xdotool', 'getmouselocation'], env)
            if where.startswith('x:%d y:%d ' % FAR):
                break
            time.sleep(0.1)
        else:
            return [(False, 'nomouse: the mouse moved away from the stack', where)]
        wait_for(log_path, 'POPUP opening', engine, 20)
        time.sleep(1.5)
        if shots:
            x(['import', '-window', 'root', os.path.join(shots, 'grab-menu-nomouse.png')], env)
        windows = x(['xwininfo', '-root', '-tree'], env) if shutil.which('xwininfo') else ''
        # the menu's top left is at the mouse; its first item is just
        # inside. As a hand does it: the mouse moves there, and the button
        # is down for a moment.
        for step in range(1, 8):
            x(['xdotool', 'mousemove', str(FAR[0] + 2 * step), str(FAR[1] + 2 * step - (2 if step == 7 else 0))], env)
            time.sleep(0.05)
        time.sleep(0.4)
        x(['xdotool', 'mousedown', '1'], env)
        time.sleep(0.15)
        x(['xdotool', 'mouseup', '1'], env)
        time.sleep(2)
        lines = read_lines(log_path)
        results = with_lines(popup_verdict(lines, engine.poll()), lines, 'nomouse')
        if not all(ok for ok, _, _ in results if ok is not None):
            # what the screen held when the menu was open, and what a
            # second click, on the second item, does: for the next reader
            kept = [' '.join(l.split()) for l in windows.splitlines() if '+' in l and 'x' in l]
            results.append((None, 'nomouse: the windows with the menu open', ' | '.join(kept)[:1200] or '(no xwininfo)'))
            results.append((None, 'nomouse: the mouse', x(['xdotool', 'getmouselocation'], env)))
            x(['xdotool', 'mousemove', str(FAR[0] + 16), str(FAR[1] + 34)], env)
            time.sleep(0.4)
            x(['xdotool', 'mousedown', '1'], env)
            time.sleep(0.15)
            x(['xdotool', 'mouseup', '1'], env)
            time.sleep(1.5)
            more = read_lines(log_path)[len(lines):]
            results.append((None, 'nomouse: after a second click, on the second item', ' | '.join(more)[:600]))
        return results
    except RuntimeError as e:
        return [(False, 'nomouse: the run', str(e))]
    finally:
        for proc in (engine, xvfb):
            if proc is not None and proc.poll() is None:
                proc.kill()
                proc.wait()
        shutil.rmtree(work, ignore_errors=True)


def run_once(engine_path, mode, shots, drag=False):
    work = tempfile.mkdtemp(prefix='oxt-grab-menu-')
    log_path = os.path.join(work, 'log.txt')
    xvfb = engine = None
    results = []
    try:
        xvfb, display = start_xvfb()
        env = dict(os.environ, DISPLAY=display, OXT_GRAB_MENU_LOG=log_path, OXT_GRAB_MENU_MODE=mode)
        engine = subprocess.Popen([engine_path, SCRIPT], env=env, cwd=work,
                                  stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        if not wait_for(log_path, 'READY', engine):
            return [(False, '%s: the stack opened' % mode, 'no READY line (engine exit code %s)' % engine.poll())]
        time.sleep(1.5)
        at = PLAIN_BUTTON if drag else MENU_BUTTON
        x(['xdotool', 'mousemove', str(at[0]), str(at[1])], env)
        time.sleep(0.3)
        x(['xdotool', 'mousedown', '1'], env)
        time.sleep(0.5)
        for dx, dy in ((35, 35), (75, 95)):
            x(['xdotool', 'mousemove', str(at[0] + dx), str(at[1] + dy)], env)
            time.sleep(0.6 if drag else 0.3)
        x(['xdotool', 'mouseup', '1'], env)
        time.sleep(0.5)
        before = read_lines(log_path)
        if not drag:
            x(['xdotool', 'mousemove', str(BESIDE[0]), str(BESIDE[1])], env)
            x(['xdotool', 'click', '1'], env)
            time.sleep(0.5)
            x(['xdotool', 'key', 'Escape'], env)
        time.sleep(3)
        if shots:
            x(['import', '-window', 'root', os.path.join(shots, 'grab-menu-%s.png' % ('drag' if drag else mode))], env)
        after = read_lines(log_path)
        results = with_lines(drag_verdict(after) if drag else verdict(before, after, engine.poll(), mode), after,
                             'drag' if drag else mode)
    except RuntimeError as e:
        results = [(False, '%s: the run' % mode, str(e))]
    finally:
        for proc in (engine, xvfb):
            if proc is not None and proc.poll() is None:
                proc.kill()
                proc.wait()
        shutil.rmtree(work, ignore_errors=True)
    return results


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    ap.add_argument('--engine', required=True, help='the standalone engine to run')
    ap.add_argument('--log', help='write the results to this file too')
    ap.add_argument('--shots', help='keep pictures of the screen in this folder')
    args = ap.parse_args(argv)

    if not sys.platform.startswith('linux'):
        log('The grab menu check is for Linux only')
        return 0
    missing = [t for t in ('Xvfb', 'xdotool') if shutil.which(t) is None]
    if missing:
        log('FAIL missing: %s' % ', '.join(missing))
        return 1
    if args.shots:
        os.makedirs(args.shots, exist_ok=True)
    engine = os.path.abspath(args.engine)

    results = []
    for mode in MODES:
        results.extend(run_once(engine, mode, args.shots))
    results.extend(run_once(engine, 'popup', args.shots, drag=True))
    results.extend(run_popup(engine, args.shots))

    notes = [r for r in results if r[0] is None]
    results = [r for r in results if r[0] is not None]
    lines = ['%s %s%s' % ('PASS' if ok else 'FAIL', what, (': ' + detail) if detail and not ok else '')
             for ok, what, detail in results]
    lines.extend('NOTE %s: %s' % (what, detail) for _, what, detail in notes)
    failed = [r for r in results if not r[0]]
    lines.append('%d of %d checks passed' % (len(results) - len(failed), len(results)))
    text = '\n'.join(lines)
    log(text)
    if args.log:
        os.makedirs(os.path.dirname(os.path.abspath(args.log)), exist_ok=True)
        with open(args.log, 'w', encoding='utf-8') as f:
            f.write(text + '\n')
    return 1 if failed else 0


if __name__ == '__main__':
    sys.exit(main())
