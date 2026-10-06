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

With --appearance dark the script also sets the IDE to follow the system
(View > Appearance), so the IDE is dark wherever the system is.

Everything is printed, for the CI log: the script's lines (INFO, ERROR,
SHOT, STEP and DONE) and every snapshot as lines tools/ci/print_images.py
turns back into PNG files ("IMAGE <appearance>/<file> <part>/<parts>
<base64>"). The snapshots also stay in <out>/shots. Exit status 0 when the
script got to the end with every step done and no script error in the IDE's
windows, 1 otherwise. Only the Python 3 standard library is used (3.8 or
later).
"""

import argparse
import base64
import os
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
            finally:
                stop(proc)
        log('The script %s.' % status)
        if not finished:
            problems.append('the script %s' % status)
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
