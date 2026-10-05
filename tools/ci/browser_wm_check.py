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

"""Check the Linux browser widget under real window managers: that it is
shown, and that it does not keep the keyboard.

  python tools/ci/browser_wm_check.py (--install DIR | --package FILE)
      [--wm xfwm4,openbox] [--log FILE] [--shots DIR]

A standalone of the layout (media_check.stage_runtime) runs
tools/ci/browser-wm-check.livecodescript on an Xvfb screen of its own
under each window manager in turn. The script opens a page of one colour
in a browser widget, and this script checks from outside:

  1. a browser in a new stack: the page is on the screen (its colour at
     the browser's middle); after the page loaded, typing into a field of
     the stack reaches the field; after a click into the browser, a click
     on the field gives the keys back to the field; the application got
     no suspend while the keyboard was in the browser;
  2. the stack closed and opened again: the page is on the screen;
  3. a second stack with a browser: the page is on the screen, and typing
     reaches its field.

Before OXT-Beyond 0.2.4 (pull request #57) the browser window was made
on the root window, so the window manager could take it and leave it
unmapped (openbox: an empty browser, from the second one on), and CEF
gave it the X input focus on each page load, which the engine did not
take back (xfwm4: the keys went to the browser, and the application
suspended).

Needs Xvfb, xdotool, xwininfo and ImageMagick's import, and the window
managers. Exit status 0 when every check passed, 1 otherwise. Only the
Python 3 standard library is used.
"""

import argparse
import base64
import functools
import http.server
import os
import re
import shutil
import subprocess
import sys
import tempfile
import threading
import time

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(os.path.dirname(HERE), 'oxt'))
sys.path.insert(0, HERE)
import package  # noqa: E402
import run_livecode_check as rlc  # noqa: E402
import media_check  # noqa: E402

SCRIPT = os.path.join(HERE, 'browser-wm-check.livecodescript')
COLOUR = (255, 0, 255)
PAGE = """<!DOCTYPE html>
<html><head><meta charset="utf-8"><title>OXT window manager check</title></head>
<body style="margin:0;background:#ff00ff"></body></html>
"""
WMS = {
    'xfwm4': ['xfwm4', '--compositor=off', '--replace'],
    'openbox': ['openbox', '--replace'],
}
# Where the script puts the browser and the field in a card
BROWSER_MIDDLE = (205, 175)
BROWSER_INSIDE = (100, 100)
FIELD_MIDDLE = (450, 35)


def gha():
    return bool(os.environ.get('GITHUB_ACTIONS'))


class _QuietHandler(http.server.SimpleHTTPRequestHandler):
    def log_message(self, *args):
        pass


def x(cmd, env, check=False):
    proc = subprocess.run(cmd, env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=60)
    if check and proc.returncode != 0:
        raise rlc.CheckError('%s: %s' % (' '.join(cmd), proc.stderr.decode('utf-8', 'replace').strip()))
    return proc.stdout.decode('utf-8', 'replace')


def card_origin(name, env):
    """The screen position of the card of the stack titled name."""
    ids = x(['xdotool', 'search', '--onlyvisible', '--name', '^%s$' % name], env).split()
    if not ids:
        raise rlc.CheckError('no window %s on the screen' % name)
    info = x(['xwininfo', '-id', ids[0]], env, check=True)
    left = int(re.search(r'Absolute upper-left X:\s+(-?\d+)', info).group(1))
    top = int(re.search(r'Absolute upper-left Y:\s+(-?\d+)', info).group(1))
    return left, top


def pixel(at, env):
    out = x(['import', '-window', 'root', '-crop', '1x1+%d+%d' % at, '-depth', '8', 'txt:-'], env, check=True)
    m = re.search(r'\((\d+),(\d+),(\d+)', out.splitlines()[-1])
    return tuple(int(v) for v in m.groups()) if m else None


def close_to(a, b):
    return a is not None and all(abs(p - q) <= 24 for p, q in zip(a, b))


def click(at, env):
    x(['xdotool', 'mousemove', str(at[0]), str(at[1])], env)
    time.sleep(0.3)
    x(['xdotool', 'click', '1'], env)
    time.sleep(0.7)


def type_text(text, env):
    x(['xdotool', 'type', '--delay', '60', text], env)
    time.sleep(0.8)


class Run(object):
    """The engine under one window manager."""

    def __init__(self, wm, engine, work, url, extensions, shots):
        self.wm, self.engine, self.work, self.url, self.extensions = wm, engine, work, url, extensions
        self.shots = shots
        self.lines, self.problems, self.procs = [], [], []
        self.engine_proc = None
        self.dir = os.path.join(work, 'wm-' + wm)
        os.makedirs(self.dir)
        self.log = os.path.join(self.dir, 'log.txt')

    def check(self, name, ok, detail=''):
        line = '%s %s: %s%s' % ('PASS' if ok else 'FAIL', self.wm, name, (' (%s)' % detail) if detail else '')
        self.lines.append(line)
        if not ok:
            self.problems.append(line[5:])

    def script_lines(self):
        if not os.path.exists(self.log):
            return []
        with open(self.log, encoding='utf-8', errors='replace') as f:
            return [v.rstrip('\r\n') for v in f if v.strip()]

    def wait_line(self, prefix, seconds=90):
        end = time.time() + seconds
        while time.time() < end:
            for v in self.script_lines():
                if v.startswith(prefix):
                    return v
            if self.engine_proc.poll() is not None:
                return None
            time.sleep(0.2)
        return None

    def go(self, step):
        open(os.path.join(self.dir, 'go-%d' % step), 'w').close()

    def shot(self, name):
        if not self.shots:
            return
        path = os.path.join(self.shots, '%s-%s.png' % (self.wm, name))
        subprocess.run(['import', '-window', 'root', path], env=self.env, timeout=60)

    def browser_shown(self, stack, what):
        left, top = card_origin(stack, self.env)
        colour = pixel((left + BROWSER_MIDDLE[0], top + BROWSER_MIDDLE[1]), self.env)
        self.check('%s: the page is on the screen' % what, close_to(colour, COLOUR), 'colour %s' % (colour,))
        return left, top

    def typing(self, stack, left, top, text, what):
        click((left + FIELD_MIDDLE[0], top + FIELD_MIDDLE[1]), self.env)
        type_text(text, self.env)

    def run(self):
        display = None
        for n in range(91, 120):
            if not os.path.exists('/tmp/.X%d-lock' % n):
                display = ':%d' % n
                break
        self.env = dict(os.environ, DISPLAY=display, OXT_WM_DIR=self.dir, OXT_WM_URL=self.url,
                        OXT_WM_EXTENSIONS=self.extensions)
        try:
            self.procs.append(subprocess.Popen(['Xvfb', display, '-screen', '0', '1600x1000x24', '-nolisten', 'tcp'],
                                               stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL))
            time.sleep(1.5)
            self.procs.append(subprocess.Popen(WMS[self.wm], env=self.env, stdout=subprocess.DEVNULL,
                                               stderr=subprocess.DEVNULL))
            time.sleep(2)
            self.engine_proc = subprocess.Popen([self.engine, SCRIPT], cwd=self.dir, env=self.env,
                                                stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
            self.procs.append(self.engine_proc)

            # 1
            if not self.wait_line('READY 1'):
                raise rlc.CheckError('the first stack did not get ready')
            self.shot('1-loaded')
            left, top = self.browser_shown('WMCheckA', 'a new stack')
            self.typing('WMCheckA', left, top, 'abc', 'after the page loaded')
            click((left + BROWSER_INSIDE[0], top + BROWSER_INSIDE[1]), self.env)
            self.shot('1-browser-clicked')
            self.typing('WMCheckA', left, top, 'def', 'after a click into the browser')
            self.shot('1-typed')
            self.go(1)
            field = self.wait_line('FIELD 1')
            text = field[len('FIELD 1'):].strip() if field else None
            self.check('a new stack: typing reaches its field after the page loaded', text is not None and
                       text.startswith('abc'), 'the field has %r' % text)
            self.check('a new stack: clicking the field after the browser takes the keys back', text == 'abcdef',
                       'the field has %r' % text)

            # 2
            if not self.wait_line('READY 2'):
                raise rlc.CheckError('the stack opened again did not get ready')
            self.shot('2-reopened')
            self.browser_shown('WMCheckA', 'the stack closed and opened again')
            self.go(2)

            # 3
            if not self.wait_line('READY 3'):
                raise rlc.CheckError('the second stack did not get ready')
            self.shot('3-second')
            left, top = self.browser_shown('WMCheckB', 'a second stack')
            self.typing('WMCheckB', left, top, 'ghi', 'in the second stack')
            self.go(3)
            field = self.wait_line('FIELD 3')
            text = field[len('FIELD 3'):].strip() if field else None
            self.check('a second stack: typing reaches its field', text == 'ghi', 'the field has %r' % text)
            self.wait_line('DONE', 30)
        except (rlc.CheckError, OSError, subprocess.SubprocessError) as e:
            self.problems.append('%s: %s' % (self.wm, e))
            self.shot('error')
        finally:
            for p in reversed(self.procs):
                if p.poll() is None:
                    p.terminate()
                    try:
                        p.wait(10)
                    except subprocess.TimeoutExpired:
                        p.kill()
        lines = self.script_lines()
        suspends = [v for v in lines if v.startswith('EVENT suspend')]
        self.check('no suspend while the keyboard was in the browser', not suspends, '; '.join(suspends))
        for v in lines:
            if v.startswith('ERROR') or v.startswith('INFO'):
                self.lines.append('%s %s: %s' % (v.split(' ', 1)[0], self.wm, v.split(' ', 1)[-1]))
                if v.startswith('ERROR'):
                    self.problems.append('%s: %s' % (self.wm, v[6:]))
        if not any(v.startswith('DONE') for v in lines):
            self.problems.append('%s: the engine did not finish' % self.wm)
            out = b''
            if self.engine_proc and self.engine_proc.stdout:
                out = self.engine_proc.stdout.read()
            for v in out.decode('utf-8', 'replace').splitlines()[-30:]:
                rlc.log('  ' + v)


def main(argv=None):
    ap = argparse.ArgumentParser(description='Check the Linux browser widget under window managers.')
    ap.add_argument('--install', metavar='DIR', help='installed layout')
    ap.add_argument('--package', metavar='FILE', help='a package to extract and check like --install')
    ap.add_argument('--platform', default='linux-x86_64', choices=list(package.PLATFORMS))
    ap.add_argument('--wm', default='xfwm4,openbox', help='comma-separated window managers (default: %(default)s)')
    ap.add_argument('--log', metavar='FILE', help='write the results here too')
    ap.add_argument('--shots', metavar='DIR', help='write screenshots here')
    args = ap.parse_args(argv)
    if bool(args.install) == bool(args.package):
        ap.error('pass --install or --package')
    p = package.PLATFORMS[args.platform]
    lines, problems, temp_dirs, server = [], [], [], None
    try:
        for tool in ('Xvfb', 'xdotool', 'xwininfo', 'import'):
            if not shutil.which(tool):
                raise rlc.CheckError('%s is not installed' % tool)
        base = os.environ.get('RUNNER_TEMP') or tempfile.gettempdir()
        work = tempfile.mkdtemp(prefix='oxt-wm-', dir=base)
        temp_dirs.append(work)
        args.bin_dir, args.engine = None, None
        lay = rlc.find_layout(args, p, temp_dirs)
        engine, _ = media_check.stage_runtime(lay.tools, p, work)
        rlc.log('Engine  : %s' % engine)
        site = os.path.join(work, 'site')
        os.makedirs(site)
        with open(os.path.join(site, 'index.html'), 'w', encoding='utf-8', newline='\n') as f:
            f.write(PAGE)
        handler = functools.partial(_QuietHandler, directory=site)
        server = http.server.ThreadingHTTPServer(('127.0.0.1', 0), handler)
        threading.Thread(target=server.serve_forever, daemon=True).start()
        url = 'http://127.0.0.1:%d/index.html' % server.server_address[1]
        if args.shots:
            os.makedirs(args.shots, exist_ok=True)
        for wm in [w.strip() for w in args.wm.split(',') if w.strip()]:
            if wm not in WMS or not shutil.which(WMS[wm][0]):
                problems.append('%s: the window manager is not installed' % wm)
                continue
            rlc.log('Window manager: %s' % wm)
            r = Run(wm, engine, work, url, os.path.join(lay.tools, 'Extensions'), args.shots)
            r.run()
            lines += r.lines
            problems += r.problems
    except (rlc.CheckError, OSError) as e:
        problems.append(str(e))
    finally:
        if server:
            server.shutdown()
        for d in temp_dirs:
            shutil.rmtree(d, ignore_errors=True)

    if args.shots and gha() and os.path.isdir(args.shots) and problems:
        rlc.log('::group::Screenshots (base64 PNG)')
        for name in sorted(os.listdir(args.shots)):
            with open(os.path.join(args.shots, name), 'rb') as f:
                rlc.log('%s %s' % (name, base64.b64encode(f.read()).decode('ascii')))
        rlc.log('::endgroup::')
    rlc.log('')
    for v in lines:
        rlc.log(v)
    for msg in problems:
        rlc.log('::error title=Browser window manager check::%s' % msg if gha() else 'error: %s' % msg)
    result = 'passed' if not problems else 'FAILED (%d problems)' % len(problems)
    rlc.log('Browser window manager check %s.' % result)
    rlc._append('GITHUB_STEP_SUMMARY', '### Browser window manager check (%s)\n\n%s\n\nResult: **%s**\n\n'
                % (p.name, '\n'.join('- ' + v for v in lines), result))
    if args.log:
        with open(args.log, 'w', encoding='utf-8', newline='\n') as f:
            f.write('\n'.join(lines + problems + [result]) + '\n')
    return 1 if problems else 0


if __name__ == '__main__':
    sys.exit(main())
