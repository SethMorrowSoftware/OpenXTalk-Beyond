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

"""The Mac IDE with the backdrop on, a menu of its menu bar and real
clicks. The forum's report on 0.2.7-rc.6.4 (tperry2x, macOS Sonoma on
Apple silicon): "If you click the menu, then click the actual backdrop,
seems to be a program freeze (loop?)", the Menubar palette gone and
nothing else drawn. It was no freeze: a click on the backdrop brought it
in front of every window of the IDE but its palettes, and the engine went
on answering behind it.

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
found with System Events), each step followed by a look at the beat and
at the window server's order of the IDE's windows
(CGWindowListCopyWindowInfo):

  menu-close      the menu's title, then the title again (the menu closes)
  menu-backdrop   the menu's title, then the backdrop (the report)
  backdrop        the backdrop alone, then once more
  away-backdrop   the Finder made the active app, then the backdrop
  menu-desktop    the backdrop off, the menu's title, then the desktop
  menu-slide      File's title clicked, the pointer moved to Edit's
                  title, back to File's and on to Help's, without a click
                  (a slide along the menu bar), the items of the open menu
                  read with System Events at each: File must never show
                  Exit nor Help About, which the application menu shows
                  instead (the report on 0.2.8-dp.2.1, macOS 26 on Apple
                  silicon and Intel: File gained an Exit item at its
                  bottom after the pointer went to Edit and back)

After each step with the backdrop on, the backdrop must be behind every
window of the IDE of the normal layer (the Menubar palette, the stacks),
not in front of them; when it is not, the screen is taken and the
backdrop turned off and on again, which puts it back, before the next
step. A step after which the beat stops for 8 s is a stop: the screen is
taken, the engine is sampled (its main thread's call graph into the log,
named from the build's dSYMs under $OXT_DSYM_DIR), then Escape is pressed
and the title clicked again to see whether either brings it back, and no
more steps run. Every screenshot is printed into the log as
tools/ci/print_images.py reads it. Exit status 0 when the IDE answered and
kept the backdrop behind its windows after every step and the slide
showed no hidden item, 1 when it did not,
2 when the check itself could not run. Only the Python 3 standard library
is used.
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


def osascript(text, language=None, timeout=30, args=()):
    """Runs text with osascript, args going to its run handler: (exit
    status, what it printed)."""
    cmd = ['osascript'] + (['-l', language] if language else []) + ['-e', text] + [str(a) for a in args]
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


def move(x, y):
    """The pointer moved to x, y on the screen, no button down: over a
    title of the menu bar while one of its menus is open, macOS opens that
    title's menu instead (a slide)."""
    code, said = osascript(POST + 'post(5, %d, %d, 0);' % (x, y), 'JavaScript')
    log('%.3f move to %d,%d%s' % (time.time(), x, y, '' if code == 0 and not said else ' (%s: %s)' % (code, said)))


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


# The windows of a process on the screen, front to back, as the window
# server orders them (CGWindowListCopyWindowInfo, kCGWindowListOptionOnScreenOnly):
# a line each of its number, layer, x, y, width, height and title (empty
# where macOS does not give it)
WINDOWS = '''ObjC.import("CoreGraphics");
function run(argv) {
  var pid = parseInt(argv[0]);
  var list = ObjC.deepUnwrap(ObjC.castRefToObject($.CGWindowListCopyWindowInfo(1, 0)));
  var out = [];
  for (var i = 0; i < list.length; i++) {
    var w = list[i];
    if (w.kCGWindowOwnerPID != pid) continue;
    var b = w.kCGWindowBounds;
    out.push([w.kCGWindowNumber, w.kCGWindowLayer, Math.round(b.X), Math.round(b.Y),
              Math.round(b.Width), Math.round(b.Height), w.kCGWindowName || ""].join(" "));
  }
  return out.join("\\n");
}
'''


def window_order(pid):
    """The windows of the process pid on the screen, front to back: tuples
    of (number, layer, x, y, width, height, title), or None when the
    window server could not be asked."""
    code, said = osascript(WINDOWS, 'JavaScript', args=[pid])
    if code != 0:
        log('The window list: exit status %s: %s' % (code, said))
        return None
    windows = []
    for line in said.splitlines():
        words = line.split(' ', 6)
        try:
            windows.append(tuple(int(v) for v in words[:6]) + ((words[6] if len(words) > 6 else ''),))
        except ValueError:
            log('The window list: an odd line: %r' % line)
    return windows


def backdrop_behind(windows, screen):
    """Whether the backdrop (the process's window of the normal layer, 0,
    that covers the whole screen, x, y, width and height) is behind the
    process's other windows of that layer, and the order as text. None
    when there is no such window, no other window of that layer to be
    behind (so no answer), or no list."""
    if windows is None:
        return None, 'no window list'
    names = []
    backdrop = None
    before, after = [], []
    for number, layer, x, y, w, h, title in windows:
        if w == 0 or h == 0:
            continue
        if layer == 0 and (x, y, w, h) == tuple(screen):
            backdrop = number
            names.append('[backdrop]')
            continue
        names.append('%s%s' % (title or '#%d %dx%d at %d,%d' % (number, w, h, x, y),
                               '' if layer == 0 else ' (layer %d)' % layer))
        if layer == 0:
            (before if backdrop is None else after).append(names[-1])
    text = ' > '.join(names)
    if backdrop is None:
        return None, 'no backdrop: ' + text
    if after:
        return False, 'the backdrop is IN FRONT of %s: %s' % (', '.join(after), text)
    if not before:
        return None, 'no window of the normal layer but the backdrop: ' + text
    return True, 'the backdrop is behind: ' + text


def frontmost():
    """The unix id of the active app's process, as System Events sees it."""
    code, said = osascript('tell application "System Events" to get unix id of first process whose frontmost is true')
    return said


def menu_items(pid, menu):
    """The titles of the items of the menu bar menu named menu of the
    process pid that System Events finds (a separator as "-"; macOS leaves
    hidden items out), or None when it could not be asked."""
    code, said = osascript(
        'tell application "System Events"\n'
        '  set p to first application process whose unix id is %d\n'
        '  set t to ""\n'
        '  repeat with i in menu items of menu 1 of menu bar item "%s" of menu bar 1 of p\n'
        '    set n to name of i\n'
        '    if n is missing value then set n to "-"\n'
        '    set t to t & n & linefeed\n'
        '  end repeat\n'
        '  return t\n'
        'end tell' % (pid, menu))
    if code != 0:
        log('System Events: the items of %s: exit status %s: %s' % (menu, code, said))
        return None
    items = [x for x in said.splitlines() if x]
    log('System Events: the items of %s: %s' % (menu, ' | '.join(items)))
    return items


# The items each menu bar menu must not show on a Mac, where the
# application menu shows them instead (the engine hides them,
# engine/src/mac-menu.mm, hideShadowedMenuItems)
HIDDEN_ITEMS = {'File': ('Exit', 'Quit'), 'Help': ('About',)}


def shown_hidden(menu, items):
    """The items of menu that items (as menu_items gives them) shows and
    must not."""
    return [x for x in (items or []) if x in HIDDEN_ITEMS.get(menu, ())]


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
        """Whether the beat went on in the seconds after a step: the newest
        beat read in them no more than STOPPED_AFTER old at the end of them.
        The newest of every read, not the last read alone: the engine's put
        into URL "binfile:" empties beat.txt before it writes the new beat,
        so a read between the two finds nothing, or the first digits of the
        new beat, though the beat goes on. (A last read alone took that for
        a stop on an Intel Mac on 20 Nov 2026, in #585's run; the engine,
        sampled, was in that very put, and answered again at once.)"""
        end = time.time() + seconds
        newest, newest_line = None, ''
        while True:
            when, line = read_beat(self.out)
            if when is not None and (newest is None or when > newest):
                newest, newest_line = when, line
            if time.time() >= end:
                break
            time.sleep(0.5)
        age = time.time() - newest if newest else None
        log('%.3f %s: the last beat %s: %s%s' % (time.time(), step, 'none' if age is None else '%.1f s ago' % age,
                                                  newest_line,
                                                  '' if when == newest else ' (the last read: %r)' % line))
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
    misplaced = []
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
        rect = next((x.split()[2] for x in lines if x.startswith('INFO screenRect ')), '')
        try:
            left, top, right, bottom = [int(v) for v in rect.split(',')]
        except ValueError:
            log('error: no screenRect from the IDE: %r' % rect)
            return 2
        screen = (left, top, right - left, bottom - top)
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
            run.screen('backdrop-clicked')
            click(bx, by)
            time.sleep(1)

        def step_menu_backdrop():
            open_menu()
            time.sleep(1.5)
            run.screen('menu-open')
            click(bx, by)
            time.sleep(1)
            run.screen('backdrop-clicked')

        def step_away_backdrop():
            code, said = osascript('tell application "Finder" to activate')
            time.sleep(2)
            log('%.3f the active app: %s' % (time.time(), frontmost()))
            run.screen('finder-active')
            click(bx, by)
            time.sleep(1.5)
            log('%.3f the active app: %s (the IDE is %d)' % (time.time(), frontmost(), pid))

        slide_faults = []

        def step_menu_slide():
            """File's title clicked, then a slide to Edit, back to File and
            on to Help, the open menu's items read at each stop"""
            # the step before clicked the desktop, which makes the Finder
            # the active app and puts its menu bar on the screen: the IDE
            # made the active app again, or the slide would be in the
            # Finder's menus
            code, said = osascript('tell application "System Events" to set frontmost of '
                                   '(first application process whose unix id is %d) to true' % pid)
            time.sleep(1.5)
            active = frontmost()
            log('%.3f the active app: %s (the IDE is %d)%s' % (time.time(), active, pid,
                                                              '' if code == 0 else ' (exit status %s: %s)' % (code, said)))
            if active != str(pid):
                log('error: the IDE could not be made the active app: no slide')
                slide_faults.append('the IDE could not be made the active app')
                return
            titles = {m: menu_title(pid, m) for m in ('File', 'Edit', 'Help')}
            if None in titles.values():
                log('error: a title of File, Edit and Help was not found (System Events): no slide')
                slide_faults.append('a title of File, Edit or Help was not found')
                return
            first = None
            for n, (menu, how) in enumerate((('File', click), ('Edit', move), ('File', move), ('Help', move))):
                how(*titles[menu])
                time.sleep(1.5)
                items = menu_items(pid, menu)
                run.screen('slide-%d-%s' % (n + 1, menu.lower()))
                if items is None:
                    slide_faults.append('the items of %s could not be read' % menu)
                    continue
                if menu == 'File':
                    if first is None:
                        first = items
                    elif items != first:
                        log('File\'s items after the slide differ from its first opening\'s')
                        slide_faults.append('File changed after the slide: %s' % ', '.join(
                            [x for x in items if x not in first] or ['(its order)']))
                bad = shown_hidden(menu, items)
                if bad:
                    log('::error title=Menu slide::%s shows %s (stop %d of the slide)' % (menu, ', '.join(bad), n + 1))
                    slide_faults.append('%s showed %s at stop %d of the slide' % (menu, ', '.join(bad), n + 1))
            key(ESCAPE)
            time.sleep(1)

        def step_menu_desktop():
            command(out, 'set the backdrop to "none"')
            time.sleep(2)
            open_menu()
            time.sleep(1.5)
            click(bx, by)
            time.sleep(1)
            run.screen('desktop-clicked')

        # (name, what it does, whether the backdrop is on)
        steps = [('menu-close', step_menu_close, True), ('menu-backdrop', step_menu_backdrop, True),
                 ('backdrop', step_backdrop, True), ('away-backdrop', step_away_backdrop, True),
                 ('menu-desktop', step_menu_desktop, False), ('menu-slide', step_menu_slide, False)]
        status = 0
        behind, said = backdrop_behind(window_order(pid), screen)
        log('Ready: %s' % said)
        if behind is not True:
            log('error: the backdrop is not behind the IDE\'s windows before the first click')
            return 2
        for name, do, backdrop in steps:
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
            if name == 'menu-slide' and slide_faults:
                status = 1
            if not backdrop:
                continue
            behind, said = backdrop_behind(window_order(pid), screen)
            log('Step %s: %s' % (name, said))
            if behind is not True:
                log('::error title=Menu and backdrop::after the step %s %s' % (name, said))
                misplaced.append(name)
                status = 1
                # back behind the IDE's windows for the next step
                command(out, 'mbResetBackdrop')
                time.sleep(2)
                log('After the backdrop was turned off and on: %s' % backdrop_behind(window_order(pid), screen)[1])
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
    if status == 1:
        said = []
        if 'slide_faults' in locals() and slide_faults:
            said.append('the slide along the menu bar: %s' % '; '.join(slide_faults))
        if misplaced:
            said.append('the backdrop came in front of the IDE\'s windows after the step%s %s' % (
                's' if len(misplaced) > 1 else '', ', '.join(misplaced)))
        if 'run' in locals() and run.stopped:
            said.append('the IDE stopped answering after the step %s' % run.stopped)
        verdict = '; '.join(said)
    else:
        verdict = {0: 'the IDE answered and kept the backdrop behind its windows after every step, '
                      'and the slide along the menu bar showed no item the application menu shows',
                   2: 'the check could not run'}[status]
    log('Menu and backdrop: %s' % verdict)
    return status


if __name__ == '__main__':
    sys.exit(main())
