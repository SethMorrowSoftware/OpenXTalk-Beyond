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

"""Check on Windows that a stack's minimize button minimizes it, including
a stack opened the way the IDE opens its menubar (translucent at first).

  python tools/ci/window_frame_check.py (--install DIR | --package FILE)
      [--platform P] [--log FILE] [--timeout SECONDS]

The layout's standalone runtime is copied to a folder of its own
(media_check.stage_runtime) and runs tools/ci/window-frame-check.livecodescript,
which opens three stacks with a title bar and a minimize box (see that
script): FramePlain, opened as any stack is; FrameFaded, opened as the
IDE's menubar is (revmenubar.livecodescript: at blendLevel 99 with no
decorations, moved and sized, given its decorations, then blendLevel 0);
and FrameFadedTitled, at blendLevel 99 with its decorations, then 0. For
each window this script checks, from outside, with the Win32 API:

  1. the window has no window region (GetWindowRgn): a stack without a
     windowShape never sets one;
  2. where the window manager says its minimize button is (the title bar
     information, WM_GETTITLEBARINFOEX) is where DWM draws it
     (DWMWA_CAPTION_BUTTON_BOUNDS), when DWM draws the buttons;
  3. a real click (SendInput) on the minimize button DWM draws minimizes
     the window (IsIconic) and the stack gets iconifyStack.

Up to OXT-Beyond 0.2.7-rc.6.11 the IDE's menubar kept the region and
caption-button layout Windows gave it while it was translucent, so a click
on the minimize button Windows 11 draws landed on the title bar and did
nothing; FrameFaded is opened the same way. The windows are restored after
each click.

Windows only (elsewhere it reports that and exits 0). Needs the runner's
desktop, as media_check.py does. Exit status 0 when every check passed, 1
otherwise. Under GitHub Actions failures are annotations and the results
go into the job summary. Only the Python 3 standard library is used.
"""

import argparse
import os
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
import standalone_check  # noqa: E402
import media_check  # noqa: E402

SCRIPT = os.path.join(HERE, 'window-frame-check.livecodescript')
STACKS = ('FramePlain', 'FrameFaded', 'FrameFadedTitled')


def gha():
    return bool(os.environ.get('GITHUB_ACTIONS'))


class Win32:
    """The few user32/dwmapi/gdi32 calls the checks need (ctypes)."""

    WM_GETTITLEBARINFOEX = 0x033F
    DWMWA_CAPTION_BUTTON_BOUNDS = 5
    SW_RESTORE = 9
    INPUT_MOUSE = 0
    MOUSEEVENTF_LEFTDOWN = 0x0002
    MOUSEEVENTF_LEFTUP = 0x0004
    REGION_TYPES = {0: 'none', 1: 'empty', 2: 'simple', 3: 'complex'}

    def __init__(self):
        import ctypes
        from ctypes import wintypes
        self.ct, self.wt = ctypes, wintypes
        self.user32 = ctypes.WinDLL('user32', use_last_error=True)
        self.gdi32 = ctypes.WinDLL('gdi32')
        try:
            self.dwmapi = ctypes.WinDLL('dwmapi')
        except OSError:
            self.dwmapi = None
        # Physical pixels everywhere, whatever the scale
        try:
            self.user32.SetProcessDpiAwarenessContext.restype = wintypes.BOOL
            self.user32.SetProcessDpiAwarenessContext(ctypes.c_void_p(-4))
        except AttributeError:
            pass
        self.user32.SendMessageW.argtypes = [wintypes.HWND, wintypes.UINT, wintypes.WPARAM, wintypes.LPARAM]
        self.user32.SendMessageW.restype = ctypes.c_ssize_t
        self.user32.GetWindowRgn.argtypes = [wintypes.HWND, wintypes.HRGN]
        self.user32.IsIconic.argtypes = [wintypes.HWND]
        self.user32.IsWindow.argtypes = [wintypes.HWND]
        self.user32.ShowWindow.argtypes = [wintypes.HWND, ctypes.c_int]
        self.user32.SetForegroundWindow.argtypes = [wintypes.HWND]
        self.user32.GetWindowRect.argtypes = [wintypes.HWND, ctypes.POINTER(wintypes.RECT)]
        self.gdi32.CreateRectRgn.restype = wintypes.HRGN
        self.gdi32.DeleteObject.argtypes = [wintypes.HGDIOBJ]

        class TITLEBARINFOEX(ctypes.Structure):
            _fields_ = [('cbSize', wintypes.DWORD), ('rcTitleBar', wintypes.RECT),
                        ('rgstate', wintypes.DWORD * 6), ('rgrect', wintypes.RECT * 6)]

        class MOUSEINPUT(ctypes.Structure):
            _fields_ = [('dx', wintypes.LONG), ('dy', wintypes.LONG), ('mouseData', wintypes.DWORD),
                        ('dwFlags', wintypes.DWORD), ('time', wintypes.DWORD),
                        ('dwExtraInfo', ctypes.c_size_t)]

        class INPUT(ctypes.Structure):
            class _U(ctypes.Union):
                _fields_ = [('mi', MOUSEINPUT), ('pad', ctypes.c_byte * 32)]
            _anonymous_ = ('u',)
            _fields_ = [('type', wintypes.DWORD), ('u', _U)]

        self.TITLEBARINFOEX, self.INPUT = TITLEBARINFOEX, INPUT

    @staticmethod
    def rect(r):
        return (r.left, r.top, r.right, r.bottom)

    def window_rect(self, hwnd):
        r = self.wt.RECT()
        self.user32.GetWindowRect(hwnd, self.ct.byref(r))
        return self.rect(r)

    def region(self, hwnd):
        rgn = self.gdi32.CreateRectRgn(0, 0, 0, 0)
        try:
            return self.REGION_TYPES.get(self.user32.GetWindowRgn(hwnd, rgn), 'unknown')
        finally:
            self.gdi32.DeleteObject(rgn)

    def minimize_button(self, hwnd):
        """The minimize button's screen rect as the window manager has it."""
        info = self.TITLEBARINFOEX()
        info.cbSize = self.ct.sizeof(info)
        self.user32.SendMessageW(hwnd, self.WM_GETTITLEBARINFOEX, 0, self.ct.addressof(info))
        return self.rect(info.rgrect[2])

    def dwm_buttons(self, hwnd):
        """The caption buttons DWM draws, in screen coordinates, or None."""
        if self.dwmapi is None:
            return None
        r = self.wt.RECT()
        hr = self.dwmapi.DwmGetWindowAttribute(self.wt.HWND(hwnd), self.DWMWA_CAPTION_BUTTON_BOUNDS,
                                               self.ct.byref(r), self.ct.sizeof(r))
        if hr != 0 or r.right <= r.left:
            return None
        x, y = self.window_rect(hwnd)[:2]
        return (x + r.left, y + r.top, x + r.right, y + r.bottom)

    def click(self, x, y):
        self.user32.SetCursorPos(x, y)
        time.sleep(0.3)
        for flag in (self.MOUSEEVENTF_LEFTDOWN, self.MOUSEEVENTF_LEFTUP):
            inp = self.INPUT()
            inp.type = self.INPUT_MOUSE
            inp.mi.dwFlags = flag
            self.user32.SendInput(1, self.ct.byref(inp), self.ct.sizeof(inp))
            time.sleep(0.12)

    def bring_forward(self, hwnd):
        # SetForegroundWindow is refused to a process that is not in front
        # unless it just had input: a tap of Alt counts as input
        KEYEVENTF_KEYUP, VK_MENU = 0x0002, 0x12
        self.user32.keybd_event(VK_MENU, 0, 0, 0)
        self.user32.keybd_event(VK_MENU, 0, KEYEVENTF_KEYUP, 0)
        self.user32.SetForegroundWindow(hwnd)
        time.sleep(0.3)


def read_log(path):
    if not os.path.exists(path):
        return []
    with open(path, encoding='utf-8', errors='replace') as f:
        return [x.rstrip('\r\n') for x in f if x.strip()]


def wait_for(path, word, seconds):
    end = time.time() + seconds
    while time.time() < end:
        lines = read_log(path)
        if any(x == word or x.startswith(word + ' ') or x.startswith('ERROR ') for x in lines):
            return lines
        time.sleep(0.2)
    return read_log(path)


def check_window(w, name, hwnd, log_path, lines, problems):
    def check(what, ok, detail):
        line = '%s %s: %s (%s)' % ('PASS' if ok else 'FAIL', name, what, detail)
        lines.append(line)
        if not ok:
            problems.append(line[5:])

    region = w.region(hwnd)
    check('no window region', region in ('none',), 'GetWindowRgn: %s' % region)

    button = w.minimize_button(hwnd)
    dwm = w.dwm_buttons(hwnd)
    lines.append('INFO %s: window %s, minimize button %s, DWM caption buttons %s'
                 % (name, w.window_rect(hwnd), button, dwm))
    if dwm is None:
        lines.append('INFO %s: DWM draws no caption buttons here; clicking the window manager\'s own' % name)
        target = button
    else:
        # DWM draws minimize, maximize (greyed when there is no maximize
        # box) and close, the same width each
        third = (dwm[2] - dwm[0]) // 3
        target = (dwm[0], dwm[1], dwm[0] + third, dwm[3])
        centre = (button[0] + button[2]) // 2
        check('minimize button where DWM draws it', target[0] <= centre < target[2],
              'its centre x %d, DWM\'s minimize %d..%d' % (centre, target[0], target[2]))

    before = len([x for x in read_log(log_path) if x == 'ICONIFY ' + name])
    w.bring_forward(hwnd)
    w.click((target[0] + target[2]) // 2, (target[1] + target[3]) // 2)
    end = time.time() + 3
    while time.time() < end and not w.user32.IsIconic(hwnd):
        time.sleep(0.1)
    iconic = bool(w.user32.IsIconic(hwnd))
    time.sleep(0.5)
    got = len([x for x in read_log(log_path) if x == 'ICONIFY ' + name]) > before
    check('a click on the minimize button minimizes it', iconic and got,
          'IsIconic %s, iconifyStack %s' % (iconic, 'received' if got else 'not received'))
    if iconic:
        w.user32.ShowWindow(hwnd, w.SW_RESTORE)
        time.sleep(0.5)


def main(argv=None):
    ap = argparse.ArgumentParser(description='Check that a click on a stack\'s minimize button minimizes it '
                                             '(Windows).')
    ap.add_argument('--install', metavar='DIR', help='installed layout')
    ap.add_argument('--package', metavar='FILE', help='a package to extract and check like --install')
    ap.add_argument('--platform', choices=list(package.PLATFORMS),
                    help='the layout (default: this machine\'s, %s)' % rlc.default_platform())
    ap.add_argument('--log', metavar='FILE', help='write the results here too')
    ap.add_argument('--timeout', type=int, default=60, help='seconds for the stacks to open (default: %(default)s)')
    args = ap.parse_args(argv)
    if bool(args.install) == bool(args.package):
        ap.error('pass --install or --package')
    p = package.PLATFORMS[args.platform or rlc.default_platform()]
    if p.family != 'windows' or os.name != 'nt':
        rlc.log('Window frame check: Windows only; nothing to check for %s.' % p.name)
        return 0

    lines, problems, temp_dirs, proc = [], [], [], None
    try:
        base = os.environ.get('RUNNER_TEMP') or tempfile.gettempdir()
        work = tempfile.mkdtemp(prefix='oxt-frame-', dir=base)
        temp_dirs.append(work)
        args.bin_dir, args.engine = None, None
        lay = rlc.find_layout(args, p, temp_dirs)
        rlc.log('Layout  : %s' % lay.root)
        engine, _ = media_check.stage_runtime(lay.tools, p, work)
        rlc.log('Engine  : %s' % engine)
        log_path = os.path.join(work, 'window-frame-check.log')
        go_path = os.path.join(work, 'go')
        env = dict(os.environ)
        env.update({'OXT_FRAME_LOG': log_path.replace('\\', '/'), 'OXT_FRAME_GO': go_path.replace('\\', '/')})
        proc = subprocess.Popen([engine, SCRIPT], cwd=work, env=env,
                                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        got = wait_for(log_path, 'READY', args.timeout)
        lines += [x for x in got if x.startswith(('INFO ', 'ERROR '))]
        problems += [x[6:] for x in got if x.startswith('ERROR ')]
        if 'READY' not in got:
            problems.append('the stacks did not open within %d seconds' % args.timeout)
        else:
            windows = {}
            for x in got:
                if x.startswith('WINDOW '):
                    parts = x.split()
                    windows[parts[1]] = int(parts[2])
            w = Win32()
            for name in STACKS:
                hwnd = windows.get(name)
                if not hwnd or not w.user32.IsWindow(hwnd):
                    problems.append('%s: no window (%s)' % (name, hwnd))
                    continue
                check_window(w, name, hwnd, log_path, lines, problems)
        with open(go_path, 'w') as f:
            f.write('go\n')
        try:
            proc.wait(timeout=30)
        except subprocess.TimeoutExpired:
            problems.append('the engine did not quit')
            proc.kill()
    except (rlc.CheckError, OSError) as e:
        problems.append(str(e))
        if proc and proc.poll() is None:
            proc.kill()
    finally:
        for d in temp_dirs:
            shutil.rmtree(d, ignore_errors=True)

    rlc.log('')
    for x in lines:
        rlc.log(x)
    for msg in problems:
        rlc.log('::error title=Window frame check::%s' % msg if gha() else 'error: %s' % msg)
    result = 'passed' if not problems else 'FAILED (%d problems)' % len(problems)
    rlc.log('Window frame check %s.' % result)
    rlc._append('GITHUB_STEP_SUMMARY', '### Window frame check (%s)\n\n%s\n\nResult: **%s**\n\n'
                % (p.name, '\n'.join('- ' + x for x in lines), result))
    if args.log:
        with open(args.log, 'w', encoding='utf-8', newline='\n') as f:
            f.write('\n'.join(lines + problems + [result]) + '\n')
    return 1 if problems else 0


if __name__ == '__main__':
    sys.exit(main())
