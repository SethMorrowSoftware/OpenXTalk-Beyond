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

"""Does the Mac IDE still answer after a menu of its menu bar is opened and
the backdrop is clicked? The forum's report on 0.2.7-rc.6.4 (tperry2x,
macOS Sonoma on Apple silicon): "If you click the menu, then click the
actual backdrop, seems to be a program freeze (loop?)", the menu's title
left selected, the Menubar palette gone and nothing else drawn.

  python3 tools/ci/mac_menu_backdrop.py --install DIR --out DIR
      [--menu Text] [--launch exec|open]

Starts the installed IDE (--launch exec runs its binary, as the IDE tour
does; --launch open starts it with open, as the Finder does, so that macOS
takes the app for itself and not for the runner, as on a user's Mac) with
tools/ci/mac-menu-backdrop.livecodescript, which turns the backdrop on,
writes a beat every 250 ms that stops while the engine does not answer,
and logs the messages of the menus, the backdrop and the windows' focus.
Then it clicks with real mouse events (CGEventPost through osascript's
JavaScript, as the IDE tour posts its mouse moves; the menu's title is
found with System Events), each step followed by a look at the beat:

  menu-close     the menu's title, then the title again (the menu closes)
  backdrop       the backdrop alone
  menu-backdrop  the menu's title, then the backdrop (the report), twice
  menu-desktop   the backdrop off, the menu's title, then the desktop

A step after which the beat stops for 8 s is a stop: the screen is taken,
the engine is sampled (its main thread's call graph into the log, named
from the build's dSYMs under $OXT_DSYM_DIR), then Escape is pressed and
the title clicked again to see whether either brings it back, and no more
steps run. Every screenshot is printed into the log as tools/ci/print_images.py
reads it. Exit status 0 when the IDE answered after every step, 1 when it
stopped, 2 when the check itself could not run. Only the Python 3
standard library is used.
"""

import argparse
import os
import shutil
import subprocess
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(os.path.dirname(HERE), 'oxt'))
sys.path.insert(0, HERE)
import package  # noqa: E402
import run_livecode_check as rlc  # noqa: E402
import ui_tour  # noqa: E402

SCRIPT = os.path.join(HERE, 'mac-menu-backdrop.livecodescript')
DOCUMENT = 'oxt_menu_backdrop.livecodescript'

# How long without a beat is a stop, and how long a step's look lasts
STOPPED_AFTER = 8.0
LOOK = 10.0

log = ui_tour.log


def osascript(text, language=None, timeout=30):
    """Runs text with osascript: (exit status, what it printed)."""
    cmd = ['osascript'] + (['-l', language] if language else []) + ['-e', text]
    try:
        proc = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=timeout)
    except subprocess.TimeoutExpired:
        return -1, 'no answer in %d s' % timeout
    return proc.returncode, proc.stdout.decode('utf-8', 'replace').strip()


POST = '''ObjC.import("CoreGraphics");
function post(type, x, y, clicks) {
  var e = $.CGEventCreateMouseEvent(null, type, {x: x, y: y}, 0);
  if (clicks) $.CGEventSetIntegerValueField(e, 1, clicks);
  $.CGEventPost(0, e);
}
'''


def click(x, y):
    """A click of the left button at x, y on the screen: the pointer moved
    there, then the button down and up."""
    code, said = osascript(POST + 'post(5, %d, %d, 0); delay(0.2); post(1, %d, %d, 1); delay(0.1); '
                           'post(2, %d, %d, 1);' % (x, y, x, y, x, y), 'JavaScript')
    log('%.3f click at %d,%d%s' % (time.time(), x, y, '' if code == 0 and not said else ' (%s: %s)' % (code, said)))


def key(code_, flags=0):
    """A key pressed and released (a virtual key code, with modifier flags)."""
    code, said = osascript('ObjC.import("CoreGraphics");'
                           'var d = $.CGEventCreateKeyboardEvent(null, %d, true);'
                           'var u = $.CGEventCreateKeyboardEvent(null, %d, false);'
                           '$.CGEventSetFlags(d, %d); $.CGEventSetFlags(u, %d);'
                           '$.CGEventPost(0, d); delay(0.05); $.CGEventPost(0, u);'
                           % (code_, code_, flags, flags), 'JavaScript')
    log('%.3f key %d (flags %#x)%s' % (time.time(), code_, flags, '' if code == 0 and not said else
                                         ' (%s: %s)' % (code, said)))


# Virtual key codes and the Control key's flag (kCGEventFlagMaskControl)
ESCAPE, F2, RIGHT, DOWN = 53, 120, 124, 125
CONTROL = 0x40000

# The IDE's menus in its menu bar, after the application menu
# (revMenubarMenus in ide/Toolset/palettes/menubar/revmenubar.livecodescript)
IDE_MENUS = ['File', 'Edit', 'Tools', 'Object', 'Text', 'Development', 'View', 'Window', 'Help']


def menu_title(pid, menu):
    """The middle of the menu bar title menu of the process pid, as System
    Events finds it, or None."""
    code, said = osascript(
        'tell application "System Events"\n'
        '  set p to first application process whose unix id is %d\n'
        '  set i to menu bar item "%s" of menu bar 1 of p\n'
        '  set {x, y} to position of i\n'
        '  set {w, h} to size of i\n'
        '  return (x as text) & "," & (y as text) & "," & (w as text) & "," & (h as text)\n'
        'end tell' % (pid, menu))
    log('System Events: the menu bar item %s: %s%s' % (menu, said, '' if code == 0 else ' (exit status %s)' % code))
    try:
        x, y, w, h = [int(float(v)) for v in said.split(',')]
    except ValueError:
        return None
    return x + w // 2, y + h // 2


def menu_bar_titles(pid):
    code, said = osascript(
        'tell application "System Events" to get name of every menu bar item of menu bar 1 of '
        '(first application process whose unix id is %d)' % pid)
    log('System Events: the menu bar: %s%s' % (said, '' if code == 0 else ' (exit status %s)' % code))


def read_beat(out):
    """(when the beat was written, the line) or (None, '')."""
    path = os.path.join(out, 'beat.txt')
    try:
        with open(path, encoding='utf-8', errors='replace') as f:
            line = f.read().strip()
    except OSError:
        return None, ''
    try:
        return int(line.split('\t')[0]) / 1000.0, line
    except ValueError:
        return None, line


class Run:
    def __init__(self, out, proc, pid, app):
        self.out, self.proc, self.pid, self.app = out, proc, pid, app
        self.shots = 0
        self.stopped = None

    def alive(self):
        if self.proc is not None:
            return self.proc.poll() is None
        return subprocess.run(['kill', '-0', str(self.pid)], stdout=subprocess.DEVNULL,
                              stderr=subprocess.DEVNULL).returncode == 0

    def screen(self, name):
        self.shots += 1
        path = os.path.join(self.out, 'shots', '%02d-%s.png' % (self.shots, name))
        if ui_tour.mac_screen(path):
            log('%.3f screen: %s' % (time.time(), os.path.basename(path)))

    def look(self, step, seconds=LOOK):
        """Whether the beat went on in the seconds after a step: the last
        beat no more than STOPPED_AFTER old at the end of them."""
        end = time.time() + seconds
        last = None
        while time.time() < end:
            when, line = read_beat(self.out)
            if line != last:
                last = line
            time.sleep(0.5)
        when, line = read_beat(self.out)
        age = time.time() - when if when else None
        log('%.3f %s: the last beat %s: %s' % (time.time(), step, 'none' if age is None else '%.1f s ago' % age,
                                                line))
        return age is not None and age <= STOPPED_AFTER

    def stop_report(self, step, menu, title):
        """What the engine is doing, once the beat stopped after step."""
        self.stopped = step
        log('::error title=Menu and backdrop::the IDE stopped answering after the step %s' % step)
        self.screen('stopped-after-%s' % step)
        ui_tour.mac_sample(self.pid, os.path.join(self.out, 'sample-%s.txt' % step))
        ui_tour.mac_tools_log(120)
        # does it come back?
        key(ESCAPE)
        if self.look('%s, then Escape' % step, 6):
            log('It answers again after Escape.')
            return
        self.screen('after-escape')
        if title:
            click(*title)
            time.sleep(1)
            key(ESCAPE)
            if self.look('%s, then the menu title and Escape' % step, 6):
                log('It answers again after a click on the menu title and Escape.')
                return
        self.screen('still-stopped')
        log('It still does not answer: a second sample.')
        ui_tour.mac_sample(self.pid, os.path.join(self.out, 'sample-%s-later.txt' % step))


def command(out, line):
    """A line of script for the IDE's script to run at its next beat."""
    with open(os.path.join(out, 'command.txt'), 'w', encoding='utf-8') as f:
        f.write(line + '\n')
    log('%.3f command: %s' % (time.time(), line))


def main(argv=None):
    ap = argparse.ArgumentParser(description='The Mac IDE after a menu and a click on the backdrop.')
    ap.add_argument('--install', required=True, metavar='DIR', help='the folder that holds OXT-Beyond.app')
    ap.add_argument('--out', required=True, metavar='DIR', help='folder for the logs and the screenshots')
    ap.add_argument('--menu', default='Text', help='the menu to open (default: %(default)s)')
    ap.add_argument('--launch', choices=('exec', 'open'), default='exec',
                    help='run the binary, or start the app with open (default: %(default)s)')
    ap.add_argument('--timeout', type=int, default=240, help='seconds for the IDE to get ready (default: %(default)s)')
    args = ap.parse_args(argv)

    p = package.PLATFORMS['mac-universal']
    out = os.path.abspath(args.out)
    if os.path.isdir(out):
        shutil.rmtree(out)
    os.makedirs(os.path.join(out, 'shots'))
    document = os.path.join(out, DOCUMENT)
    shutil.copyfile(SCRIPT, document)
    results = os.path.join(out, 'menu-backdrop.txt')

    temp_dirs = []
    args.bin_dir, args.engine, args.package = None, None, None
    try:
        lay = rlc.find_layout(args, p, temp_dirs)
    except rlc.CheckError as e:
        log('error: %s' % e)
        return 2
    app = ui_tour.mac_app(lay.engine)
    log('Engine     : %s' % lay.engine)
    log('Launch     : %s' % args.launch)
    if os.environ.get('GITHUB_ACTIONS'):
        ui_tour.mac_no_crash_dialog()
    restore = ui_tour.set_mac('light')

    proc = None
    engine_log = open(os.path.join(out, 'engine-output.txt'), 'wb')
    started = time.time()
    status = 2
    try:
        if args.launch == 'exec':
            proc = subprocess.Popen([lay.engine, document], cwd=out, stdout=engine_log, stderr=subprocess.STDOUT,
                                    start_new_session=True)
            pid = proc.pid
        else:
            subprocess.run(['open', '-n', '-a', app, document], stdout=engine_log, stderr=subprocess.STDOUT)
            pid = None
            for _ in range(60):
                found = subprocess.run(['pgrep', '-n', '-f', lay.engine], stdout=subprocess.PIPE).stdout.split()
                if found:
                    pid = int(found[0])
                    break
                time.sleep(1)
            if pid is None:
                log('error: no process of %s after open' % lay.engine)
                return 2
        log('pid        : %d' % pid)
        run = Run(out, proc, pid, app)

        point = None
        while time.time() - started < args.timeout:
            lines = ui_tour.read_lines(results)
            if any(x == 'READY' for x in lines):
                point = next((x.split()[1] for x in lines if x.startswith('POINT ') and len(x.split()) > 1), None)
                break
            if not run.alive():
                log('error: the IDE ended before it was ready')
                return 2
            time.sleep(1)
        else:
            log('error: the IDE was not ready in %d s' % args.timeout)
            run.screen('not-ready')
            ui_tour.mac_sample(pid, os.path.join(out, 'sample-not-ready.txt'))
            return 2
        log('Ready after %.0f s; a point of the backdrop: %s' % (time.time() - started, point))
        if not point:
            log('error: no point of the backdrop that no window covers')
            return 2
        bx, by = [int(v) for v in point.split(',')]
        menu_bar_titles(pid)
        title = menu_title(pid, args.menu)
        if title is None:
            if args.menu not in IDE_MENUS:
                log('error: the menu %s was not found in the menu bar (System Events)' % args.menu)
                return 2
            log('The menu %s is opened from the keyboard instead: Control-F2 and the arrow keys' % args.menu)
        run.screen('ready')

        def open_menu():
            if title:
                click(*title)
            else:
                # Control-F2 takes the keyboard to the menu bar's Apple
                # menu; the IDE's menus follow the application menu
                key(F2, CONTROL)
                time.sleep(0.5)
                for _ in range(IDE_MENUS.index(args.menu) + 2):
                    key(RIGHT)
                    time.sleep(0.2)
                key(DOWN)

        def step_menu_close():
            open_menu()
            time.sleep(1.5)
            run.screen('menu-open')
            if title:
                click(*title)
            else:
                key(ESCAPE)
            time.sleep(1)

        def step_backdrop():
            click(bx, by)
            time.sleep(1)

        def step_menu_backdrop():
            open_menu()
            time.sleep(1.5)
            run.screen('menu-open')
            click(bx, by)
            time.sleep(1)
            run.screen('backdrop-clicked')

        def step_menu_desktop():
            command(out, 'set the backdrop to "none"')
            time.sleep(2)
            open_menu()
            time.sleep(1.5)
            click(bx, by)
            time.sleep(1)
            run.screen('desktop-clicked')

        steps = [('menu-close', step_menu_close), ('backdrop', step_backdrop),
                 ('menu-backdrop', step_menu_backdrop), ('menu-backdrop-again', step_menu_backdrop),
                 ('menu-desktop', step_menu_desktop)]
        status = 0
        for name, do in steps:
            log('::group::Step %s' % name)
            do()
            answered = run.look(name)
            run.screen('after-%s' % name)
            log('::endgroup::')
            if not answered:
                run.stop_report(name, args.menu, title)
                status = 1
                break
            log('Step %s: the IDE answers.' % name)
    finally:
        if proc is not None:
            ui_tour.stop(proc)
        elif 'pid' in locals() and pid:
            subprocess.run(['kill', '-9', str(pid)], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        engine_log.close()
        restore()
        for d in temp_dirs:
            shutil.rmtree(d, ignore_errors=True)
        log('')
        log('::group::The IDE script\'s lines')
        for x in ui_tour.read_lines(results):
            log(x)
        log('::endgroup::')
        tail = ui_tour.read_lines(os.path.join(out, 'engine-output.txt'))[-60:]
        if tail:
            log('::group::The engine\'s output (last lines)')
            for x in tail:
                log(x)
            log('::endgroup::')
        shots = os.path.join(out, 'shots')
        names = sorted(n for n in os.listdir(shots) if n.endswith('.png'))
        log('::group::Screenshots (%d, base64 for tools/ci/print_images.py)' % len(names))
        for n in names:
            ui_tour.print_image('menu-backdrop/%s' % n, os.path.join(shots, n))
        log('::endgroup::')
    log('Menu and backdrop: %s' % {0: 'the IDE answered after every step', 1: 'the IDE stopped answering',
                                   2: 'the check could not run'}[status])
    return status


if __name__ == '__main__':
    sys.exit(main())
