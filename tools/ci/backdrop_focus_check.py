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

"""Check on Linux that the keyboard is not lost in the backdrop: with the
backdrop shown, keys typed after a palette closed, and after a click into
the backdrop, reach a field of the stack in front.

  python tools/ci/backdrop_focus_check.py --engine FILE
      [--wm xfwm4,openbox,mutter] [--log FILE] [--shots DIR]

The standalone engine runs tools/ci/backdrop-focus-check.livecodescript on
an Xvfb screen of its own under each window manager in turn, with the
backdrop shown and, for comparison, without it. The script opens a stack
with a field that has the keyboard and a palette over it; this script
clicks into the palette (the palette then has the keyboard, as the IDE's
Message Box has it), the script closes the palette (as Ctrl+M closes the
Message Box), and this script types: the keys must reach the field. With
the backdrop shown it then clicks into the backdrop and types again: the
keys reach the field, and the click still sends mouseDownInBackdrop.

Up to 0.2.8-dp.1 a window manager that gives the keyboard to the window
the closed one was transient for (Mutter, GNOME's, the window manager of
Ubuntu's Wayland session too) gave it to the backdrop, for every stack's
window is transient for the backdrop while it shows: the keys went
nowhere and the dock showed no application active until a click on a
stack (reported on the forum for Ubuntu 26.04, Wayland, by bwmilby). The
check also says which window has the keyboard after the palette closed;
under Mutter that is one of the stack's windows, not the backdrop.

Needs Xvfb, xdotool and the window managers (ImageMagick's import for the
pictures). Exit status 0 when every check passed, 1 otherwise. Only the
Python 3 standard library is used.
"""

import argparse
import os
import shutil
import subprocess
import sys
import tempfile
import time

HERE = os.path.dirname(os.path.abspath(__file__))
SCRIPT = os.path.join(HERE, 'backdrop-focus-check.livecodescript')
WMS = {
    'xfwm4': ['xfwm4', '--compositor=off', '--replace'],
    'openbox': ['openbox', '--replace'],
    'mutter': ['mutter', '--x11', '--replace', '--sm-disable'],
}
# The window managers under which the keyboard itself must leave the
# backdrop (the others are only reported on): the one of the report
FOCUS_MUST_MOVE = ('mutter',)
BACKDROP = 'gray'
# Where the script puts the windows, in pixels of the screen
PALETTE_MIDDLE = (700, 200)
BACKDROP_SPOT = (1300, 850)
TYPED_AFTER_CLOSE = 'abc'
TYPED_AFTER_CLICK = 'def'


def log(msg=''):
    print(msg, flush=True)


def x(cmd, env):
    try:
        proc = subprocess.run(cmd, env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=60)
    except (OSError, subprocess.SubprocessError) as e:
        return 'error: %s' % e
    return proc.stdout.decode('utf-8', 'replace').strip()


def focus_window(env):
    """(X window id, its name) of the window with the X input focus."""
    window = x(['xdotool', 'getwindowfocus'], env)
    if not window.isdigit():
        return window, ''
    return window, x(['xdotool', 'getwindowname', window], env)


def keyboard_in_stack(name):
    """Is a window named name one of the check's stacks (BFMain, whose title
    the engine may mark with an asterisk, or BFPalette)?"""
    return name.rstrip(' *') in ('BFMain', 'BFPalette')


def parse(lines):
    """The script's FIELD n lines, EVENT lines and ERROR lines."""
    fields, events, errors = {}, [], []
    for line in lines:
        if line.startswith('FIELD '):
            parts = line.split(' ', 2)
            fields[parts[1]] = parts[2] if len(parts) > 2 else ''
        elif line.startswith('EVENT '):
            events.append(line[len('EVENT '):])
        elif line.startswith('ERROR '):
            errors.append(line[len('ERROR '):])
    return fields, events, errors


class Run:
    def __init__(self, engine, wm, backdrop, shots):
        self.engine, self.wm, self.backdrop, self.shots = engine, wm, backdrop, shots
        self.name = '%s, %s' % (wm, 'backdrop shown' if backdrop else 'no backdrop')
        self.dir = tempfile.mkdtemp(prefix='oxt-backdrop-focus-')
        self.procs = []
        self.env = None
        self.results = []

    def check(self, what, ok, detail=''):
        self.results.append((ok, '%s: %s' % (self.name, what), detail))

    def lines(self):
        try:
            with open(os.path.join(self.dir, 'log.txt'), encoding='utf-8', errors='replace') as f:
                return f.read().splitlines()
        except OSError:
            return []

    def wait_line(self, line, seconds=60):
        end = time.time() + seconds
        while time.time() < end:
            if line in self.lines():
                return True
            if self.procs and self.procs[-1].poll() is not None:
                return line in self.lines()
            time.sleep(0.3)
        return False

    def go(self, step):
        open(os.path.join(self.dir, 'go-%d' % step), 'w').close()

    def shot(self, label):
        if self.shots:
            name = '%s-%s-%s.png' % (self.wm, 'backdrop' if self.backdrop else 'none', label)
            x(['import', '-window', 'root', os.path.join(self.shots, name)], self.env)

    def click(self, at):
        x(['xdotool', 'mousemove', str(at[0]), str(at[1])], self.env)
        time.sleep(0.3)
        x(['xdotool', 'click', '1'], self.env)
        time.sleep(1)

    def type_text(self, text):
        x(['xdotool', 'type', '--delay', '80', text], self.env)
        time.sleep(1)

    def run(self):
        display = None
        for n in range(91, 140):
            if not os.path.exists('/tmp/.X%d-lock' % n):
                display = ':%d' % n
                break
        self.env = dict(os.environ, DISPLAY=display, OXT_BF_DIR=self.dir, OXT_BF_BACKDROP=self.backdrop)
        self.env.pop('GDK_SCALE', None)
        try:
            self.procs.append(subprocess.Popen(['Xvfb', display, '-screen', '0', '1600x1000x24', '-nolisten', 'tcp'],
                                               stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL))
            time.sleep(1.5)
            self.procs.append(subprocess.Popen(WMS[self.wm], env=self.env, stdout=subprocess.DEVNULL,
                                               stderr=subprocess.DEVNULL))
            time.sleep(3)
            output = open(os.path.join(self.dir, 'engine-output.txt'), 'w')
            self.procs.append(subprocess.Popen([self.engine, SCRIPT], cwd=self.dir, env=self.env,
                                               stdout=output, stderr=subprocess.STDOUT))

            # 1: the palette gets the keyboard
            if not self.wait_line('READY 1'):
                self.check('the stacks opened', False, 'the script said: %r' % self.lines())
                return
            time.sleep(1)
            self.click(PALETTE_MIDDLE)
            window, name = focus_window(self.env)
            log('  %s: the keyboard is in %s %r after the click into the palette' % (self.name, window, name))
            self.shot('1-palette')
            self.go(1)

            # 2: the palette closed
            if not self.wait_line('READY 2'):
                self.check('the palette closed', False, 'the script said: %r' % self.lines())
                return
            time.sleep(1.5)
            window, name = focus_window(self.env)
            log('  %s: the keyboard is in %s %r after the palette closed' % (self.name, window, name))
            if self.backdrop and self.wm in FOCUS_MUST_MOVE:
                self.check('the keyboard is in a stack after the palette closed, not in the backdrop',
                           keyboard_in_stack(name), 'it is in %s %r' % (window, name))
            self.type_text(TYPED_AFTER_CLOSE)
            self.shot('2-closed')
            self.go(2)

            # 3: a click into the backdrop
            if not self.wait_line('READY 3'):
                self.check('the field was emptied', False, 'the script said: %r' % self.lines())
                return
            if self.backdrop:
                time.sleep(1)
                self.click(BACKDROP_SPOT)
                window, name = focus_window(self.env)
                log('  %s: the keyboard is in %s %r after the click into the backdrop' % (self.name, window, name))
                self.type_text(TYPED_AFTER_CLICK)
                self.shot('3-backdrop-clicked')
            self.go(3)
            self.wait_line('DONE', 30)
        finally:
            for p in reversed(self.procs):
                if p.poll() is None:
                    p.terminate()
                    try:
                        p.wait(10)
                    except subprocess.TimeoutExpired:
                        p.kill()

        fields, events, errors = parse(self.lines())
        self.check('the script ran to its end', 'DONE' in self.lines() and not errors,
                   'errors %r, lines %r' % (errors, self.lines()))
        self.check('keys typed after the palette closed reach the stack\'s field',
                   fields.get('2') == TYPED_AFTER_CLOSE, 'the field has %r' % fields.get('2'))
        if self.backdrop:
            self.check('keys typed after a click into the backdrop reach the stack\'s field',
                       fields.get('3') == TYPED_AFTER_CLICK, 'the field has %r' % fields.get('3'))
            self.check('a click into the backdrop still sends mouseDownInBackdrop',
                       'mouseDownInBackdrop 1' in events, 'events %r' % events)

    def cleanup(self):
        shutil.rmtree(self.dir, ignore_errors=True)


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    ap.add_argument('--engine', required=True, help='the standalone engine to run')
    ap.add_argument('--wm', default='xfwm4,openbox,mutter', help='the window managers, comma-separated')
    ap.add_argument('--log', help='write the results to this file too')
    ap.add_argument('--shots', help='keep pictures of the screen in this folder')
    args = ap.parse_args(argv)

    if not sys.platform.startswith('linux'):
        log('The backdrop focus check is for Linux only')
        return 0
    engine = os.path.abspath(args.engine)
    if args.shots:
        os.makedirs(args.shots, exist_ok=True)
    missing = [t for t in ('Xvfb', 'xdotool') if shutil.which(t) is None]
    wms = [w.strip() for w in args.wm.split(',') if w.strip()]
    missing += [w for w in wms if w not in WMS or shutil.which(WMS[w][0]) is None]
    if missing:
        log('FAIL missing: %s' % ', '.join(missing))
        return 1

    results = []
    for wm in wms:
        for backdrop in (BACKDROP, ''):
            run = Run(engine, wm, backdrop, args.shots)
            log('%s:' % run.name)
            try:
                run.run()
            finally:
                run.cleanup()
            results.extend(run.results)

    lines = ['%s %s%s' % ('PASS' if ok else 'FAIL', what, (': ' + detail) if detail and not ok else '')
             for ok, what, detail in results]
    failed = [r for r in results if not r[0]]
    lines.append('%d of %d checks passed' % (len(results) - len(failed), len(results)))
    text = '\n'.join(lines)
    log(text)
    if args.log:
        with open(args.log, 'w', encoding='utf-8') as f:
            f.write(text + '\n')
    return 1 if failed else 0


if __name__ == '__main__':
    sys.exit(main())
