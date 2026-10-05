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

"""Times tools/ci/field-speed-test.livecodescript (a Sudoku-shaped stack's
field work) in an engine with a user interface, and on macOS profiles it.

The script runs as the development engine's home stack (copied to
<out>/tools/Startup.rev, REV_TOOLS_PATH pointing there), or with --ide in
the real IDE, which is started first and then sent the script as a
document to open. While the script solves the puzzle (it writes
<out>/speed/solving), `sample` records the engine for a few seconds; the
same happens if the run does not end in time. The engine's frames are
named with atos and the dSYM given with --dsym, as release binaries carry
no symbols. Everything is printed, for the CI log.

Exit status 0 when the script reported "done".
"""

import argparse
import os
import platform
import re
import shutil
import subprocess
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
SCRIPT = os.path.join(HERE, 'field-speed-test.livecodescript')


def defaults(*args):
    proc = subprocess.run(('defaults',) + args, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    return proc.returncode, proc.stdout.decode('utf-8', 'replace').strip()


def set_mac_setting(value):
    """'dark', 'light' or None (leave it)."""
    if value == 'dark':
        defaults('write', '-g', 'AppleInterfaceStyle', 'Dark')
    elif value == 'light':
        defaults('delete', '-g', 'AppleInterfaceStyle')


def read_mac_setting():
    code, out = defaults('read', '-g', 'AppleInterfaceStyle')
    return out if code == 0 else None


def sample(pid, seconds, path):
    if not shutil.which('sample'):
        return False
    proc = subprocess.run(['sample', str(pid), str(seconds), '-file', path],
                          stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    return proc.returncode == 0 and os.path.isfile(path)


def symbolicate(text, dsym, image):
    """Names the frames of the image (the engine's executable name) in a
    `sample` report with atos and the dSYM's DWARF file."""
    if not dsym or not os.path.isfile(dsym) or not shutil.which('atos'):
        return text
    load = None
    for line in text.splitlines():
        m = re.match(r'\s*(0x[0-9a-f]+)\s+-\s+0x[0-9a-f]+\s+\+?%s\b' % re.escape(image), line)
        if m:
            load = m.group(1)
            break
    if load is None:
        return text
    frame = re.compile(r'(\S.*?)\s+\(in %s\)(.*?)\[(0x[0-9a-f]+)(?:,0x[0-9a-f]+)*\]' % re.escape(image))
    addresses = sorted(set(m.group(3) for m in frame.finditer(text)))
    names = {}
    arch = platform.machine()
    for i in range(0, len(addresses), 500):
        chunk = addresses[i:i + 500]
        proc = subprocess.run(['atos', '-o', dsym, '-arch', arch, '-l', load] + chunk,
                              stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
        lines = proc.stdout.decode('utf-8', 'replace').splitlines()
        for address, name in zip(chunk, lines):
            # "MCField::settext(...) (in LiveCode-Community) (field.cpp:123)"
            name = re.sub(r' \(in [^)]*\)', '', name).strip()
            if name and not name.startswith('0x'):
                names[address] = name

    def rename(m):
        name = names.get(m.group(3))
        if not name:
            return m.group(0)
        # keep the count and the tree markers before the symbol
        lead = re.match(r'([+!:|\s\d]*)', m.group(1)).group(1)
        return '%s%s  (in %s)  [%s]' % (lead, name, image, m.group(3))
    return frame.sub(rename, text)


def section(text, start, stop_prefixes, limit):
    """The lines of the report from the one starting with `start`."""
    out = []
    on = False
    for line in text.splitlines():
        if line.startswith(start):
            on = True
        elif on and any(line.startswith(p) for p in stop_prefixes):
            break
        if on:
            out.append(line[:220])
            if len(out) >= limit:
                break
    return out


def print_sample(path, dsym, image):
    with open(path, encoding='utf-8', errors='replace') as f:
        text = f.read()
    text = symbolicate(text, dsym, image)
    with open(path + '.symbolicated.txt', 'w', encoding='utf-8') as f:
        f.write(text)
    stops = ('Total number in stack', 'Sort by top of stack', 'Binary Images')
    print('--- sample: functions on the stack (a recursive one counted at each level)')
    for line in section(text, 'Total number in stack', ('Sort by top of stack', 'Binary Images'), 80):
        print(line)
    print('--- sample: where the samples were (top of stack)')
    for line in section(text, 'Sort by top of stack', ('Binary Images',), 50):
        print(line)
    # The main thread's frames in at least a tenth of its samples: the
    # first ones, then the deepest, where the time goes
    graph = section(text, 'Call graph:', stops, 1000000)
    total = None
    heavy = []
    for line in graph:
        if 'Thread_' in line and total is not None:
            break
        m = re.match(r'[\s+!:|]*(\d+) ', line)
        if not m:
            continue
        count = int(m.group(1))
        if total is None:
            total = count
        if count * 10 >= total:
            heavy.append(line.rstrip())
    print('--- sample: the main thread, frames in 10%% or more of %s samples (%d lines)' % (total, len(heavy)))
    if len(heavy) > 200:
        heavy = heavy[:40] + ['    ...'] + heavy[-160:]
    for line in heavy:
        print(line[-220:] if len(line) > 220 else line)


def run(args):
    out = os.path.abspath(args.out)
    if os.path.isdir(out):
        shutil.rmtree(out)
    tools = os.path.join(out, 'tools')
    speed = os.path.join(out, 'speed')
    os.makedirs(tools)
    os.makedirs(speed)

    env = dict(os.environ)
    env['OXT_SPEED_OUT'] = speed
    env['OXT_SPEED_SOLVE_MS'] = str(args.solve_ms)
    if args.appearance:
        env['OXT_SPEED_APPEARANCE'] = args.appearance

    engine = args.engine or os.path.join(args.app, 'Contents', 'MacOS', 'OXT-Beyond')
    image = os.path.basename(engine)
    if args.ide:
        document = os.path.join(out, 'oxt_field_speed_test.livecodescript')
        shutil.copyfile(SCRIPT, document)
    else:
        shutil.copyfile(SCRIPT, os.path.join(tools, 'Startup.rev'))
        env['REV_TOOLS_PATH'] = tools

    saved = read_mac_setting() if sys.platform == 'darwin' else None
    if sys.platform == 'darwin':
        set_mac_setting(args.mac)
        print('The Mac: AppleInterfaceStyle %s' % (read_mac_setting() or '(not set: light)'))

    results = os.path.join(speed, 'speed.txt')
    solving = os.path.join(speed, 'solving')
    sampled = None
    status = 'did not finish in %d s' % args.timeout
    started = time.time()
    with open(os.path.join(out, 'engine-output.txt'), 'wb') as log:
        proc = subprocess.Popen([engine], cwd=tools, env=env, stdout=log, stderr=subprocess.STDOUT)
        try:
            if args.ide:
                # the IDE first, then the document
                time.sleep(args.ide_wait)
                subprocess.run(['open', '-a', args.app, document])
            while time.time() - started < args.timeout:
                if proc.poll() is not None:
                    status = 'ended with exit status %d after %.0f s' % (proc.returncode, time.time() - started)
                    break
                if args.ide and os.path.isfile(results):
                    with open(results, encoding='utf-8', errors='replace') as f:
                        if '\tdone\t' in f.read():
                            status = 'reported done after %.0f s' % (time.time() - started)
                            break
                if sampled is None and os.path.isfile(solving) and sys.platform == 'darwin':
                    sampled = os.path.join(out, 'sample-solving.txt')
                    if not sample(proc.pid, args.sample_seconds, sampled):
                        sampled = None
                        print('(sample failed)')
                time.sleep(0.2)
            if proc.poll() is None and sys.platform == 'darwin' and 'did not finish' in status:
                # where it is stuck
                sampled = os.path.join(out, 'sample-timeout.txt')
                if not sample(proc.pid, args.sample_seconds, sampled):
                    sampled = None
        finally:
            if proc.poll() is None:
                proc.kill()
                proc.wait()
            if sys.platform == 'darwin':
                if saved is None:
                    set_mac_setting('light')
                else:
                    set_mac_setting('dark')

    print('Engine: %s' % status)
    print('--- speed.txt')
    if os.path.isfile(results):
        with open(results, encoding='utf-8', errors='replace') as f:
            text = f.read()
        print(text.rstrip())
    else:
        text = ''
        print('(none)')
    print('--- the engine\'s output (first 3000 bytes)')
    with open(os.path.join(out, 'engine-output.txt'), 'rb') as f:
        print(f.read(3000).decode('utf-8', 'replace'))
    if sampled:
        print_sample(sampled, args.dsym, image)
    sys.stdout.flush()
    return 0 if '\tdone\t' in text else 1


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    where = parser.add_mutually_exclusive_group(required=True)
    where.add_argument('--app', help='OXT-Beyond.app (its engine is Contents/MacOS/OXT-Beyond)')
    where.add_argument('--engine', help='the development engine to run')
    parser.add_argument('--out', required=True, help='folder for this run')
    parser.add_argument('--mac', choices=('dark', 'light'), help='set the Mac to dark or light for the run')
    parser.add_argument('--appearance', default='', help='the appAppearance to set (light, dark, system)')
    parser.add_argument('--ide', action='store_true', help='run the script in the IDE (needs --app)')
    parser.add_argument('--ide-wait', type=int, default=30, help='seconds for the IDE to start (default %(default)s)')
    parser.add_argument('--solve-ms', type=int, default=20000, help='how long the solve may run (default %(default)s)')
    parser.add_argument('--sample-seconds', type=int, default=5)
    parser.add_argument('--timeout', type=int, default=180, help='seconds for the run (default %(default)s)')
    parser.add_argument('--dsym', default='', help="the engine's dSYM DWARF file, for atos")
    args = parser.parse_args(argv)
    if args.ide and not args.app:
        parser.error('--ide needs --app')
    return run(args)


if __name__ == '__main__':
    sys.exit(main())
