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

"""Check on Windows that a standard button, an option menu and a combo box
are drawn for the appearance Windows has (light or dark): when the engine
starts in it, and when Windows is switched to it while the engine runs.

  python tools/ci/dark_switch_check.py (--install DIR | --package FILE)
      [--platform P] [--log FILE] [--timeout SECONDS] [--need-visual-styles]

The layout's standalone runtime is copied to a folder of its own
(media_check.stage_runtime) and runs tools/ci/dark-switch-check.livecodescript,
which opens a stack with the three controls, none with a colour of its own,
and measures each from a snapshot when this script tells it to: its face
(the colour most of its inside has) and its ink (the colour there that
differs most from the face: its label). This script sets Windows'
appearance, the value AppsUseLightTheme that applications follow, as
Settings > Personalization > Colors does, and puts it back when it is done.
The engine is started twice (RUNS):

  starts dark   the appearance is dark when the engine starts; then it is
                switched to light with no notice;
  starts light  it is light when the engine starts; then it is switched to
                dark with no notice, to light with Windows' notice, and to
                dark with it.

"With Windows' notice" is how Settings does it: the value is written and
every top-level window is sent WM_SETTINGCHANGE "ImmersiveColorSet" (here
the engine's own windows are). "With no notice" writes the value and
nothing else: a program that only believes the notice then draws for the
appearance it was last told of. After each step:

  1. each control's face is dark in the dark appearance and light in the
     light one, and its ink stands out from it;
  2. the systemAppearance is the appearance that was set;
  3. after a switch, the stack was sent systemAppearanceChanged.

The same reading of each control taken from the screen, after the control
was drawn again, is reported beside them and not checked.

Up to OXT-Beyond 0.2.7 the dark appearance filled a button, an option menu
and a combo box with a background colour the engine kept from its start or
from Windows' last notice, under words in the colour of the appearance read
as they were drawn: switched to dark with no notice they were light grey
with white words, a white button with white text (openxtalk.org p=26224).

The fault needs visual styles (without them the engine draws the controls
itself, with colours it reads each time), which Windows 10 and 11 have as
people use them and the Windows Server sessions of the CI runners have only
when the Themes service is started: the results say whether they are on,
and --need-visual-styles makes it a failure when they are not.

Windows only (elsewhere it reports that and exits 0). Needs the runner's
desktop, as media_check.py does. Exit status 0 when every check passed, 1
otherwise. Under GitHub Actions failures are annotations and the results
go into the job summary. Only the Python 3 standard library is used.
"""

import argparse
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(os.path.dirname(HERE), 'oxt'))
sys.path.insert(0, HERE)
import package  # noqa: E402
import run_livecode_check as rlc  # noqa: E402
import media_check  # noqa: E402

SCRIPT = os.path.join(HERE, 'dark-switch-check.livecodescript')
CONTROLS = ('Push', 'Option', 'Combo')
PERSONALIZE = r'Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'
VALUE = 'AppsUseLightTheme'

# (name, the appearance the engine starts in,
#  ((label, the appearance to switch to, whether Windows' notice is sent), ...))
RUNS = (
    ('starts dark', 'dark', (('quiet-light', 'light', False),)),
    ('starts light', 'light', (('quiet-dark', 'dark', False), ('told-light', 'light', True),
                               ('told-dark', 'dark', True))),
)

# A face is dark below DARK_FACE and light above LIGHT_FACE (luma, 0-255:
# the dark appearance's is 32, the light one's 225 to 255), and an ink
# stands out from its face when their lumas are CONTRAST apart (white on the
# light grey of the fault is 15 apart; black on it, or white on dark, 200)
DARK_FACE, LIGHT_FACE, CONTRAST = 100, 160, 90

MEASURE = re.compile(r'^(MEASURE|SCREEN) (\S+) (\S+) face=(\d+),(\d+),(\d+) ink=(\d+),(\d+),(\d+) '
                     r'size=(\d+)x(\d+)$')


def gha():
    return bool(os.environ.get('GITHUB_ACTIONS'))


def luma(rgb):
    """Rec. 601 luma of an (r, g, b), 0 to 255."""
    return (299 * rgb[0] + 587 * rgb[1] + 114 * rgb[2]) / 1000.0


def measurements(log, label, word='MEASURE'):
    """{control: (face, ink)} of a label's MEASURE lines (from a snapshot
    of each control), or of its SCREEN lines (read from the screen)."""
    out = {}
    for x in log:
        m = MEASURE.match(x)
        if m and m.group(1) == word and m.group(2) == label:
            n = [int(v) for v in m.groups()[3:9]]
            out[m.group(3)] = (tuple(n[:3]), tuple(n[3:]))
    return out


def value_of(log, word, label):
    """The last word of the line "<word> <label> <value>", or None."""
    for x in log:
        parts = x.split()
        if len(parts) == 3 and parts[0] == word and parts[1] == label:
            return parts[2]
    return None


def judge(appearance, face, ink):
    """Whether a control with this face and ink is drawn for the appearance:
    (ok, what was found)."""
    f, i = luma(face), luma(ink)
    detail = 'face %d,%d,%d, ink %d,%d,%d' % (face + ink)
    if appearance == 'dark' and f >= DARK_FACE:
        return False, detail + ': a light face in the dark appearance'
    if appearance == 'light' and f <= LIGHT_FACE:
        return False, detail + ': a dark face in the light appearance'
    if abs(f - i) < CONTRAST:
        return False, detail + ': the ink does not stand out from the face'
    return True, detail


def check_step(log, run, label, appearance, switched, check):
    """The checks of one step of a run, from the script's log."""
    name = '%s, %s' % (run, label)
    found = measurements(log, label)
    for control in CONTROLS:
        if control not in found:
            check(name, '%s is drawn for the %s appearance' % (control, appearance), False, 'not measured')
            continue
        ok, detail = judge(appearance, *found[control])
        check(name, '%s is drawn for the %s appearance' % (control, appearance), ok, detail)
    got = value_of(log, 'APPEARANCE', label)
    check(name, 'the systemAppearance is %s' % appearance, got == appearance, 'it is %s' % (got or 'not logged'))
    if switched:
        count = value_of(log, 'CHANGED', label)
        check(name, 'the stack was sent systemAppearanceChanged', bool(count) and count.isdigit() and int(count) >= 1,
              '%s times' % count if count else 'not logged')


def screen_lines(log, run, label, appearance):
    """What the screen showed at a step, as lines for the results. They are
    reported, not checked: a reading of the screen also sees whatever else
    is on it, and the snapshots above are drawn by the same code."""
    found = measurements(log, label, 'SCREEN')
    out = []
    for control in CONTROLS:
        if control not in found:
            out.append('INFO %s, %s: on the screen %s was not read' % (run, label, control))
            continue
        ok, detail = judge(appearance, *found[control])
        out.append('INFO %s, %s: on the screen %s %s (%s)'
                   % (run, label, control, 'is drawn for the %s appearance' % appearance if ok
                      else 'is NOT drawn for the %s appearance' % appearance, detail))
    return out


def read_log(path):
    if not os.path.exists(path):
        return []
    with open(path, encoding='utf-8', errors='replace') as f:
        return [x.rstrip('\r\n') for x in f if x.strip()]


class Windows:
    """The setting and the few user32/uxtheme/dwmapi calls the check needs."""

    WM_SETTINGCHANGE = 0x001A
    SMTO_ABORTIFHUNG = 0x0002
    DWMWA_USE_IMMERSIVE_DARK_MODE = 20

    def __init__(self):
        import ctypes
        import winreg
        from ctypes import wintypes
        self.ct, self.wt, self.winreg = ctypes, wintypes, winreg
        self.user32 = ctypes.WinDLL('user32', use_last_error=True)
        self.user32.SendMessageTimeoutW.argtypes = [wintypes.HWND, wintypes.UINT, wintypes.WPARAM, ctypes.c_wchar_p,
                                                    wintypes.UINT, wintypes.UINT, ctypes.POINTER(ctypes.c_size_t)]
        self.user32.SendMessageTimeoutW.restype = ctypes.c_ssize_t
        self.user32.GetWindowThreadProcessId.argtypes = [wintypes.HWND, ctypes.POINTER(wintypes.DWORD)]
        self.key = winreg.CreateKeyEx(winreg.HKEY_CURRENT_USER, PERSONALIZE, 0,
                                      winreg.KEY_READ | winreg.KEY_SET_VALUE)
        try:
            self.before = winreg.QueryValueEx(self.key, VALUE)[0]
        except OSError:
            self.before = None

    def set_appearance(self, appearance):
        self.winreg.SetValueEx(self.key, VALUE, 0, self.winreg.REG_DWORD, 0 if appearance == 'dark' else 1)

    def restore(self):
        if self.before is None:
            try:
                self.winreg.DeleteValue(self.key, VALUE)
            except OSError:
                pass
        else:
            self.winreg.SetValueEx(self.key, VALUE, 0, self.winreg.REG_DWORD, self.before)
        self.winreg.CloseKey(self.key)

    def themed(self):
        """Whether visual styles are on (uxtheme IsThemeActive)."""
        try:
            return bool(self.ct.WinDLL('uxtheme').IsThemeActive())
        except (OSError, AttributeError):
            return False

    def tell(self, pid):
        """Send Windows' notice of a changed appearance to each top-level
        window of a process, and wait for each to take it; how many."""
        windows = []
        proc_type = self.ct.WINFUNCTYPE(self.wt.BOOL, self.wt.HWND, self.wt.LPARAM)

        def each(hwnd, _):
            owner = self.wt.DWORD()
            self.user32.GetWindowThreadProcessId(hwnd, self.ct.byref(owner))
            if owner.value == pid:
                windows.append(hwnd)
            return True
        self.user32.EnumWindows(proc_type(each), 0)
        for hwnd in windows:
            result = self.ct.c_size_t()
            self.user32.SendMessageTimeoutW(hwnd, self.WM_SETTINGCHANGE, 0, 'ImmersiveColorSet',
                                            self.SMTO_ABORTIFHUNG, 5000, self.ct.byref(result))
        return len(windows)

    def dark_title_bar(self, hwnd):
        """What DWM says of a window's dark title bar, where it tells
        (DWMWA_USE_IMMERSIVE_DARK_MODE): True, False or None."""
        try:
            dwmapi = self.ct.WinDLL('dwmapi')
        except OSError:
            return None
        v = self.wt.BOOL()
        hr = dwmapi.DwmGetWindowAttribute(self.wt.HWND(hwnd), self.DWMWA_USE_IMMERSIVE_DARK_MODE,
                                          self.ct.byref(v), self.ct.sizeof(v))
        return bool(v.value) if hr == 0 else None


def wait_for(log_path, wanted, seconds, proc):
    """Wait until the log has the line wanted (or an ERROR, or the engine
    is gone); the log, and whether the line came."""
    end = time.time() + seconds
    while True:
        log = read_log(log_path)
        if wanted in log:
            return log, True
        if any(x.startswith('ERROR ') or x == 'DONE' for x in log) or proc.poll() is not None \
                or time.time() >= end:
            return read_log(log_path), wanted in read_log(log_path)
        time.sleep(0.05)


def run_engine(w, engine, work, run, start, steps, timeout, lines, problems, check):
    """One start of the engine: the appearance it starts in, then the
    steps. Appends to lines and problems."""
    slug = run.replace(' ', '-')
    log_path = os.path.join(work, 'dark-switch-%s.log' % slug)
    go_path = os.path.join(work, 'go-%s' % slug)
    env = dict(os.environ)
    env.update({'OXT_DARK_LOG': log_path.replace('\\', '/'), 'OXT_DARK_GO': go_path.replace('\\', '/')})
    w.set_appearance(start)
    proc = subprocess.Popen([engine, SCRIPT], cwd=work, env=env,
                            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    plan = (('start', start, None),) + tuple(steps)
    number, stopped = 0, False
    try:
        for label, appearance, told in plan:
            number += 1
            log, ok = wait_for(log_path, 'STEP %d' % number, timeout, proc)
            if not ok:
                problems.append('%s: the script did not reach step %d (%s) within %d seconds'
                                % (run, number, label, timeout))
                stopped = True
                break
            if told is not None:
                w.set_appearance(appearance)
                how = 'with no notice'
                if told:
                    how = 'with Windows\' notice to %d windows' % w.tell(proc.pid)
                lines.append('INFO %s, %s: switched to %s %s' % (run, label, appearance, how))
            with open('%s.%d' % (go_path, number), 'w') as f:
                f.write(label + '\n')
            log, ok = wait_for(log_path, 'MEASURED ' + label, timeout, proc)
            if not ok:
                problems.append('%s: no measurements of %s within %d seconds' % (run, label, timeout))
                stopped = True
                break
            check_step(log, run, label, appearance, told is not None, check)
            lines += screen_lines(log, run, label, appearance)
            window = value_of(log, 'WINDOW', 'DarkSwitch')
            if window and window.isdigit():
                lines.append('INFO %s, %s: DWM says of the dark title bar: %s'
                             % (run, label, w.dark_title_bar(int(window))))
        if not stopped:
            with open('%s.%d' % (go_path, number + 1), 'w') as f:
                f.write('quit\n')
            try:
                proc.wait(timeout=30)
            except subprocess.TimeoutExpired:
                problems.append('%s: the engine did not quit' % run)
    finally:
        if proc.poll() is None:
            proc.kill()
    log = read_log(log_path)
    lines += ['%s (%s)' % (x, run) for x in log if x.startswith(('INFO ', 'ERROR '))]
    problems += ['%s: %s' % (run, x[6:]) for x in log if x.startswith('ERROR ')]
    return log


def main(argv=None):
    ap = argparse.ArgumentParser(description='Check that buttons are drawn for Windows\' appearance, at the '
                                             'engine\'s start and when it is switched (Windows).')
    ap.add_argument('--install', metavar='DIR', help='installed layout')
    ap.add_argument('--package', metavar='FILE', help='a package to extract and check like --install')
    ap.add_argument('--platform', choices=list(package.PLATFORMS),
                    help='the layout (default: this machine\'s, %s)' % rlc.default_platform())
    ap.add_argument('--log', metavar='FILE', help='write the results here too')
    ap.add_argument('--timeout', type=int, default=60, help='seconds for each step (default: %(default)s)')
    ap.add_argument('--need-visual-styles', action='store_true',
                    help='fail when visual styles are off (the Themes service is not running)')
    args = ap.parse_args(argv)
    if bool(args.install) == bool(args.package):
        ap.error('pass --install or --package')
    p = package.PLATFORMS[args.platform or rlc.default_platform()]
    if p.family != 'windows' or os.name != 'nt':
        rlc.log('Dark switch check: Windows only; nothing to check for %s.' % p.name)
        return 0

    lines, problems, temp_dirs, w = [], [], [], None

    def check(name, what, ok, detail):
        line = '%s %s: %s (%s)' % ('PASS' if ok else 'FAIL', name, what, detail)
        lines.append(line)
        if not ok:
            problems.append(line[5:])

    try:
        base = os.environ.get('RUNNER_TEMP') or tempfile.gettempdir()
        work = tempfile.mkdtemp(prefix='oxt-dark-', dir=base)
        temp_dirs.append(work)
        args.bin_dir, args.engine = None, None
        lay = rlc.find_layout(args, p, temp_dirs)
        rlc.log('Layout  : %s' % lay.root)
        engine, _ = media_check.stage_runtime(lay.tools, p, work)
        rlc.log('Engine  : %s' % engine)
        w = Windows()
        themed = w.themed()
        lines.append('INFO visual styles %s; %s was %s' % ('on' if themed else 'off', VALUE, w.before))
        if not themed:
            lines.append('INFO without visual styles the engine draws the controls itself: the Windows theme\'s '
                         'dark buttons, which this check was written for, are not drawn here')
            if args.need_visual_styles:
                problems.append('visual styles are off (is the Themes service running?)')
        for run, start, steps in RUNS:
            run_engine(w, engine, work, run, start, steps, args.timeout, lines, problems, check)
    except (rlc.CheckError, OSError) as e:
        problems.append(str(e))
    finally:
        if w is not None:
            w.restore()
        for d in temp_dirs:
            shutil.rmtree(d, ignore_errors=True)

    rlc.log('')
    for x in lines:
        rlc.log(x)
    for msg in problems:
        rlc.log('::error title=Dark switch check::%s' % msg if gha() else 'error: %s' % msg)
    result = 'passed' if not problems else 'FAILED (%d problems)' % len(problems)
    rlc.log('Dark switch check %s.' % result)
    rlc._append('GITHUB_STEP_SUMMARY', '### Dark switch check (%s)\n\n%s\n\nResult: **%s**\n\n'
                % (p.name, '\n'.join('- ' + x for x in lines), result))
    if args.log:
        with open(args.log, 'w', encoding='utf-8', newline='\n') as f:
            f.write('\n'.join(lines + problems + [result]) + '\n')
    return 1 if problems else 0


if __name__ == '__main__':
    sys.exit(main())
