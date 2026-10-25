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

"""A probe, not a test: where macOS puts a window that cannot become key
(the engine's backdrop) when it is clicked, and which way of keeping it
behind the app's other windows works. tools/ci/mac-backdrop-probe.m is
built and started once per way; each is clicked with real mouse events
(tools/ci/mac_menu_backdrop.py's), and the window server's order of its
windows is read after each click.

  python3 tools/ci/mac_backdrop_probe.py OUT
"""

import os
import shutil
import subprocess
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import mac_menu_backdrop as mb  # noqa: E402

WAYS = ['firstmouse', 'upstream', 'mousedown', 'sendevent', 'prevent', 'keyable']

log = mb.log


def frontmost():
    code, said = mb.osascript('tell application "System Events" to get unix id of first process whose frontmost is true')
    return said


def main():
    out = os.path.abspath(sys.argv[1] if len(sys.argv) > 1 else 'backdrop-probe')
    shutil.rmtree(out, ignore_errors=True)
    os.makedirs(out)
    binary = os.path.join(out, 'mac-backdrop-probe')
    built = subprocess.run(['clang', '-fobjc-arc', '-Wno-deprecated-declarations', '-framework', 'Cocoa',
                            '-framework', 'QuartzCore', '-o', binary, os.path.join(HERE, 'mac-backdrop-probe.m')])
    if built.returncode != 0:
        log('error: the probe did not build')
        return 2
    summary = []
    for way in WAYS:
        folder = os.path.join(out, way)
        os.makedirs(folder)
        probe_log = os.path.join(folder, 'probe.txt')

        def command(line):
            with open(os.path.join(folder, 'command.txt'), 'w', encoding='utf-8') as f:
                f.write(line + '\n')
            time.sleep(0.4)

        log('::group::%s' % way)
        proc = subprocess.Popen([binary, way, folder], stdout=subprocess.DEVNULL, stderr=subprocess.STDOUT)
        ready = None
        for _ in range(60):
            ready = next((x for x in mb.ui_tour.read_lines(probe_log) if ' READY ' in x), None)
            if ready or proc.poll() is not None:
                break
            time.sleep(0.5)
        if not ready:
            log('error: the probe was not ready')
            proc.kill()
            log('::endgroup::')
            summary.append((way, 'not ready'))
            continue
        words = ready.split()
        bx, by = [int(v) for v in words[2].split(',')]
        screen = tuple(int(v) for v in words[4].split(','))
        mb.osascript('tell application "System Events" to set frontmost of (first process whose unix id is %d) '
                     'to true' % proc.pid)
        time.sleep(1.5)
        log('frontmost: %s (the probe is %d)' % (frontmost(), proc.pid))

        def order(label):
            windows = mb.window_order(proc.pid)
            behind, text = mb.backdrop_behind(windows, screen)
            log('%s: %s' % (label, text))
            return behind

        def scenario(name, act):
            command('sync')
            order('%s, before' % name)
            act()
            time.sleep(1.5)
            behind = order('%s, after' % name)
            command('log %s done' % name)
            summary.append((way, '%s: %s' % (name, 'behind' if behind else 'IN FRONT')))

        scenario('click', lambda: mb.click(bx, by))

        def twice():
            mb.click(bx, by)
            time.sleep(1)
            mb.click(bx, by)
        scenario('click-twice', twice)

        title = mb.menu_title(proc.pid, 'Text')

        def menu_click():
            if title:
                mb.click(*title)
                time.sleep(1.2)
            mb.click(bx, by)
            time.sleep(0.5)
            mb.key(mb.ESCAPE)
        scenario('menu-then-click', menu_click)

        def inactive_click():
            mb.osascript('tell application "Finder" to activate')
            time.sleep(1.5)
            log('frontmost before the click: %s' % frontmost())
            mb.click(bx, by)
            time.sleep(1)
            log('frontmost after the click: %s' % frontmost())
        scenario('inactive-click', inactive_click)

        command('quit')
        time.sleep(1)
        if proc.poll() is None:
            proc.kill()
        for x in mb.ui_tour.read_lines(probe_log):
            log('  ' + x)
        log('::endgroup::')
    log('')
    log('Summary (%s):' % ' '.join(os.uname()[2:3]))
    for way, verdict in summary:
        log('  %-11s %s' % (way, verdict))
    return 0


if __name__ == '__main__':
    sys.exit(main())
