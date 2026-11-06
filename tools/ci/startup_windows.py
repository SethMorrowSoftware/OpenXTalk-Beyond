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

"""Watch the windows that come and go while the IDE starts, and name
every window that showed and was taken away again: the "ghost windows" of
a start (LittleNemo, openxtalk.org p=25967: "a succession of fleeting
windows" before the IDE settles).

  python3 tools/ci/startup_windows.py --seconds 60 --log FILE
      [--ready FILE] [--display :91] [--process NAME]
      [--launch PROGRAM [ARGUMENT ...]]

On Linux it follows the window manager's list of the windows it manages
(_NET_CLIENT_LIST on the root window, which openbox, xfwm4 and mutter
keep), so it sees what a user sees: a window that is mapped, framed and
given a place in the taskbar, however briefly. Needs python3-xlib.

On Windows it hears each top-level window of the IDE's process shown,
hidden and destroyed (SetWinEventHook, EVENT_OBJECT_SHOW, _HIDE and
_DESTROY), menus and tooltips aside. On macOS it asks for the windows on
the screen every few milliseconds (CGWindowListCopyWindowInfo) and keeps
the IDE's below the menu bar's level, so menus, the menu bar and tooltips
aside; a window that is up for less than that can be missed. Both through
ctypes alone. Which process is the IDE's: --process names it (the
program's file name, as "OXT-Beyond"), or --launch starts it once the
watch has begun and stops it at the end (on Windows, --launch only).

A window that went is a ghost, unless it is the splash, which is meant
to go. Each change is a line of the log: the time in seconds since the
watch began, "+" for a window that came or "-" for one that went, its id
and its title. Then a summary, and one "GHOST" line for each window that
went; with --launch, an "ENDED" line if the program ended before the
watch did. The exit status is 1 when there was a ghost, 2 when the
launched program ended early (and no ghost), 0 otherwise. --ready names a
file written once the watch has begun, so the IDE starts only after that.

The start checks run it beside the IDE: tools/ci/linux_ide_start.sh,
tools/ci/mac_ide_start.sh, and on Windows the step "Start the IDE" of
.github/workflows/build-windows.yml, with --launch.
"""

import argparse
import os
import subprocess
import sys
import time

# The windows that are meant to go while the IDE starts: the splash
SPLASH_TITLES = ('revSplash',)


def ghosts(events, allowed=SPLASH_TITLES):
    """The windows that came and went, from (time, sign, id, title)
    events in order, sign "+" or "-": a list of (id, title, came, went),
    one for each time a window went that is not among the allowed titles.
    A window that came back after it went is a ghost all the same."""
    found = []
    came = {}
    titles = {}
    for when, sign, wid, title in events:
        if sign == '+':
            came[wid] = when
            if title:
                titles[wid] = title
        elif sign == '-':
            title = titles.get(wid, title)
            if title in allowed:
                continue
            found.append((wid, title, came.get(wid), when))
    return found


def report(events, found):
    lines = ['%8.3f %s %#x %s' % (when, sign, wid, title or '(no title)')
             for when, sign, wid, title in events]
    if found:
        for wid, title, came, went in found:
            shown = '' if came is None else ' after %.3f s' % (went - came)
            lines.append('GHOST %#x "%s" went at %.3f s%s'
                         % (wid, title or '(no title)', went, shown))
    else:
        lines.append('No window came and went (the splash aside)')
    return lines


def watch_x11(display_name, seconds, ready=None, on_ready=None):
    from Xlib import X, display
    d = display.Display(display_name)
    root = d.screen().root
    root.change_attributes(event_mask=X.PropertyChangeMask)
    client_list = d.intern_atom('_NET_CLIENT_LIST')
    net_name = d.intern_atom('_NET_WM_NAME')
    utf8 = d.intern_atom('UTF8_STRING')

    def title(wid):
        try:
            w = d.create_resource_object('window', wid)
            p = w.get_full_property(net_name, utf8)
            if p is not None and p.value:
                v = p.value
                return v.decode('utf-8', 'replace') if isinstance(v, bytes) else str(v)
            n = w.get_wm_name()
            return n.decode('latin-1') if isinstance(n, bytes) else (n or '')
        except Exception:
            return ''

    def clients():
        p = root.get_full_property(client_list, X.AnyPropertyType)
        return list(p.value) if p is not None else []

    start = time.time()
    events = []
    now = clients()
    for wid in now:
        events.append((0.0, '+', wid, title(wid)))
    began(ready, on_ready)
    end = start + seconds
    while time.time() < end:
        while d.pending_events():
            e = d.next_event()
            if e.type == X.PropertyNotify and e.atom == client_list:
                after = clients()
                when = time.time() - start
                for wid in after:
                    if wid not in now:
                        events.append((when, '+', wid, title(wid)))
                for wid in now:
                    if wid not in after:
                        events.append((when, '-', wid, ''))
                now = after
        time.sleep(0.002)
    return events


def began(ready, on_ready):
    """The watch has begun: say so in the --ready file, then start the
    program with --launch"""
    if ready:
        with open(ready, 'w') as f:
            f.write('ready\n')
    if on_ready:
        on_ready()


def program_name(path):
    """A program's name as --process gives it: its file name without the
    folder or ".exe", any case"""
    name = os.path.basename(path.replace('\\', '/'))
    if name.lower().endswith('.exe'):
        name = name[:-4]
    return name.lower()


# Windows: the classes of top-level windows that are not a window of the
# IDE's in the sense here: menus and tooltips, the system's and the
# engine's (engine/src/w32dc.h), the IME's, and the engine's snapshot
WIN32_IGNORED_CLASSES = ('#32768', 'tooltips_class32', 'MCMenuWinClass',
                         'MCPopupWinClass', 'MCSnapshotWinClass', 'IME',
                         'MSCTFIME UI')

EVENT_OBJECT_DESTROY = 0x8001
EVENT_OBJECT_SHOW = 0x8002
EVENT_OBJECT_HIDE = 0x8003


def win32_events(raw, keep):
    """The (time, sign, id, title) events from what the Windows hook
    heard: (time, event, hwnd, pid, class name, title, top-level), in
    order. A window counts once it is shown, if it is top-level, is the
    IDE's (keep(pid)) and not of an ignored class; it went when it is
    hidden or destroyed while shown. Its pid and class are the ones it had
    when shown: a destroyed window has none."""
    shown = {}
    events = []
    for when, event, hwnd, pid, cls, title, top in raw:
        if event == EVENT_OBJECT_SHOW:
            if hwnd in shown or not top or cls in WIN32_IGNORED_CLASSES or not keep(pid):
                continue
            shown[hwnd] = title
            events.append((when, '+', hwnd, title))
        elif event in (EVENT_OBJECT_HIDE, EVENT_OBJECT_DESTROY):
            if hwnd not in shown:
                continue
            events.append((when, '-', hwnd, title or shown[hwnd]))
            del shown[hwnd]
    return events


def watch_win32(seconds, keep, ready=None, on_ready=None):
    import ctypes
    from ctypes import wintypes
    user32 = ctypes.WinDLL('user32', use_last_error=True)
    WINEVENTPROC = ctypes.WINFUNCTYPE(
        None, wintypes.HANDLE, wintypes.DWORD, wintypes.HWND, wintypes.LONG,
        wintypes.LONG, wintypes.DWORD, wintypes.DWORD)
    user32.SetWinEventHook.restype = wintypes.HANDLE
    user32.SetWinEventHook.argtypes = [
        wintypes.DWORD, wintypes.DWORD, wintypes.HMODULE, WINEVENTPROC,
        wintypes.DWORD, wintypes.DWORD, wintypes.DWORD]
    user32.UnhookWinEvent.argtypes = [wintypes.HANDLE]
    user32.GetAncestor.restype = wintypes.HWND
    user32.GetAncestor.argtypes = [wintypes.HWND, wintypes.UINT]
    user32.GetWindowThreadProcessId.restype = wintypes.DWORD
    user32.GetWindowThreadProcessId.argtypes = [wintypes.HWND, ctypes.POINTER(wintypes.DWORD)]
    user32.GetClassNameW.argtypes = [wintypes.HWND, wintypes.LPWSTR, ctypes.c_int]
    user32.GetWindowTextW.argtypes = [wintypes.HWND, wintypes.LPWSTR, ctypes.c_int]
    user32.PeekMessageW.argtypes = [ctypes.POINTER(wintypes.MSG), wintypes.HWND,
                                    wintypes.UINT, wintypes.UINT, wintypes.UINT]
    user32.TranslateMessage.argtypes = [ctypes.POINTER(wintypes.MSG)]
    user32.DispatchMessageW.argtypes = [ctypes.POINTER(wintypes.MSG)]
    OBJID_WINDOW, GA_ROOT = 0, 2
    WINEVENT_OUTOFCONTEXT, WINEVENT_SKIPOWNPROCESS = 0, 2
    PM_REMOVE = 1

    start = time.time()
    raw = []

    def heard(hook, event, hwnd, id_object, id_child, thread, ms):
        if id_object != OBJID_WINDOW or id_child != 0 or not hwnd:
            return
        try:
            when = time.time() - start
            if event == EVENT_OBJECT_DESTROY:
                raw.append((when, event, hwnd, 0, '', '', False))
                return
            pid = wintypes.DWORD()
            user32.GetWindowThreadProcessId(hwnd, ctypes.byref(pid))
            cls = ctypes.create_unicode_buffer(256)
            user32.GetClassNameW(hwnd, cls, 256)
            text = ctypes.create_unicode_buffer(512)
            user32.GetWindowTextW(hwnd, text, 512)
            top = user32.GetAncestor(hwnd, GA_ROOT) == hwnd
            raw.append((when, event, hwnd, pid.value, cls.value, text.value, top))
        except Exception as e:  # nothing may escape a callback
            sys.stderr.write('startup_windows: %r\n' % e)

    callback = WINEVENTPROC(heard)  # kept alive until the hook is gone
    hook = user32.SetWinEventHook(EVENT_OBJECT_DESTROY, EVENT_OBJECT_HIDE, None, callback,
                                  0, 0, WINEVENT_OUTOFCONTEXT | WINEVENT_SKIPOWNPROCESS)
    if not hook:
        raise OSError('SetWinEventHook failed: %d' % ctypes.get_last_error())
    try:
        began(ready, on_ready)
        msg = wintypes.MSG()
        end = start + seconds
        # an out-of-context hook is called from this thread's message loop
        while time.time() < end:
            while user32.PeekMessageW(ctypes.byref(msg), None, 0, 0, PM_REMOVE):
                user32.TranslateMessage(ctypes.byref(msg))
                user32.DispatchMessageW(ctypes.byref(msg))
            time.sleep(0.002)
    finally:
        user32.UnhookWinEvent(hook)
    return win32_events(raw, keep)


# macOS: windows at this level and above are the menu bar's, the menus',
# the Dock's and tooltips (CGWindowLevel.h: the Dock 20, the main menu 24,
# pop-up menus 101, help 200); a palette is at 3, a modal panel at 8
MAC_TOP_LEVEL = 20


def mac_changes(before, after, when):
    """The (time, sign, id, title) events between two looks at the
    windows on the screen, each {id: title}: those that came, then those
    that went, with the newest title each had"""
    events = [(when, '+', wid, after[wid]) for wid in sorted(after) if wid not in before]
    events += [(when, '-', wid, before[wid]) for wid in sorted(before) if wid not in after]
    return events


def watch_mac(seconds, keep, ready=None, on_ready=None):
    import ctypes
    cg = ctypes.CDLL('/System/Library/Frameworks/CoreGraphics.framework/CoreGraphics')
    cf = ctypes.CDLL('/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation')
    vp = ctypes.c_void_p
    cg.CGWindowListCopyWindowInfo.restype = vp
    cg.CGWindowListCopyWindowInfo.argtypes = [ctypes.c_uint32, ctypes.c_uint32]
    cf.CFArrayGetCount.restype = ctypes.c_long
    cf.CFArrayGetCount.argtypes = [vp]
    cf.CFArrayGetValueAtIndex.restype = vp
    cf.CFArrayGetValueAtIndex.argtypes = [vp, ctypes.c_long]
    cf.CFDictionaryGetValue.restype = vp
    cf.CFDictionaryGetValue.argtypes = [vp, vp]
    cf.CFNumberGetValue.restype = ctypes.c_bool
    cf.CFNumberGetValue.argtypes = [vp, ctypes.c_int, vp]
    cf.CFStringGetCString.restype = ctypes.c_bool
    cf.CFStringGetCString.argtypes = [vp, ctypes.c_char_p, ctypes.c_long, ctypes.c_uint32]
    cf.CFRelease.argtypes = [vp]
    key = dict((k, vp.in_dll(cg, k).value) for k in (
        'kCGWindowNumber', 'kCGWindowOwnerPID', 'kCGWindowOwnerName',
        'kCGWindowName', 'kCGWindowLayer'))
    ON_SCREEN_ONLY, EXCLUDE_DESKTOP = 1, 16
    SINT64, UTF8 = 4, 0x08000100

    def number(d, k):
        v = cf.CFDictionaryGetValue(d, key[k])
        n = ctypes.c_int64(0)
        if v:
            cf.CFNumberGetValue(v, SINT64, ctypes.byref(n))
        return n.value

    def string(d, k):
        v = cf.CFDictionaryGetValue(d, key[k])
        if not v:
            return ''
        buf = ctypes.create_string_buffer(1024)
        if not cf.CFStringGetCString(v, buf, 1024, UTF8):
            return ''
        return buf.value.decode('utf-8', 'replace')

    libc = ctypes.CDLL('/usr/lib/libSystem.B.dylib')
    libc.proc_pidpath.restype = ctypes.c_int
    libc.proc_pidpath.argtypes = [ctypes.c_int, ctypes.c_char_p, ctypes.c_uint32]

    def program(pid, owner):
        # the program's file name (Contents/MacOS/OXT-Beyond), which
        # --process names; the owner name is the bundle's
        buf = ctypes.create_string_buffer(4096)
        if libc.proc_pidpath(pid, buf, 4096) > 0:
            return buf.value.decode('utf-8', 'replace')
        return owner

    names = {}

    def look():
        windows = {}
        a = cg.CGWindowListCopyWindowInfo(ON_SCREEN_ONLY | EXCLUDE_DESKTOP, 0)
        if not a:
            return windows
        try:
            for i in range(cf.CFArrayGetCount(a)):
                d = cf.CFArrayGetValueAtIndex(a, i)
                if number(d, 'kCGWindowLayer') >= MAC_TOP_LEVEL:
                    continue
                pid = number(d, 'kCGWindowOwnerPID')
                if pid not in names:
                    names[pid] = program(pid, string(d, 'kCGWindowOwnerName'))
                if not keep(pid, names[pid]):
                    continue
                # the title is there only with the screen recording
                # permission
                windows[number(d, 'kCGWindowNumber')] = string(d, 'kCGWindowName')
        finally:
            cf.CFRelease(a)
        return windows

    start = time.time()
    events = []
    now = look()
    events += mac_changes({}, now, 0.0)
    began(ready, on_ready)
    end = start + seconds
    while time.time() < end:
        after = look()
        when = time.time() - start
        # a title set after the window came is kept for when it goes
        for wid in after:
            if not after[wid] and now.get(wid):
                after[wid] = now[wid]
        events += mac_changes(now, after, when)
        now = after
        time.sleep(0.005)
    return events


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    ap.add_argument('--display', default=os.environ.get('DISPLAY', ':0'),
                    help='the X screen (Linux)')
    ap.add_argument('--seconds', type=float, default=60.0)
    ap.add_argument('--log', help='where the lines go too')
    ap.add_argument('--ready', help='a file written once the watch has begun')
    ap.add_argument('--process', help='the IDE\'s program name, as "OXT-Beyond" (macOS)')
    ap.add_argument('--launch', nargs=argparse.REMAINDER,
                    help='the program to start once the watch has begun, and its arguments')
    args = ap.parse_args(argv)

    proc = []
    on_ready = None
    if args.launch:
        def on_ready():
            proc.append(subprocess.Popen(args.launch, stdout=subprocess.DEVNULL,
                                         stderr=subprocess.STDOUT))
    wanted = program_name(args.process) if args.process else None
    if sys.platform == 'win32' and not args.launch:
        ap.error('on Windows, start the IDE with --launch: its windows are those of its process')
    if sys.platform == 'darwin' and not (args.launch or wanted):
        ap.error('on macOS, name the IDE with --process or start it with --launch')

    def keep(pid, name=None):
        # with --launch, only the launched program's, and none before it
        # starts
        if args.launch and (not proc or pid != proc[0].pid):
            return False
        if wanted and name is not None and program_name(name) != wanted:
            return False
        return True

    ended = None
    try:
        if sys.platform == 'win32':
            events = watch_win32(args.seconds, keep, args.ready, on_ready)
        elif sys.platform == 'darwin':
            events = watch_mac(args.seconds, keep, args.ready, on_ready)
        else:
            events = watch_x11(args.display, args.seconds, args.ready, on_ready)
    finally:
        if proc:
            if proc[0].poll() is not None:
                ended = proc[0].returncode
            else:
                proc[0].kill()
                proc[0].wait()
    found = ghosts(events)
    lines = report(events, found)
    if ended is not None:
        lines.append('ENDED the program ended before the watch did, with exit status %s' % ended)
    text = '\n'.join(lines) + '\n'
    sys.stdout.write(text)
    if args.log:
        with open(args.log, 'w') as f:
            f.write(text)
    return 1 if found else 2 if ended is not None else 0


if __name__ == '__main__':
    sys.exit(main())
