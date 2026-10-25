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

"""Screenshots of the IDE's own windows as a user sees them, light or dark,
on Windows, Linux and macOS.

  python tools/ci/ui_tour.py (--install DIR | --package FILE) --out DIR
      [--platform P] [--appearance light|dark] [--timeout SECONDS]
      [--only NAMES]

The other checks run the engine with -ui or with a test stack as its home
stack; none of them looks at the IDE's palettes, inspector, editors and
dialogs, which are stacks of their own with colours of their own. This
starts the installed IDE as a user does, with tools/ci/ui-tour.livecodescript
named on the command line (the engine opens it once the IDE has started),
and that script opens the IDE's windows one by one and writes a snapshot of
the screen around each, and one with a tooltip showing.

The system is set to the appearance first, as a user's setting is stored,
and restored at the end:

  macOS    defaults write -g AppleInterfaceStyle Dark (dark), or delete it
  Windows  HKCU\\...\\Themes\\Personalize AppsUseLightTheme and
           SystemUsesLightTheme 0 (dark) or 1 (light)
  Linux    GTK2_RC_FILES: the Adwaita or Adwaita-dark GTK 2 theme when it
           is installed (gnome-themes-extra), else a gtkrc of plain light or
           dark colours; the engine runs under xvfb-run when there is no
           DISPLAY

The IDE follows the system's appearance (OpenXTalk Lite 1.15's dark mode on
Windows and macOS; Linux is drawn light).

Everything is printed, for the CI log: the script's lines (INFO, ERROR,
SHOT, STEP and DONE) and every snapshot as lines tools/ci/print_images.py
turns back into PNG files ("IMAGE <appearance>/<file> <part>/<parts>
<base64>"). The snapshots also stay in <out>/shots. On macOS a crash report
macOS wrote of the engine during the run is printed too, with a warning.
Exit status 0 when the script got to the end with every step done and no
script error in the IDE's windows, 1 otherwise. Only the Python 3 standard
library is used (3.8 or later).
"""

import argparse
import base64
import json
import os
import re
import shutil
import signal
import subprocess
import sys
import tempfile
import time

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(os.path.dirname(HERE), 'oxt'))
sys.path.insert(0, HERE)
import package  # noqa: E402
import run_livecode_check as rlc  # noqa: E402

SCRIPT = os.path.join(HERE, 'ui-tour.livecodescript')

# GTK 2 themes for Linux: the installed Adwaita ones, else plain colours
ADWAITA = {'light': '/usr/share/themes/Adwaita/gtk-2.0/gtkrc',
           'dark': '/usr/share/themes/Adwaita-dark/gtk-2.0/gtkrc'}
PLAIN = {
    'light': {'bg': '#ececec', 'bg2': '#f6f6f6', 'fg': '#1a1a1a', 'base': '#ffffff', 'sel': '#3584e4',
              'off': '#8b8e8f'},
    'dark': {'bg': '#353535', 'bg2': '#3f3f3f', 'fg': '#eeeeec', 'base': '#2d2d2d', 'sel': '#15539e',
             'off': '#8b8e8f'},
}
GTKRC = """style "oxt-ui-tour"
{
  bg[NORMAL] = "%(bg)s"
  bg[PRELIGHT] = "%(bg2)s"
  bg[ACTIVE] = "%(bg)s"
  bg[SELECTED] = "%(sel)s"
  bg[INSENSITIVE] = "%(bg)s"
  fg[NORMAL] = "%(fg)s"
  fg[PRELIGHT] = "%(fg)s"
  fg[ACTIVE] = "%(fg)s"
  fg[SELECTED] = "#ffffff"
  fg[INSENSITIVE] = "%(off)s"
  base[NORMAL] = "%(base)s"
  base[SELECTED] = "%(sel)s"
  base[ACTIVE] = "%(sel)s"
  base[INSENSITIVE] = "%(bg)s"
  text[NORMAL] = "%(fg)s"
  text[SELECTED] = "#ffffff"
  text[ACTIVE] = "#ffffff"
  text[INSENSITIVE] = "%(off)s"
}
class "GtkWidget" style "oxt-ui-tour"
"""

PERSONALIZE = r'Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'
WINDOWS_VALUES = ('AppsUseLightTheme', 'SystemUsesLightTheme')


def log(msg=''):
    print(msg)
    sys.stdout.flush()


def print_image(name, path):
    """Prints a PNG file into the log as tools/ci/print_images.py reads it."""
    with open(path, 'rb') as f:
        data = base64.b64encode(f.read()).decode('ascii')
    parts = [data[i:i + 4000] for i in range(0, len(data), 4000)] or ['']
    for i, part in enumerate(parts):
        print('IMAGE %s %d/%d %s' % (name, i + 1, len(parts), part))
    sys.stdout.flush()


# ---------------------------------------------------------------------------
# The system's appearance

def mac_defaults(*args):
    proc = subprocess.run(('defaults',) + args, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    return proc.returncode, proc.stdout.decode('utf-8', 'replace').strip()


def set_mac(appearance):
    """Sets the Mac's setting and returns a function that restores it."""
    code, before = mac_defaults('read', '-g', 'AppleInterfaceStyle')
    if appearance == 'dark':
        mac_defaults('write', '-g', 'AppleInterfaceStyle', 'Dark')
    else:
        mac_defaults('delete', '-g', 'AppleInterfaceStyle')
    code_now, now = mac_defaults('read', '-g', 'AppleInterfaceStyle')
    log('The Mac: AppleInterfaceStyle %s' % (now if code_now == 0 else '(not set: light)'))

    def restore():
        if code == 0:
            mac_defaults('write', '-g', 'AppleInterfaceStyle', before)
        else:
            mac_defaults('delete', '-g', 'AppleInterfaceStyle')
    return restore


def set_windows(appearance):
    """Sets Windows' apps and system mode and returns a function that
    restores them."""
    import winreg
    key = winreg.CreateKeyEx(winreg.HKEY_CURRENT_USER, PERSONALIZE, 0,
                             winreg.KEY_READ | winreg.KEY_SET_VALUE)
    before = {}
    for name in WINDOWS_VALUES:
        try:
            before[name] = winreg.QueryValueEx(key, name)[0]
        except OSError:
            before[name] = None
        winreg.SetValueEx(key, name, 0, winreg.REG_DWORD, 0 if appearance == 'dark' else 1)
    log('Windows: %s' % ', '.join('%s %s (was %s)' % (n, 0 if appearance == 'dark' else 1, before[n])
                                  for n in WINDOWS_VALUES))

    def restore():
        for name, value in before.items():
            if value is None:
                try:
                    winreg.DeleteValue(key, name)
                except OSError:
                    pass
            else:
                winreg.SetValueEx(key, name, 0, winreg.REG_DWORD, value)
        winreg.CloseKey(key)
    return restore


def linux_gtkrc(appearance, work):
    """The gtkrc for GTK2_RC_FILES."""
    if os.path.isfile(ADWAITA[appearance]):
        log('GTK theme: %s' % ADWAITA[appearance])
        return ADWAITA[appearance]
    path = os.path.join(work, 'gtkrc-%s' % appearance)
    with open(path, 'w', encoding='utf-8') as f:
        f.write(GTKRC % PLAIN[appearance])
    log('GTK theme: plain %s colours (%s); Adwaita is not installed' % (appearance, path))
    return path


# ---------------------------------------------------------------------------
# The run

def stop(proc):
    """Ends the engine and anything it started (xvfb-run's Xvfb)."""
    if proc.poll() is not None:
        return
    if os.name == 'nt':
        subprocess.run(['taskkill', '/T', '/F', '/PID', str(proc.pid)], stdout=subprocess.DEVNULL,
                       stderr=subprocess.DEVNULL)
    else:
        try:
            os.killpg(proc.pid, signal.SIGTERM)
        except OSError:
            pass
        try:
            proc.wait(10)
        except subprocess.TimeoutExpired:
            try:
                os.killpg(proc.pid, signal.SIGKILL)
            except OSError:
                pass
    try:
        proc.wait(30)
    except subprocess.TimeoutExpired:
        pass


def read_lines(path):
    if not os.path.isfile(path):
        return []
    with open(path, encoding='utf-8', errors='replace') as f:
        return [x.rstrip('\r\n') for x in f if x.strip()]


def mac_screen(path):
    """The whole screen, for when the script did not end (screencapture)."""
    if shutil.which('screencapture'):
        subprocess.run(['screencapture', '-x', path], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                       timeout=60)
        if os.path.isfile(path) and shutil.which('sips'):
            subprocess.run(['sips', '-Z', '1200', path, '--out', path], stdout=subprocess.DEVNULL,
                           stderr=subprocess.DEVNULL, timeout=60)
    return os.path.isfile(path)


# What a Mac's IDE says about itself when it stopped: the engine answers
# AppleScript's "evaluate" (engine/rsrc/terminology.sdef) from its event
# loop, which a sample showed idle, so these say which start-up step it
# never finished and the error that stopped it
MAC_QUESTIONS = (
    'the cREVLaunching of stack "Home"',
    'the statusMessage of stack "revSplash"',
    'the defaultStack',
    'the openStacks',
    'the pendingMessages',
    'the cLastError of card 1 of stack "revErrorDisplay"',
    'the cCurrentObject of card 1 of stack "revErrorDisplay"',
    'the executionError of stack "revErrorDisplay"',
    'the mode of stack "revErrorDisplay" && the visible of stack "revErrorDisplay" && '
    'the rect of stack "revErrorDisplay"',
    'the mode of stack "revTools" && the visible of stack "revTools" && the blendLevel of stack "revTools" && '
    'the number of controls of stack "revTools" && the rect of stack "revTools"',
)


def mac_ask(app, questions=MAC_QUESTIONS, timeout=20):
    """Ask the running IDE at app (its .app) each of questions, logging each
    answer. False when the engine could not be asked: osascript missing, the
    app's bundle id unread, or no answer in timeout seconds (macOS may be
    asking whether the runner may control the app)."""
    import plistlib
    if not shutil.which('osascript'):
        return False
    try:
        with open(os.path.join(app, 'Contents', 'Info.plist'), 'rb') as f:
            bundle = plistlib.load(f)['CFBundleIdentifier']
    except (OSError, KeyError, ValueError, plistlib.InvalidFileException):
        return False
    log('::group::What the IDE says (AppleScript to %s)' % bundle)
    try:
        for q in questions:
            text = 'tell application id "%s" to evaluate "%s"' % (
                bundle, q.replace('\\', '\\\\').replace('"', '\\"'))
            try:
                proc = subprocess.run(['osascript', '-e', text], stdout=subprocess.PIPE,
                                      stderr=subprocess.STDOUT, timeout=timeout)
            except subprocess.TimeoutExpired:
                log('%s: no answer in %d s; asking no more' % (q, timeout))
                return False
            except OSError as e:
                log('%s: %s' % (q, e))
                return False
            answer = proc.stdout.decode('utf-8', 'replace').strip().replace('\r', '\n')
            log('%s:%s%s' % (q, '\n' if '\n' in answer else ' ', answer or '(empty)'))
    finally:
        log('::endgroup::')
    return True


def mac_tools_log(lines=400):
    """Log the IDE's own log of its last start-up (revInternal__Log in
    ide/Toolset/home.livecodescript), at most its last lines lines, the
    clock's time now beside it, and what macOS logged of the clock being
    set while the IDE ran: the engine's pending messages wait on the wall
    clock (gettimeofday), so a clock set back holds every one of them."""
    path = os.path.expanduser('~/Library/Logs/OXT-Beyond/OXT-BeyondToolsLog.txt')
    if not os.path.isfile(path):
        log('(no IDE tools log at %s)' % path)
        return False
    with open(path, encoding='utf-8', errors='replace') as f:
        text = f.read().replace('\r', '\n').splitlines()
    starts = [i for i, x in enumerate(text) if 'Startup Started' in x]
    if starts:
        text = text[starts[-1]:]
    log('::group::The IDE\'s tools log of its last start-up (last %d of %d lines; the time now %.3f)' % (
        min(lines, len(text)), len(text), time.time()))
    for x in text[-lines:]:
        log(x)
    log('::endgroup::')
    if shutil.which('log'):
        try:
            proc = subprocess.run(['log', 'show', '--last', '15m', '--style', 'compact', '--predicate',
                                   'process == "timed" OR eventMessage CONTAINS[c] "settimeofday"'],
                                  stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=120)
            found = proc.stdout.decode('utf-8', 'replace').splitlines()
            log('::group::The clock set while the IDE ran (macOS log, timed: %d lines)' % len(found))
            for x in found[-60:]:
                log(x)
            log('::endgroup::')
        except (subprocess.TimeoutExpired, OSError) as e:
            log('(the macOS log could not be read: %s)' % e)
    return True


def mac_app(engine):
    """The .app an engine path is inside, or None."""
    return engine[:engine.index('.app/') + 4] if '.app/' in engine else None


# The binaries the package renames: OXT-Beyond.app's engine is the
# build's LiveCode-Community.app, whose dSYM keeps the build's name
MAC_BUILD_NAMES = {'OXT-Beyond': 'LiveCode-Community'}


def mac_dwarf(name):
    """The DWARF file of the binary name in the dSYM bundles under
    $OXT_DSYM_DIR (the build's debug symbols, which the macOS test job
    unpacks there), or None."""
    root = os.environ.get('OXT_DSYM_DIR')
    if not root or not os.path.isdir(root):
        return None
    names = [name, MAC_BUILD_NAMES.get(name)]
    for d, dirs, files in os.walk(root):
        if os.path.basename(d) == 'DWARF':
            for n in names:
                if n and n in files:
                    return os.path.join(d, n)
    return None


def mac_symbolicate(graph):
    """graph, a sample's call graph, with the engine's frames, which the
    stripped binary leaves as "??? (in OXT-Beyond)", named by atos from
    its dSYM where there is one."""
    pattern = re.compile(r'\?\?\?  \(in (\S+)\)  load address (0x[0-9a-f]+) \+ 0x[0-9a-f]+  \[(0x[0-9a-f]+)\]')
    frames = [m for m in (pattern.search(x) for x in graph) if m]
    if not frames or not shutil.which('atos'):
        return graph
    dwarf = mac_dwarf(frames[0].group(1))
    if not dwarf:
        log('(no dSYM for %s under $OXT_DSYM_DIR: the engine\'s frames stay unnamed)' % frames[0].group(1))
        return graph
    addresses = sorted(set(m.group(3) for m in frames if m.group(1) == frames[0].group(1)))
    try:
        proc = subprocess.run(['atos', '-o', dwarf, '-arch', os.uname().machine, '-l', frames[0].group(2)] + addresses,
                              stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, timeout=120)
    except (subprocess.TimeoutExpired, OSError):
        return graph
    names = dict(zip(addresses, proc.stdout.decode('utf-8', 'replace').splitlines()))
    out = []
    for x in graph:
        m = pattern.search(x)
        if m and m.group(3) in names:
            x = x[:m.start()] + names[m.group(3)] + '  [%s]' % m.group(3) + x[m.end():]
        out.append(x)
    return out


def mac_sample(pid, path, seconds=5, lines=400):
    """Where the engine is, for when the script did not end on a Mac: the
    process's state, then a sample of it (sample, as field_speed_test.py
    takes one) into path, whose main thread's call graph goes into the log
    too, as the job's log is read where its artifacts cannot be fetched.
    An IDE that sometimes stopped at start-up left only a screenshot of its
    splash; this says which handler it was in."""
    if not shutil.which('sample'):
        return False
    try:
        state = subprocess.run(['ps', '-o', 'stat=,rss=,pcpu=', '-p', str(pid)], stdout=subprocess.PIPE,
                               stderr=subprocess.STDOUT, timeout=30)
        log('(the engine, pid %d: %s)' % (pid, ' '.join(state.stdout.decode('utf-8', 'replace').split()) or 'gone'))
        subprocess.run(['sample', str(pid), str(seconds), '-file', path], stdout=subprocess.DEVNULL,
                       stderr=subprocess.DEVNULL, timeout=seconds + 60)
    except (subprocess.TimeoutExpired, OSError):
        return False
    if not os.path.isfile(path):
        return False
    # the call graph of the first thread (the main thread), cut at lines
    with open(path, encoding='utf-8', errors='replace') as f:
        text = f.read().splitlines()
    try:
        start = next(i for i, x in enumerate(text) if x.startswith('Call graph:'))
    except StopIteration:
        return True
    graph = []
    for x in text[start + 1:]:
        # each thread starts "    <count> Thread_<id> ..."; its frames are
        # "    + ..." under it
        if not x.strip() or (graph and re.match(r'^    \d+ Thread_', x)):
            break
        graph.append(x.rstrip())
    graph = mac_symbolicate(graph)
    log('::group::The engine\'s main thread (%s)' % os.path.basename(path))
    for x in graph[:lines]:
        log(x)
    if len(graph) > lines:
        log('... (%d lines more in %s)' % (len(graph) - lines, os.path.basename(path)))
    log('::endgroup::')
    return True


# Where macOS's crash reporter writes a report (a .ips file; a .crash
# before macOS 12) some seconds after a process crashed, as it puts up
# "<app> quit unexpectedly" over whatever runs next: main's tour on Apple
# silicon showed one over the dark run's windows, from an IDE that had
# crashed as stop ended the light run, and no report reached the log
MAC_CRASH_DIRS = ('~/Library/Logs/DiagnosticReports', '/Library/Logs/DiagnosticReports')


def mac_crash_reports(name, since):
    """The crash reports of the process name written since since (a
    time.time()), oldest first."""
    found = []
    for d in MAC_CRASH_DIRS:
        d = os.path.expanduser(d)
        try:
            names = os.listdir(d)
        except OSError:
            continue
        for n in names:
            if not (n.startswith(name) and n[len(name):len(name) + 1] in ('-', '_')
                    and n.endswith(('.ips', '.crash'))):
                continue
            try:
                when = os.path.getmtime(os.path.join(d, n))
            except OSError:
                continue
            if when >= since:
                found.append((when, os.path.join(d, n)))
    return [path for when, path in sorted(found)]


def mac_crash_frames(frames, images, lines):
    """Lines for frames, a thread's in a .ips report: each frame's image,
    address and symbol, the frames in the app's own binaries (the engine,
    the externals) named by atos from the build's dSYMs where there are
    any, as the stripped engine's have no names of their own."""
    def image_of(f):
        i = f.get('imageIndex')
        return i if isinstance(i, int) and 0 <= i < len(images) else None

    named = {}
    wanted = {}
    for f in frames[:lines]:
        i = image_of(f)
        if i is not None and isinstance(f.get('imageOffset'), int):
            wanted.setdefault(i, set()).add(images[i].get('base', 0) + f['imageOffset'])
    for i, addresses in wanted.items():
        image = images[i]
        if '.app/' not in image.get('path', '') or not shutil.which('atos'):
            continue
        dwarf = mac_dwarf(image.get('name', ''))
        if not dwarf:
            continue
        addresses = sorted(addresses)
        try:
            proc = subprocess.run(['atos', '-o', dwarf, '-arch', image.get('arch') or os.uname().machine,
                                   '-l', hex(image.get('base', 0))] + [hex(a) for a in addresses],
                                  stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, timeout=120)
        except (subprocess.TimeoutExpired, OSError):
            continue
        for a, s in zip(addresses, proc.stdout.decode('utf-8', 'replace').splitlines()):
            named[(i, a)] = s.strip()

    out = []
    for n, f in enumerate(frames[:lines]):
        i = image_of(f)
        image = images[i] if i is not None else {}
        offset = f.get('imageOffset') if isinstance(f.get('imageOffset'), int) else 0
        address = image.get('base', 0) + offset
        what = named.get((i, address))
        if not what and f.get('symbol'):
            what = f['symbol'] + (' + %d' % f['symbolLocation'] if isinstance(f.get('symbolLocation'), int) else '')
        out.append('%3d  %-28s 0x%x  %s' % (n, image.get('name', '???'), address, what or '+ 0x%x' % offset))
    if len(frames) > lines:
        out.append('     ... (%d frames more)' % (len(frames) - lines))
    return out


def mac_crash_report(path, pid=None, lines=50):
    """Log a crash report: the process, what ended it and what it said as
    it ended (an abort's message, an uncaught exception's reason), an
    uncaught exception's backtrace, and the frames of the thread that
    crashed and of the main thread."""
    try:
        with open(path, encoding='utf-8', errors='replace') as f:
            text = f.read()
    except OSError as e:
        log('(the crash report %s could not be read: %s)' % (path, e))
        return
    log('::group::A crash report: %s' % os.path.basename(path))
    try:
        # a .ips is a line of JSON about the report, then the report
        try:
            report = json.loads(text.partition('\n')[2])
        except ValueError:
            report = None
        if not isinstance(report, dict):
            # a .crash is text already
            for x in text.splitlines()[:lines * 4]:
                log(x)
            return
        who = report.get('pid')
        log('Process     : %s [%s]%s' % (report.get('procName'), who,
                                         ' (this run\'s engine)' if pid is not None and who == pid else ''))
        log('Path        : %s' % report.get('procPath'))
        log('Captured    : %s' % report.get('captureTime'))
        exc = report.get('exception') or {}
        log('Exception   : %s' % ' '.join(str(exc[k]) for k in ('type', 'signal', 'subtype') if exc.get(k)))
        if (report.get('termination') or {}).get('indicator'):
            log('Termination : %s' % report['termination']['indicator'])
        for k, v in sorted((report.get('asi') or {}).items()):
            log('It said     : %s: %s' % (k, ' | '.join(str(x) for x in v) if isinstance(v, list) else v))
        images = report.get('usedImages') or []
        if report.get('lastExceptionBacktrace'):
            log('The uncaught exception\'s backtrace:')
            for x in mac_crash_frames(report['lastExceptionBacktrace'], images, lines):
                log(x)
        threads = report.get('threads') or []
        crashed = report.get('faultingThread', 0)
        for n in [crashed] + ([0] if crashed != 0 else []):
            if not (isinstance(n, int) and 0 <= n < len(threads)):
                continue
            t = threads[n]
            label = t.get('name') or t.get('queue')
            log('Thread %d%s%s:' % (n, ' (crashed)' if n == crashed else ' (the main thread)',
                                    ', %s' % label if label else ''))
            for x in mac_crash_frames(t.get('frames') or [], images, lines):
                log(x)
    finally:
        log('::endgroup::')


def mac_crashes(name, since, pid, returncode, wait=45):
    """Log the crash reports of name (the engine's binary) written since
    since, a time.time(), and return how many. The report comes some
    seconds after the crash, so when the engine ended on a signal that
    was not stop's (SIGTERM, SIGKILL) this waits up to wait seconds for
    it; otherwise it looks once."""
    crashed = returncode is not None and returncode < 0 and -returncode not in (signal.SIGTERM, signal.SIGKILL)
    deadline = time.time() + (wait if crashed else 0)
    while True:
        found = mac_crash_reports(name, since)
        if found or time.time() >= deadline:
            break
        time.sleep(1)
    if crashed and not found:
        log('(the engine ended on signal %d, and no crash report came in %d s)' % (-returncode, wait))
    for path in found:
        mac_crash_report(path, pid)
    return len(found)


def main(argv=None):
    ap = argparse.ArgumentParser(description='Screenshots of the IDE\'s windows, light or dark.')
    ap.add_argument('--install', metavar='DIR', help='installed layout')
    ap.add_argument('--package', metavar='FILE', help='a package to extract and run like --install')
    ap.add_argument('--platform', choices=list(package.PLATFORMS),
                    help='the layout (default: this machine\'s, %s)' % rlc.default_platform())
    ap.add_argument('--out', required=True, metavar='DIR', help='folder for the snapshots and the logs')
    ap.add_argument('--appearance', choices=('light', 'dark'), default='light',
                    help='the system\'s appearance (default: %(default)s)')
    ap.add_argument('--only', default='', help='comma-separated steps of the script to run (default: all)')
    ap.add_argument('--timeout', type=int, default=600, help='seconds for the whole run (default: %(default)s)')
    ap.add_argument('--script', default=SCRIPT, help='the script to run in the IDE (default: %(default)s)')
    args = ap.parse_args(argv)
    if bool(args.install) == bool(args.package):
        ap.error('pass --install or --package')
    p = package.PLATFORMS[args.platform or rlc.default_platform()]

    out = os.path.abspath(args.out)
    shots = os.path.join(out, 'shots')
    if os.path.isdir(out):
        shutil.rmtree(out)
    os.makedirs(shots)
    results = os.path.join(out, 'tour.txt')
    document = os.path.join(out, 'oxt_ui_tour.livecodescript')
    shutil.copyfile(args.script, document)

    temp_dirs, restore, finished, problems = [], None, False, []
    try:
        args.bin_dir, args.engine = None, None
        lay = rlc.find_layout(args, p, temp_dirs)
        log('Layout     : %s' % lay.root)
        log('Engine     : %s' % lay.engine)
        log('Appearance : %s' % args.appearance)

        env = dict(os.environ)
        env.update({
            'OXT_TOUR_OUT': shots.replace('\\', '/'),
            'OXT_TOUR_LOG': results.replace('\\', '/'),
            'OXT_TOUR_APPEARANCE': args.appearance,
            'OXT_TOUR_ONLY': args.only,
        })
        cmd = [lay.engine, document]
        if p.family == 'mac':
            restore = set_mac(args.appearance)
        elif p.family == 'windows':
            restore = set_windows(args.appearance)
        else:
            env['GTK2_RC_FILES'] = linux_gtkrc(args.appearance, out)
            # as the launcher does (Installer/linux/oxt-beyond), which this
            # does not run: a package without CEF (arm64) has no browser
            # widget, and the IDE then opens the dictionary in the system's
            # browser
            if 'LIVECODE_USE_CEF' not in env and \
                    not os.path.isfile(os.path.join(lay.externals, 'CEF', 'libcef.so')):
                env['LIVECODE_USE_CEF'] = '0'
                log('Browser    : none (no Externals/CEF/libcef.so): LIVECODE_USE_CEF=0')
            if not env.get('DISPLAY'):
                xvfb = shutil.which('xvfb-run')
                if not xvfb:
                    raise rlc.CheckError('no DISPLAY and no xvfb-run')
                cmd = [xvfb, '-a', '-s', '-screen 0 1440x900x24'] + cmd

        log('Running    : %s' % ' '.join(cmd))
        started = time.time()
        progress = started
        opened_again = False
        status = 'did not finish in %d s' % args.timeout
        with open(os.path.join(out, 'engine-output.txt'), 'wb') as engine_log:
            kw = {'creationflags': subprocess.CREATE_NEW_PROCESS_GROUP} if os.name == 'nt' else \
                {'start_new_session': True}
            proc = subprocess.Popen(cmd, cwd=out, env=env, stdout=engine_log, stderr=subprocess.STDOUT, **kw)
            try:
                while time.time() - started < args.timeout:
                    lines = read_lines(results)
                    if any(x.startswith('DONE') for x in lines):
                        finished = True
                        status = 'finished after %.0f s' % (time.time() - started)
                        break
                    if proc.poll() is not None:
                        status = 'the engine ended with exit status %s after %.0f s' % (
                            proc.returncode, time.time() - started)
                        break
                    if (p.family == 'mac' and not opened_again and not lines
                            and time.time() - started > 60 and shutil.which('open')):
                        # the engine did not open the document it was
                        # started with: send it as Finder would
                        opened_again = True
                        app = lay.engine[:lay.engine.index('.app/') + 4]
                        log('No line from the script after 60 s: open -a %s %s' % (app, document))
                        subprocess.run(['open', '-a', app, document])
                    if time.time() - progress >= 15:
                        progress = time.time()
                        log('after %.0f s: %s' % (progress - started, lines[-1] if lines else '(no lines yet)'))
                    time.sleep(0.5)
                if not finished and p.family == 'mac' and proc.poll() is None:
                    if mac_screen(os.path.join(shots, 'zz-screen-at-the-end.png')):
                        log('(the screen when the run stopped: zz-screen-at-the-end.png)')
                    mac_sample(proc.pid, os.path.join(out, 'sample-at-the-end.txt'))
                    if mac_app(lay.engine):
                        mac_ask(mac_app(lay.engine))
                    mac_tools_log()
            finally:
                stop(proc)
        log('The script %s.' % status)
        if not finished:
            problems.append('the script %s' % status)
        if p.family == 'mac':
            # a crash as the engine ended fails no step of the tour: the
            # report goes into the log, with a warning
            log('The engine ended with exit status %s.' % proc.returncode)
            crashes = mac_crashes(os.path.basename(lay.engine), started, proc.pid, proc.returncode)
            if crashes and os.environ.get('GITHUB_ACTIONS'):
                log('::warning title=IDE screenshots (%s)::macOS wrote %d crash report(s) of %s during this run '
                    '(see "A crash report" in the log)' % (args.appearance, crashes, os.path.basename(lay.engine)))
    except (rlc.CheckError, OSError) as e:
        problems.append(str(e))
    finally:
        if restore:
            restore()
        for d in temp_dirs:
            shutil.rmtree(d, ignore_errors=True)

    lines = read_lines(results)
    log('')
    log('::group::The script\'s lines (%s)' % args.appearance)
    for x in lines:
        log(x)
    log('::endgroup::')
    failed = [x for x in lines if x.startswith('STEP ') and ' FAILED' in x]
    problems += [x[5:] for x in failed]
    problems += ['script error: %s' % x[6:] for x in lines if x.startswith('ERROR ')]

    tail = read_lines(os.path.join(out, 'engine-output.txt'))[-60:]
    if tail:
        log('::group::The engine\'s output (last lines)')
        for x in tail:
            log(x)
        log('::endgroup::')

    names = sorted(n for n in os.listdir(shots) if n.lower().endswith('.png'))
    log('::group::Snapshots (%d, base64 for tools/ci/print_images.py)' % len(names))
    for name in names:
        print_image('%s/%s' % (args.appearance, name), os.path.join(shots, name))
    log('::endgroup::')

    for msg in problems:
        log('::warning title=IDE screenshots (%s)::%s' % (args.appearance, msg) if os.environ.get('GITHUB_ACTIONS')
            else 'problem: %s' % msg)
    log('IDE screenshots (%s): %d snapshots, %s.' % (args.appearance, len(names),
                                                      'every step done' if not problems
                                                      else '%d problems' % len(problems)))
    return 0 if not problems else 1


if __name__ == '__main__':
    sys.exit(main())
