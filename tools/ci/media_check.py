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

"""Check that the browser widget, revBrowser and the player work in a
standalone of an installed OXT-Beyond, with a user interface.

  python tools/ci/media_check.py (--install DIR | --package FILE)
      [--platform P] [--what widget,revbrowser,player] [--log FILE]
      [--snapshots DIR] [--timeout SECONDS]
      [--player-backend auto|gstreamer|mplayer]
      [--browser-backend auto|cef|webkitgtk]
      [--session own|wayland|wayland-name]

The layout is one of run_livecode_check.py's (--install, or --package to
extract first). Its own platform's standalone runtime (standalone_check.py
RUNTIMES) is copied to a folder of its own, laid out as a standalone the
IDE builds: on Windows and Linux the engine with Externals (CEF included)
and the CEF helper processes next to it, on macOS the Standalone*.app.
That engine then runs tools/ci/media-check.livecodescript, which

  - loads the browser widget from the layout's Extensions, opens a page
    this script serves on 127.0.0.1, and checks that the page loads, that
    its JavaScript calls a handler of the script (javascriptHandlers) and
    that the widget's htmlText is the page after its JavaScript ran;
  - does the same with revBrowser (revBrowserOpenCef; on macOS
    revBrowserOpen), loaded from the runtime's Externals by a stack's
    externals property, as in a standalone;
  - plays a WAV file this script writes and the files of tools/ci/media:
    oxt-check.mp4 (H.264 and AAC), oxt-check-silent.mp4 (H.264 only),
    oxt-check.avi (Motion JPEG and PCM) and oxt-check-silent.avi (Motion
    JPEG only), 3 seconds each: duration and
    timeScale, currentTime moving on while it plays, pausing, and
    playStopped at the end. The files without sound tell a player that
    cannot open a format from one that cannot play sound (a machine with
    no sound device). What a platform is known not to play (KNOWN) is
    reported without failing the check;
  - on Linux, clicks the controller the engine draws below mplayer's
    video: its play button plays and pauses, a click in its well seeks,
    and the snapshots of what it draws show which. With --snapshots those
    snapshots, and the screen with the video, are written to DIR (and,
    under GitHub Actions, into the log as base64).

Each of the three runs in an engine of its own, as an application would
use one of them, so that one cannot hide a failure of another (the
browser widget and revBrowser load the same CEF).

On Linux the engine runs under xvfb-run when there is no DISPLAY. Its
player plays a movie through mplayer (/usr/bin/mplayer, as the engine runs
it) or through GStreamer (engine/src/lnxgstplayer.cpp): --player-backend
sets OXT_PLAYER_BACKEND for the engine, so that each of the two can be
checked on a machine that has both ("auto", the default, leaves it unset:
mplayer when it is installed, else GStreamer). The browser widget's browser is
CEF where it loads, else WebKitGTK (libbrowser_webkitgtk.cpp, through the
helper libbrowser-webkitprocess next to the engine): --browser-backend
sets OXT_BROWSER_BACKEND, so that the WebKitGTK browser can be checked on
a machine where CEF loads (revBrowser, which has CEF only, is then left
out). On a machine without a
sound card (no /dev/snd) mplayer is given MPLAYER_HOME with "ao=null", so
that it plays in real time instead of skipping to the end of a file it
cannot play the sound of; GStreamer plays without sound there by itself.

--session (Linux) is the desktop session the engine runs in. Chromium
chooses the platform of its own windows by the session: where
XDG_SESSION_TYPE is "wayland" it takes Wayland unless it is told a
platform (Chromium's ui/linux/display_server_utils.cc,
SetOzonePlatformForLinuxIfNeeded). The engine is an X11 program in such a
session too, on Xwayland, and its browser is the child of a stack's X
window, so it tells Chromium X11 (libbrowser_cef.cpp,
AppendLinuxOzonePlatform, and revBrowser's cefbrowser.cpp). What the
first CEF 156 builds did without that, main at c77e5264 in the runs
44166397552, 44167685958 and 44173064029:

  wayland-name  XDG_SESSION_TYPE=wayland alone, on the X display there is
                (or xvfb-run's), with no compositor and no
                WAYLAND_DISPLAY. No browser was made: the widget's page
                did not load, and revBrowser said "creation failed".
  wayland       A Wayland session of its own, as a desktop gives one: a
                headless Weston with Xwayland, the engine on Xwayland's
                display, and XDG_SESSION_TYPE=wayland, WAYLAND_DISPLAY and
                XDG_RUNTIME_DIR in its environment (wayland_session). The
                page loaded and its JavaScript ran, but Chromium made no
                X window: CEF's own window in the stack's stayed without
                the one Chromium puts into it on an X display (in a
                headless Mutter session, GNOME's compositor, too, where
                the same session named x11 had it). So with
                the widget and --browser-backend cef the X window tree is
                sampled while the engine runs (xwininfo), and the stack's
                window must go as deep as it does with Chromium's window
                in it (CHROMIUM_WINDOW_DEPTH).

"wayland" needs the packages weston, xwayland and x11-utils.

Exit status 0 when every check passed, 1 otherwise. Under GitHub Actions
failures are annotations and the results go into the job summary. Only
the Python 3 standard library is used (3.8 or later).
"""

import argparse
import base64
import functools
import http.server
import math
import os
import re
import shutil
import socket
import struct
import subprocess
import sys
import tempfile
import threading
import time
import wave

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(os.path.dirname(HERE), 'oxt'))
sys.path.insert(0, HERE)
import package  # noqa: E402
import run_livecode_check as rlc  # noqa: E402
import standalone_check  # noqa: E402
import hidpi_check  # noqa: E402

SCRIPT = os.path.join(HERE, 'media-check.livecodescript')
MEDIA = os.path.join(HERE, 'media')
VIDEOS = ('oxt-check.mp4', 'oxt-check-silent.mp4', 'oxt-check.avi', 'oxt-check-silent.avi')

# Files a platform's player is known not to play, with the reason: their
# failures are reported (KNOWN) but do not fail the check, and a file that
# plays after all is reported so that it can come off the list.
KNOWN = {}
# DirectShow (engine/src/w32-ds-player.cpp) has no reader for MP4 unless a
# DirectShow filter for it (LAV Filters, a codec pack) is installed; since
# 0.2.8-dp.2 the player opens a file DirectShow cannot through Media
# Foundation (engine/src/w32-mf-player.cpp), so the MP4 files must play
# wherever Windows has Media Foundation and its H.264 decoder
# (MEDIA_FOUNDATION_DLLS), and are known not to only where it does not (an
# N edition without the Media Feature Pack, a Windows Server without its
# Media Foundation feature) or with DirectShow alone (--player-backend
# directshow)
NO_MEDIA_FOUNDATION = {
    'oxt-check.mp4': 'Windows without Media Foundation: DirectShow cannot open MP4 without a third-party filter',
    'oxt-check-silent.mp4': 'Windows without Media Foundation: DirectShow cannot open MP4 without a third-party filter',
}
# What the player needs of Media Foundation for the MP4 files: MFPlay (which
# the engine loads at run time), Media Foundation itself, and its H.264
# decoder
MEDIA_FOUNDATION_DLLS = ('mfplay.dll', 'mfplat.dll', 'msmpeg2vdec.dll')
# Without a sound device (a CI runner) Windows cannot play a file that is
# only sound
NO_SOUND_DEVICE = {'oxt-check.wav': 'Windows without a sound device (as on the CI runners) does not open it'}
MPLAYER = '/usr/bin/mplayer'
# The Wayland session of --session wayland: its socket in a runtime folder
# of its own, and how long Weston has to start it with Xwayland listening
WAYLAND_SOCKET = 'wayland-oxt-check'
WAYLAND_START_SECONDS = 30
# The stack media-check.livecodescript makes its browsers in, as its window
# is named, and how many windows deep that window goes while a browser
# widget on X11 shows a page: the engine's window for the card, its window
# for the widget, CEF's, and Chromium's own in CEF's. (Counted under Xvfb in
# run 44167685958 and in a Mutter session named x11 in run 44173064029; in
# a Weston and in a Mutter session, where Chromium had taken Wayland, it
# was 3: CEF's window had nothing in it.)
CHECK_STACK = 'MediaCheck'
CHROMIUM_WINDOW_DEPTH = 4
# A window of xwininfo's tree: its indentation, and its name when it has one
TREE_WINDOW = re.compile(r'^( +)0x[0-9a-f]+ (?:"(.*?)"|\(has no name\)): \(')

# The page the browsers open: media-check.livecodescript looks for its
# title, for "script ran: 3" in its HTML and for the oxtReport calls. The
# first call is made as the page is read, before it has loaded: with CEF the
# liveCode object must be there for the page's own script from the start
# when the browser opens a page of a site it has opened before (the
# widget's second load of the page, "?again")
PAGE = """<!DOCTYPE html>
<html><head><meta charset="utf-8"><title>OXT media check</title></head>
<body><h1 id="h">waiting for the script</h1>
<script>
if (window.liveCode && liveCode.oxtReport) liveCode.oxtReport('inline', location.search || 'first');
document.getElementById('h').textContent = 'script ran: ' + (1 + 2);
setTimeout(function () {
  if (window.liveCode && liveCode.oxtReport) liveCode.oxtReport('size', window.innerWidth + ' ' + window.devicePixelRatio);
  if (window.liveCode && liveCode.oxtReport) liveCode.oxtReport('loaded', navigator.userAgent);
}, 300);
</script>
</body></html>
"""


def gha():
    return bool(os.environ.get('GITHUB_ACTIONS'))


def write_tone(path, seconds=3.0, rate=44100):
    """A 440 Hz sine, 16-bit mono PCM."""
    frames = bytearray()
    for i in range(int(seconds * rate)):
        frames += struct.pack('<h', int(12000 * math.sin(2 * math.pi * 440 * i / rate)))
    with wave.open(path, 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(rate)
        w.writeframes(bytes(frames))


class _QuietHandler(http.server.SimpleHTTPRequestHandler):
    def log_message(self, *args):
        pass


def serve(folder):
    """An HTTP server for folder on 127.0.0.1, in a thread; (server, port)."""
    handler = functools.partial(_QuietHandler, directory=folder)
    server = http.server.ThreadingHTTPServer(('127.0.0.1', 0), handler)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    return server, server.server_address[1]


def wayland_session(work, environ=None, start_seconds=WAYLAND_START_SECONDS):
    """Starts a Wayland session of its own for --session wayland: a headless
    Weston with Xwayland, in a runtime folder under work. Returns Weston's
    process and what a program of that session has in its environment:
    XDG_SESSION_TYPE=wayland, the compositor's socket (WAYLAND_DISPLAY in
    XDG_RUNTIME_DIR) and Xwayland's DISPLAY, where an X11 program such as
    the engine opens its windows. The compositor's socket must take a
    connection: with a session in name only, a Chromium that asks for
    Wayland makes no browser at all (--session wayland-name)."""
    weston = shutil.which('weston')
    if not weston or not shutil.which('Xwayland'):
        raise rlc.CheckError('--session wayland needs weston and Xwayland (the packages weston and xwayland)')
    runtime = os.path.join(work, 'xdg-runtime')
    os.makedirs(runtime)
    # (Weston refuses a runtime folder others can read)
    os.chmod(runtime, 0o700)
    log = os.path.join(work, 'weston.log')
    env = {k: v for k, v in (os.environ if environ is None else environ).items()
           if k not in ('DISPLAY', 'WAYLAND_DISPLAY', 'WAYLAND_SOCKET')}
    env['XDG_RUNTIME_DIR'] = runtime
    proc = subprocess.Popen([weston, '--backend=headless', '--xwayland', '--socket=' + WAYLAND_SOCKET,
                             '--width=1280', '--height=1024', '--log=' + log],
                            env=env, stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.STDOUT)
    display, text = None, ''
    deadline = time.time() + start_seconds
    while time.time() < deadline and proc.poll() is None:
        if os.path.exists(log):
            with open(log, encoding='utf-8', errors='replace') as f:
                text = f.read()
        m = re.search(r'xserver listening on display (:\d+)', text)
        if m and os.path.exists(os.path.join(runtime, WAYLAND_SOCKET)):
            display = m.group(1)
            break
        time.sleep(0.2)
    problem = None
    if display is None:
        problem = ('Weston ended with status %s' % proc.returncode if proc.poll() is not None
                   else 'Weston had no Wayland session with Xwayland after %d seconds' % start_seconds)
    else:
        s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        try:
            s.connect(os.path.join(runtime, WAYLAND_SOCKET))
        except OSError as e:
            problem = 'the compositor\'s socket %s takes no connection (%s)' % (WAYLAND_SOCKET, e)
        finally:
            s.close()
    if problem:
        end_session(proc)
        raise rlc.CheckError('--session wayland: %s; its log ends: %s'
                             % (problem, ' | '.join(text.splitlines()[-5:]) or '(empty)'))
    version = re.search(r'weston (\d[\w.]*)', text)
    return proc, {'XDG_SESSION_TYPE': 'wayland', 'XDG_RUNTIME_DIR': runtime, 'WAYLAND_DISPLAY': WAYLAND_SOCKET,
                  'DISPLAY': display}, 'Weston %s, headless, with Xwayland on %s' % (
                      version.group(1) if version else '(version not in its log)', display)


def end_session(proc):
    """Ends a session wayland_session started."""
    if proc.poll() is None:
        proc.terminate()
        try:
            proc.wait(timeout=10)
        except subprocess.TimeoutExpired:
            proc.kill()
            proc.wait()


def x_window_tree(env):
    """xwininfo's tree of every window on the X display of env, or '' when
    it gives none."""
    try:
        out = subprocess.run(['xwininfo', '-root', '-tree'], env=env, stdin=subprocess.DEVNULL,
                             stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, timeout=10)
    except (OSError, subprocess.TimeoutExpired):
        return ''
    return out.stdout.decode('utf-8', 'replace') if out.returncode == 0 else ''


def windows_deep(tree, title):
    """How many windows deep the window whose name begins with title goes
    in xwininfo's tree: 0 with no window inside it, 1 with children that
    have none, and so on; None when the tree has no such window. Where a
    window of that name is inside another, the inner one is counted:
    Mutter's frame carries the title of the window it frames. xwininfo
    indents a window's children three columns further."""
    inside, deepest = None, None
    for line in tree.splitlines():
        m = TREE_WINDOW.match(line)
        if not m:
            continue
        indent = len(m.group(1))
        named = (m.group(2) or '').startswith(title)
        if inside is not None and indent <= inside:
            break
        if named:
            inside, deepest = indent, 0
        elif inside is not None:
            deepest = max(deepest, (indent - inside) // 3)
    return deepest


class TreeSampler(threading.Thread):
    """Samples the X window tree of env's display until stop(), and keeps
    the sample in which the window named title goes deepest: a browser's
    windows are there only while the engine shows it."""

    def __init__(self, env, title, every=0.2):
        super().__init__(daemon=True)
        self.env, self.title, self.every = env, title, every
        self.depth, self.tree = None, ''
        self.done = threading.Event()

    def run(self):
        while not self.done.is_set():
            tree = x_window_tree(self.env)
            depth = windows_deep(tree, self.title)
            if depth is not None and (self.depth is None or depth > self.depth):
                self.depth, self.tree = depth, tree
            self.done.wait(self.every)

    def stop(self):
        """Ends the sampling; the greatest depth seen, or None."""
        self.done.set()
        self.join()
        return self.depth


def chromium_window_result(depth):
    """The result line for the stack's window having gone depth windows
    deep in a Wayland session (None: the window was never seen)."""
    if depth is not None and depth >= CHROMIUM_WINDOW_DEPTH:
        return ('PASS browser widget: Chromium\'s X window is inside the stack\'s in the Wayland session: '
                'the stack\'s window goes %d windows deep' % depth)
    return ('FAIL browser widget: Chromium made no X window inside the stack\'s in the Wayland session: the '
            'stack\'s window %s, and %d with Chromium\'s window in CEF\'s (Chromium is not on X11 there)'
            % ('was not seen' if depth is None else 'goes %d windows deep' % depth, CHROMIUM_WINDOW_DEPTH))


def stage_runtime(tools, p, work):
    """Copy the layout's own standalone runtime into work as a standalone
    has it; (engine executable, revbrowser external)."""
    runtime = os.path.join(tools, *standalone_check.RUNTIMES[standalone_check.own_target(p)].split('/'))
    if not os.path.exists(runtime):
        raise rlc.CheckError('no standalone runtime at %s' % runtime)
    folder = os.path.dirname(runtime)
    if p.family == 'mac':
        app = os.path.join(work, 'OXTMediaCheck.app')
        shutil.copytree(runtime, app, symlinks=True)
        return (os.path.join(app, *standalone_check.MAC_EXE.split('/')),
                os.path.join(folder, 'Externals', 'revbrowser.bundle'))
    app = os.path.join(work, 'OXTMediaCheck')
    shutil.copytree(folder, app, symlinks=True)
    name = os.path.basename(runtime)
    if p.family == 'windows':
        os.rename(os.path.join(app, name), os.path.join(app, 'OXTMediaCheck.exe'))
        return os.path.join(app, 'OXTMediaCheck.exe'), os.path.join(app, 'Externals', 'revbrowser.dll')
    return os.path.join(app, name), os.path.join(app, 'Externals', 'revbrowser.so')


def windows_sound_devices():
    """The names of the sound devices Windows has (Win32_SoundDevice)."""
    try:
        out = subprocess.run(['powershell', '-NoProfile', '-Command',
                              '(Get-CimInstance Win32_SoundDevice | ForEach-Object { $_.Name }) -join "; "'],
                             stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=60).stdout
        return out.decode('utf-8', 'replace').strip() or 'none'
    except (OSError, subprocess.TimeoutExpired) as e:
        return 'unknown (%s)' % e


def windows_media_foundation(system32=None):
    """The MEDIA_FOUNDATION_DLLS missing from Windows' system folder (empty
    when the player can open an MP4 through Media Foundation)."""
    if system32 is None:
        system32 = os.path.join(os.environ.get('SystemRoot', r'C:\Windows'), 'System32')
    return [n for n in MEDIA_FOUNDATION_DLLS if not os.path.isfile(os.path.join(system32, n))]


def known_failures(family, player_backend='auto', missing_media_foundation=()):
    """What the player is known not to play on a platform family: KNOWN's,
    and on Windows the MP4 files where Media Foundation cannot play them
    (missing_media_foundation lists what of it is missing) or DirectShow
    plays alone."""
    known = dict(KNOWN.get(family, {}))
    if family == 'windows' and (player_backend == 'directshow' or missing_media_foundation):
        known.update(NO_MEDIA_FOUNDATION)
    return known


# The variables Chromium reads the desktop's name from (base/nix/xdg_util.cc,
# GetDesktopEnvironment), and what the sessions of three desktops give them:
# Ubuntu's GNOME (24.04 and 26.04), Xubuntu's Xfce and Kubuntu's Plasma
DESKTOP_VARIABLES = ('XDG_CURRENT_DESKTOP', 'DESKTOP_SESSION', 'GNOME_DESKTOP_SESSION_ID', 'KDE_FULL_SESSION')
DESKTOPS = {
    'gnome': {'XDG_CURRENT_DESKTOP': 'ubuntu:GNOME', 'DESKTOP_SESSION': 'ubuntu',
              'GNOME_DESKTOP_SESSION_ID': 'this-is-deprecated'},
    'xfce': {'XDG_CURRENT_DESKTOP': 'XFCE', 'DESKTOP_SESSION': 'xubuntu'},
    'kde': {'XDG_CURRENT_DESKTOP': 'KDE', 'DESKTOP_SESSION': 'plasma', 'KDE_FULL_SESSION': 'true'},
}

# What glibc prints when a function returns with a changed stack canary
STACK_SMASHED = 'stack smashing detected'


def main(argv=None):
    ap = argparse.ArgumentParser(description='Check the browser widget, revBrowser and the player in a standalone '
                                             'of an installed OXT-Beyond.')
    ap.add_argument('--install', metavar='DIR', help='installed layout')
    ap.add_argument('--package', metavar='FILE', help='a package to extract and check like --install')
    ap.add_argument('--platform', choices=list(package.PLATFORMS),
                    help='the layout (default: this machine\'s, %s)' % rlc.default_platform())
    ap.add_argument('--what', default='widget,revbrowser,player',
                    help='comma-separated: widget, revbrowser, player (default: %(default)s)')
    ap.add_argument('--must-play', metavar='FILES', default='',
                    help='comma-separated media files that must play although KNOWN lists them (for example the '
                         'MP4 files on Windows with LAV Filters installed)')
    ap.add_argument('--log', metavar='FILE', help='write the results here too')
    ap.add_argument('--snapshots', metavar='DIR', help='write the snapshots of the Linux player\'s controller here')
    ap.add_argument('--timeout', type=int, default=240, help='seconds for the engine run (default: %(default)s)')
    ap.add_argument('--player-backend', choices=('auto', 'gstreamer', 'mplayer', 'directshow', 'mediafoundation'),
                    default='auto',
                    help='what plays the movies: OXT_PLAYER_BACKEND for the engine (default: %(default)s; on Linux '
                         'mplayer when it is installed, else GStreamer; on Windows DirectShow, and Media Foundation '
                         'for a file DirectShow cannot open)')
    ap.add_argument('--browser-backend', choices=('auto', 'cef', 'webkitgtk'), default='auto',
                    help='on Linux, the browser widget\'s browser: OXT_BROWSER_BACKEND for the engine (default: '
                         '%(default)s, CEF where it loads, else WebKitGTK through libbrowser-webkitprocess). '
                         'revBrowser has CEF only.')
    ap.add_argument('--session', choices=('own', 'wayland', 'wayland-name'), default='own',
                    help='on Linux, the desktop session the engine runs in: "wayland" starts a Wayland session of '
                         'its own (a headless Weston with Xwayland; XDG_SESSION_TYPE=wayland, WAYLAND_DISPLAY and '
                         'Xwayland\'s DISPLAY for the engine), as on a desktop whose session is Wayland, and '
                         'looks for Chromium\'s X window in the stack\'s; "wayland-name" gives the engine '
                         'XDG_SESSION_TYPE=wayland alone, with no compositor (default: %(default)s, the display '
                         'there is, or xvfb-run)')
    ap.add_argument('--desktop', choices=sorted(DESKTOPS), metavar='NAME',
                    help='on Linux, name the desktop for the engine as that desktop\'s session does '
                         '(XDG_CURRENT_DESKTOP, DESKTOP_SESSION and the rest; one of %(choices)s). Chromium asks for '
                         'the theme of the desktop it is named: GTK\'s on gnome and xfce, which the GTK 2 engine '
                         'cannot load, so the engine keeps the name from it')
    ap.add_argument('--desktop-scale', type=int, choices=(2, 3), metavar='N',
                    help='on Linux, run the engine on a screen of its own (Xvfb) with a desktop scaled N times: an '
                         'XSETTINGS manager (xsettingsd) publishing Gdk/WindowScalingFactor N, Xft/DPI N times 96 '
                         'and Gdk/UnscaledDPI 96, as GNOME\'s settings do. The browser widget\'s page must then be '
                         'as wide as the widget, at N pixels a point')
    args = ap.parse_args(argv)
    if bool(args.install) == bool(args.package):
        ap.error('pass --install or --package')
    p = package.PLATFORMS[args.platform or rlc.default_platform()]
    if standalone_check.own_target(p) not in standalone_check.RUNTIMES:
        ap.error('%s has no standalone runtime of its own' % p.name)
    what = [w.strip() for w in args.what.split(',') if w.strip()]
    if p.name.startswith('linux-') and p.name != 'linux-x86_64':
        # CEF is in the x86_64 Linux package only; WebKitGTK is the browser
        # widget's browser on every Linux architecture
        what = [w for w in what if w == 'player' or (w == 'widget' and args.browser_backend == 'webkitgtk')]
    if args.browser_backend == 'webkitgtk':
        what = [w for w in what if w != 'revbrowser']

    if args.session != 'own' and p.family != 'linux':
        ap.error('--session %s is for Linux' % args.session)
    if args.desktop and p.family != 'linux':
        ap.error('--desktop is for Linux')
    if args.desktop_scale and (p.family != 'linux' or args.session != 'own'):
        ap.error('--desktop-scale is for Linux, with a screen of its own (no --session)')

    lines, problems, temp_dirs, server, session, sample_tree = [], [], [], None, None, False
    desktop = []
    try:
        base = os.environ.get('RUNNER_TEMP') or tempfile.gettempdir()
        work = tempfile.mkdtemp(prefix='oxt-media-', dir=base)
        temp_dirs.append(work)
        args.bin_dir, args.engine = None, None
        lay = rlc.find_layout(args, p, temp_dirs)
        rlc.log('Layout  : %s' % lay.root)
        engine, revbrowser = stage_runtime(lay.tools, p, work)
        rlc.log('Engine  : %s' % engine)

        site = os.path.join(work, 'site')
        os.makedirs(site)
        with open(os.path.join(site, 'index.html'), 'w', encoding='utf-8', newline='\n') as f:
            f.write(PAGE)
        server, port = serve(site)
        media = os.path.join(work, 'media')
        os.makedirs(media)
        write_tone(os.path.join(media, 'oxt-check.wav'))
        for name in VIDEOS:
            shutil.copy(os.path.join(MEDIA, name), media)
        files = [os.path.join(media, n).replace('\\', '/') for n in ('oxt-check.wav',) + VIDEOS]

        env = dict(os.environ)
        env.update({
            'OXT_MEDIA_URL': 'http://127.0.0.1:%d/index.html' % port,
            'OXT_MEDIA_FILES': ','.join(files),
            'OXT_MEDIA_EXTENSIONS': os.path.join(lay.tools, 'Extensions').replace('\\', '/'),
            'OXT_MEDIA_REVBROWSER': revbrowser.replace('\\', '/'),
        })
        if args.snapshots:
            os.makedirs(args.snapshots, exist_ok=True)
            env['OXT_MEDIA_SNAPSHOTS'] = os.path.abspath(args.snapshots).replace('\\', '/')
        cmd = [engine, SCRIPT]
        if p.family == 'linux':
            if args.browser_backend == 'auto':
                env.pop('OXT_BROWSER_BACKEND', None)
            else:
                env['OXT_BROWSER_BACKEND'] = args.browser_backend
            if 'widget' in what:
                rlc.log('Browser : %s' % args.browser_backend)
            # The desktop's name: the runner's own is taken away (a test
            # runs on a desktop with no name unless it gives one)
            for name in DESKTOP_VARIABLES:
                env.pop(name, None)
            if args.desktop:
                env.update(DESKTOPS[args.desktop])
                env['OXT_MEDIA_DESKTOP'] = DESKTOPS[args.desktop]['XDG_CURRENT_DESKTOP']
                rlc.log('Desktop : named %s' % args.desktop)
                lines.append('INFO desktop: %s' % ' '.join('%s=%s' % x for x in sorted(DESKTOPS[args.desktop].items())))
            if 'player' in what:
                if args.player_backend == 'auto':
                    env.pop('OXT_PLAYER_BACKEND', None)
                else:
                    env['OXT_PLAYER_BACKEND'] = args.player_backend
                rlc.log('Player  : %s' % args.player_backend)
                if args.player_backend == 'mplayer' and not os.path.exists(MPLAYER):
                    problems.append('the player needs %s, which is not installed' % MPLAYER)
                if not os.path.exists('/dev/snd'):
                    home = os.path.join(work, 'mplayer')
                    os.makedirs(home)
                    with open(os.path.join(home, 'config'), 'w') as f:
                        f.write('ao=null\n')
                    env['MPLAYER_HOME'] = home
                    rlc.log('No sound card: mplayer plays without sound (ao=null)')
            if args.session == 'wayland':
                sample_tree = 'widget' in what and args.browser_backend == 'cef'
                if sample_tree and not shutil.which('xwininfo'):
                    raise rlc.CheckError('--session wayland needs xwininfo (the package x11-utils)')
                session, session_env, about = wayland_session(work)
                env.update(session_env)
                rlc.log('Session : wayland (%s)' % about)
                lines.append('INFO session: XDG_SESSION_TYPE=wayland WAYLAND_DISPLAY=%s DISPLAY=%s (%s)'
                             % (session_env['WAYLAND_DISPLAY'], session_env['DISPLAY'], about))
            else:
                if args.session == 'wayland-name':
                    # (the name alone: nothing there for a WAYLAND_DISPLAY to name)
                    env['XDG_SESSION_TYPE'] = 'wayland'
                    for name in ('WAYLAND_DISPLAY', 'WAYLAND_SOCKET'):
                        env.pop(name, None)
                    rlc.log('Session : XDG_SESSION_TYPE=wayland alone, with no compositor')
                    lines.append('INFO session: XDG_SESSION_TYPE=wayland alone, on an X display, with no compositor')
                if args.desktop_scale:
                    # A desktop scaled as GNOME scales one: the engine reads
                    # the scale from XSETTINGS (no GDK_SCALE), and a GTK 3
                    # program finds Xft/DPI with the scale in it already
                    for name in ('GDK_SCALE', 'GDK_DPI_SCALE'):
                        env.pop(name, None)
                    try:
                        xvfb, display = hidpi_check.start_xvfb(1280 * args.desktop_scale, 1024 * args.desktop_scale)
                        desktop.append(xvfb)
                        manager = hidpi_check.start_xsettingsd(display, args.desktop_scale, work)
                    except RuntimeError as e:
                        raise rlc.CheckError(str(e))
                    if manager is None:
                        raise rlc.CheckError('--desktop-scale needs xsettingsd')
                    desktop.append(manager)
                    env['DISPLAY'] = display
                    env['OXT_MEDIA_DESKTOP_SCALE'] = str(args.desktop_scale)
                    rlc.log('Desktop : scaled %d times (XSETTINGS, on %s)' % (args.desktop_scale, display))
                    lines.append('INFO desktop: Gdk/WindowScalingFactor %d, Xft/DPI %d, Gdk/UnscaledDPI 96'
                                 % (args.desktop_scale, 96 * args.desktop_scale))
                if not env.get('DISPLAY'):
                    xvfb = shutil.which('xvfb-run')
                    if not xvfb:
                        raise rlc.CheckError('no DISPLAY and no xvfb-run')
                    cmd = [xvfb, '-a', '-s', '-screen 0 1280x1024x24'] + cmd
        missing_mf = windows_media_foundation() if p.family == 'windows' and 'player' in what else []
        if p.family == 'windows' and 'player' in what:
            lines.append('INFO Media Foundation: %s' % ('missing %s' % ', '.join(missing_mf) if missing_mf
                                                        else 'present (%s)' % ', '.join(MEDIA_FOUNDATION_DLLS)))
        known = known_failures(p.family, args.player_backend, missing_mf)
        for name in args.must_play.split(','):
            known.pop(name.strip(), None)
        if p.family == 'windows' and 'player' in what:
            devices = windows_sound_devices()
            lines.append('INFO sound devices: %s' % devices)
            if devices == 'none':
                known.update(NO_SOUND_DEVICE)
        rlc.log('Running : %s' % ' '.join(cmd))
        for part in what:
            result_log = os.path.join(work, 'media-check-%s.log' % part)
            env['OXT_MEDIA_LOG'] = result_log
            env['OXT_MEDIA_WHAT'] = part
            sampler = TreeSampler(env, CHECK_STACK) if sample_tree and part == 'widget' else None
            if sampler:
                sampler.start()
            try:
                proc = subprocess.run(cmd, cwd=work, env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                      timeout=args.timeout)
                code, output = proc.returncode, proc.stdout
            except subprocess.TimeoutExpired as e:
                code, output = None, e.stdout or b''
            finally:
                depth = sampler.stop() if sampler else None
            results = []
            if os.path.exists(result_log):
                with open(result_log, encoding='utf-8', errors='replace') as f:
                    results = [x.rstrip('\r\n') for x in f if x.strip()]
            finished = any(x.startswith('DONE ') for x in results)
            if sampler and finished:
                # (an engine that did not finish is its own problem below)
                results.append(chromium_window_result(depth))
                if depth is None or depth < CHROMIUM_WINDOW_DEPTH:
                    rlc.log('The X window tree with the stack\'s window at its deepest:')
                    for x in (sampler.tree or '(the window was in no sample)').splitlines():
                        if x.strip():
                            rlc.log('  ' + x.rstrip()[:170])
            results = [x for x in results if not x.startswith('DONE ') and not (x.startswith('INFO platform=')
                                                                              and part != what[0])]
            for name, reason in sorted(known.items()):
                mine = [x for x in results if x.split(' ', 1)[-1].startswith('player %s:' % name)]
                if mine and not any(x.startswith('FAIL ') for x in mine):
                    lines.append('INFO player %s plays, though it is listed as known not to (%s)' % (name, reason))
                results = ['KNOWN' + x[4:] + ' [%s]' % reason if x in mine and x.startswith('FAIL ') else x
                           for x in results]
            lines += results
            problems += [x[5:] for x in results if x.startswith('FAIL ')]
            # A process of the browser's that ended by failing the stack
            # protector's check: up to 0.2.8-dp.2 every child Chromium's
            # zygote forked (which has a new canary) ended so, on its way
            # out of the helper's main (libbrowser_cefprocess_lnx.cpp)
            smashed = output.decode('utf-8', 'replace').count(STACK_SMASHED)
            if smashed:
                problems.append('%s: %d of the browser\'s processes ended with "%s"' % (part, smashed, STACK_SMASHED))
            if not finished:
                problems.append('%s: the engine did not finish (%s)'
                                % (part, 'timed out after %d seconds' % args.timeout if code is None
                                   else 'exit status %s' % code))
                tail = output.decode('utf-8', 'replace').splitlines()[-30:]
                if tail:
                    rlc.log('Engine output (%s, last lines):' % part)
                    for x in tail:
                        rlc.log('  ' + x)
    except (rlc.CheckError, OSError) as e:
        problems.append(str(e))
    finally:
        if session:
            end_session(session)
        for proc in reversed(desktop):
            proc.kill()
            proc.wait()
        if server:
            server.shutdown()
        for d in temp_dirs:
            shutil.rmtree(d, ignore_errors=True)

    if args.snapshots and gha() and os.path.isdir(args.snapshots):
        names = sorted(os.listdir(args.snapshots))
        if names:
            rlc.log('::group::Snapshots (base64)')
            for name in names:
                with open(os.path.join(args.snapshots, name), 'rb') as f:
                    rlc.log('%s %s' % (name, base64.b64encode(f.read()).decode('ascii')))
            rlc.log('::endgroup::')
    rlc.log('')
    for x in lines:
        rlc.log(x)
    for msg in problems:
        rlc.log('::error title=Browser and player check::%s' % msg if gha() else 'error: %s' % msg)
    result = 'passed' if not problems else 'FAILED (%d problems)' % len(problems)
    rlc.log('Browser and player check %s.' % result)
    rlc._append('GITHUB_STEP_SUMMARY', '### Browser and player check (%s)\n\n%s\n\nResult: **%s**\n\n'
                % (p.name, '\n'.join('- ' + x for x in lines + ['problem: ' + m for m in problems
                                                                  if 'FAIL ' + m not in lines]), result))
    if args.log:
        with open(args.log, 'w', encoding='utf-8', newline='\n') as f:
            f.write('\n'.join(lines + problems + [result]) + '\n')
    return 1 if problems else 0


if __name__ == '__main__':
    sys.exit(main())
