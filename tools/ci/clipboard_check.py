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

"""Check that text an OXT-Beyond engine puts on the clipboard on Linux is
still there after the engine quits, when a clipboard manager runs.

  python3 tools/ci/clipboard_check.py --engine FILE [--log FILE]
      [--timeout SECONDS]

On X11 the data of a selection stays with the application that owns it,
so the CLIPBOARD goes when that application quits, unless a clipboard
manager keeps it: the freedesktop.org protocol has the owner ask the
owner of the CLIPBOARD_MANAGER selection to SAVE_TARGETS, and the manager
then reads the data (with MULTIPLE, as the managers of GNOME and Xfce
do) and takes the CLIPBOARD over. The engine does this as it quits (the
Linux clipboard's FlushData).

The check starts its own X server (Xvfb) and runs three things on it:

  1. With no clipboard manager, the engine sets the clipboard and quits:
     it must quit at once (it waits for no manager), and the text goes
     with it, as before.
  2. With this script's own clipboard manager (--manager, a small one
     that does what the managers of GNOME and Xfce do), the engine sets
     the clipboard and quits: the manager must have been asked to save
     it, and reading the CLIPBOARD afterwards must give the text.
  3. The same, with text outside ASCII.

The engine runs tools/ci/clipboard-check.livecodescript. It is a
standalone engine (the runtime's Standalone, or the bin folder's
standalone-community), which opens that script-only stack as a user's
standalone opens its stack. Needs Xvfb and python3-xlib.

Exit status 0 when every check passed, 1 otherwise. Under GitHub Actions
a failure is an annotation and the results go into the job summary.
"""

import argparse
import os
import select
import shutil
import subprocess
import sys
import tempfile
import time

HERE = os.path.dirname(os.path.abspath(__file__))
SCRIPT = os.path.join(HERE, 'clipboard-check.livecodescript')


def log(msg=''):
    print(msg, flush=True)


# ---------------------------------------------------------------------------
# The clipboard manager (run as a process of its own, with --manager)

def run_manager(display_name, ready_file, log_file):
    from Xlib import X, Xatom, display
    from Xlib.protocol import event

    d = display.Display(display_name)
    root = d.screen().root
    win = root.create_window(0, 0, 1, 1, 0, X.CopyFromParent)

    def atom(name):
        return d.intern_atom(name)

    CLIPBOARD, MANAGER = atom('CLIPBOARD'), atom('CLIPBOARD_MANAGER')
    SAVE_TARGETS, TARGETS = atom('SAVE_TARGETS'), atom('TARGETS')
    MULTIPLE, ATOM_PAIR = atom('MULTIPLE'), atom('ATOM_PAIR')

    out = open(log_file, 'a', encoding='utf-8')

    def note(text):
        out.write(text + '\n')
        out.flush()

    win.set_selection_owner(MANAGER, X.CurrentTime)
    d.flush()
    if d.get_selection_owner(MANAGER) != win:
        note('ERROR could not own CLIPBOARD_MANAGER')
        return 1

    saved = {}          # target atom -> (type atom, format, data)
    pending = None      # the SAVE_TARGETS request being served
    with open(ready_file, 'w') as f:
        f.write('ready\n')
    note('READY')

    def notify(req, prop):
        ev = event.SelectionNotify(time=req.time, requestor=req.requestor,
                                   selection=req.selection, target=req.target,
                                   property=prop)
        req.requestor.send_event(ev)
        d.flush()

    # Asks the owner of the CLIPBOARD for the targets with MULTIPLE, as the
    # managers of GNOME and Xfce do; False if there is nothing to ask for
    def ask_multiple(targets, when):
        skip = (TARGETS, MULTIPLE, SAVE_TARGETS, atom('TIMESTAMP'), atom('DELETE'),
                atom('INSERT_PROPERTY'), atom('INSERT_SELECTION'), atom('PIXMAP'))
        pairs = []
        for t in targets:
            if t not in skip:
                pairs += [t, t]
        if not pairs:
            return False
        win.change_property(MULTIPLE, ATOM_PAIR, 32, pairs)
        win.convert_selection(CLIPBOARD, MULTIPLE, MULTIPLE, when)
        d.flush()
        return True

    while True:
        ev = d.next_event()
        if ev.type == X.SelectionRequest and ev.selection == MANAGER:
            if ev.target == SAVE_TARGETS:
                targets = []
                if ev.property != X.NONE:
                    p = ev.requestor.get_full_property(ev.property, Xatom.ATOM)
                    if p is not None:
                        targets = list(p.value)
                note('SAVE_TARGETS %s' % (' '.join(d.get_atom_name(t) for t in targets) or '(all)'))
                pending = ev
                saved = {}
                if targets:
                    ask_multiple(targets, ev.time)
                else:
                    # No list: save every target the owner offers
                    win.convert_selection(CLIPBOARD, TARGETS, TARGETS, ev.time)
                    d.flush()
            else:
                notify(ev, X.NONE)
        elif ev.type == X.SelectionNotify and ev.selection == CLIPBOARD and pending is not None \
                and ev.target == TARGETS:
            p = win.get_full_property(TARGETS, Xatom.ATOM) if ev.property != X.NONE else None
            targets = list(p.value) if p is not None else []
            note('TARGETS %s' % ' '.join(d.get_atom_name(t) for t in targets))
            if not ask_multiple(targets, pending.time):
                notify(pending, X.NONE)
                pending = None
        elif ev.type == X.SelectionNotify and ev.selection == CLIPBOARD and pending is not None:
            if ev.property == X.NONE:
                note('MULTIPLE refused')
                notify(pending, X.NONE)
                pending = None
                continue
            p = win.get_full_property(MULTIPLE, ATOM_PAIR)
            values = list(p.value) if p is not None else []
            for i in range(0, len(values) - 1, 2):
                target, prop = values[i], values[i + 1]
                if prop == X.NONE:
                    note('NOT CONVERTED %s' % d.get_atom_name(target))
                    continue
                data = win.get_full_property(prop, X.AnyPropertyType)
                if data is not None:
                    value = data.value
                    if isinstance(value, str):
                        value = value.encode('latin-1')
                    saved[target] = (data.property_type, data.format, value)
                    note('SAVED %s %d bytes' % (d.get_atom_name(target), len(value)))
            win.set_selection_owner(CLIPBOARD, ev.time)
            d.flush()
            notify(pending, pending.property if saved else X.NONE)
            note('SAVED_ALL %d' % len(saved))
            pending = None
        elif ev.type == X.SelectionRequest and ev.selection == CLIPBOARD:
            prop = ev.property if ev.property != X.NONE else ev.target
            if ev.target == TARGETS:
                ev.requestor.change_property(prop, Xatom.ATOM, 32, [TARGETS] + list(saved))
                notify(ev, prop)
            elif ev.target in saved:
                type_, format_, value = saved[ev.target]
                ev.requestor.change_property(prop, type_, format_, value)
                notify(ev, prop)
            else:
                notify(ev, X.NONE)


# ---------------------------------------------------------------------------
# Reading the CLIPBOARD, as a pasting application does

def read_clipboard(display_name, timeout=5.0):
    from Xlib import X, display

    d = display.Display(display_name)
    win = d.screen().root.create_window(0, 0, 1, 1, 0, X.CopyFromParent)
    CLIPBOARD, UTF8 = d.intern_atom('CLIPBOARD'), d.intern_atom('UTF8_STRING')
    PROP = d.intern_atom('OXT_CLIPBOARD_CHECK')
    if d.get_selection_owner(CLIPBOARD) == X.NONE:
        d.close()
        return None
    win.convert_selection(CLIPBOARD, UTF8, PROP, X.CurrentTime)
    d.flush()
    end = time.time() + timeout
    text = None
    while time.time() < end:
        if not d.pending_events():
            select.select([d.fileno()], [], [], 0.1)
            continue
        ev = d.next_event()
        if ev.type == X.SelectionNotify:
            if ev.property != X.NONE:
                p = win.get_full_property(PROP, X.AnyPropertyType)
                if p is not None:
                    value = p.value
                    if isinstance(value, str):
                        value = value.encode('latin-1')
                    text = value.decode('utf-8', 'replace')
            break
    d.close()
    return text


# ---------------------------------------------------------------------------
# The check

def start_xvfb():
    xvfb = shutil.which('Xvfb')
    if not xvfb:
        raise RuntimeError('Xvfb is not installed')
    r, w = os.pipe()
    proc = subprocess.Popen([xvfb, '-displayfd', str(w), '-screen', '0', '1280x1024x24', '-nolisten', 'tcp'],
                            pass_fds=(w,), stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    os.close(w)
    number = b''
    while not number.endswith(b'\n'):
        ready, _, _ = select.select([r], [], [], 30)
        if not ready:
            proc.kill()
            raise RuntimeError('Xvfb did not start')
        chunk = os.read(r, 16)
        if not chunk:
            raise RuntimeError('Xvfb did not start')
        number += chunk
    os.close(r)
    return proc, ':' + number.decode().strip()


def run_engine(engine, display_name, text, work, timeout):
    result_log = os.path.join(work, 'engine.log')
    if os.path.exists(result_log):
        os.remove(result_log)
    env = dict(os.environ)
    env.update({'DISPLAY': display_name, 'OXT_CLIPBOARD_TEXT': text, 'OXT_CLIPBOARD_LOG': result_log})
    started = time.time()
    try:
        proc = subprocess.run([engine, SCRIPT], cwd=work, env=env, stdout=subprocess.PIPE,
                              stderr=subprocess.STDOUT, timeout=timeout)
        code, output = proc.returncode, proc.stdout.decode('utf-8', 'replace')
    except subprocess.TimeoutExpired as e:
        code, output = None, (e.stdout or b'').decode('utf-8', 'replace')
    elapsed = time.time() - started
    lines = []
    if os.path.exists(result_log):
        with open(result_log, encoding='utf-8', errors='replace') as f:
            lines = [x.rstrip('\r\n') for x in f if x.strip()]
    return code, output, lines, elapsed


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    ap.add_argument('--engine', help='the standalone engine to run')
    ap.add_argument('--log', help='write the results to this file too')
    ap.add_argument('--timeout', type=int, default=60, help='seconds each engine run may take')
    ap.add_argument('--manager', nargs=3, metavar=('DISPLAY', 'READY', 'LOG'), help=argparse.SUPPRESS)
    args = ap.parse_args(argv)

    if args.manager:
        return run_manager(*args.manager)
    if not args.engine:
        ap.error('--engine is required')
    if not sys.platform.startswith('linux'):
        log('The clipboard check is for Linux only')
        return 0
    engine = os.path.abspath(args.engine)

    lines, problems = [], []

    def check(name, ok, detail=''):
        lines.append('%s %s%s' % ('PASS' if ok else 'FAIL', name, (': ' + detail) if detail and not ok else ''))
        if not ok:
            problems.append('%s%s' % (name, (': ' + detail) if detail else ''))

    work = tempfile.mkdtemp(prefix='oxt-clipboard-')
    xvfb, display_name = start_xvfb()
    manager = None
    try:
        log('X server %s, engine %s' % (display_name, engine))

        # 1. No clipboard manager: the engine quits at once, as before
        code, output, result, elapsed = run_engine(engine, display_name, 'OXT check without a manager',
                                                   work, args.timeout)
        lines += ['INFO ' + x for x in result if x.startswith('INFO ')]
        check('without a manager: the engine set the clipboard', 'SET true' in result,
              'engine log: %r, exit status %s, output: %s' % (result, code, output[-2000:]))
        check('without a manager: the engine quit within 5 seconds', code is not None and elapsed < 5,
              '%.1f seconds, exit status %s' % (elapsed, code))
        lines.append('INFO without a manager the engine ran for %.1f seconds' % elapsed)

        # 2 and 3. With a clipboard manager: the text outlives the engine
        manager_log = os.path.join(work, 'manager.log')
        ready = os.path.join(work, 'manager.ready')
        manager = subprocess.Popen([sys.executable, os.path.abspath(__file__), '--manager',
                                    display_name, ready, manager_log])
        end = time.time() + 15
        while not os.path.exists(ready) and time.time() < end and manager.poll() is None:
            time.sleep(0.1)
        if not os.path.exists(ready):
            raise RuntimeError('the clipboard manager did not start (python3-xlib installed?)')

        for label, text in (('ASCII text', 'OXT clipboard check %d' % os.getpid()),
                            ('text outside ASCII', 'OXT été ☃ \U0001F600 %d' % os.getpid())):
            code, output, result, elapsed = run_engine(engine, display_name, text, work, args.timeout)
            check('%s: the engine set the clipboard' % label, 'SET true' in result,
                  'engine log: %r, exit status %s, output: %s' % (result, code, output[-2000:]))
            check('%s: the engine quit' % label, code is not None,
                  'timed out after %d seconds' % args.timeout)
            lines.append('INFO with a manager the engine ran for %.1f seconds' % elapsed)
            got = read_clipboard(display_name)
            check('%s: the clipboard holds the text after the engine quit' % label, got == text,
                  'read %r, expected %r' % (got, text))
        with open(manager_log, encoding='utf-8', errors='replace') as f:
            lines += ['INFO manager: ' + x.rstrip('\n') for x in f if x.strip()]
    except RuntimeError as e:
        problems.append(str(e))
        lines.append('FAIL ' + str(e))
    finally:
        if manager is not None:
            manager.kill()
            manager.wait()
        xvfb.kill()
        xvfb.wait()
        shutil.rmtree(work, ignore_errors=True)

    log('\n'.join(lines))
    if args.log:
        with open(args.log, 'w', encoding='utf-8') as f:
            f.write('\n'.join(lines) + '\n')
    if os.environ.get('GITHUB_ACTIONS') == 'true':
        for p in problems:
            print('::error title=Clipboard check::%s' % p.replace('\n', ' '))
        summary = os.environ.get('GITHUB_STEP_SUMMARY')
        if summary:
            with open(summary, 'a', encoding='utf-8') as f:
                f.write('### Clipboard check\n\n```\n%s\n```\n' % '\n'.join(lines))
    log('Clipboard check %s' % ('passed' if not problems else 'FAILED: %d problem(s)' % len(problems)))
    return 1 if problems else 0


if __name__ == '__main__':
    sys.exit(main())
