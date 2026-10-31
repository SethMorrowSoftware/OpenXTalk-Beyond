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

"""Check that the systemAppearance of an OXT-Beyond engine on Linux follows
the desktop's light or dark setting while the useDesktopAppearance is true,
and only then.

  python3 tools/ci/appearance_check.py --engine FILE [--log FILE]
      [--timeout SECONDS]

GNOME 42 and later switch between light and dark with the GSettings key
color-scheme of org.gnome.desktop.interface. The check gives the engine a
desktop of its own: an X server (Xvfb) and GSettings' keyfile backend
(GSETTINGS_BACKEND=keyfile) in a temporary XDG_CONFIG_HOME, whose keyfile
sets color-scheme to prefer-dark. The engine runs
tools/ci/appearance-check.livecodescript, which switches the setting by
replacing the keyfile, as a settings tool would, and logs each step:

  - as it starts, the useDesktopAppearance is false and the
    systemAppearance "light" (as it always was on Linux);
  - set to true on the dark desktop: "dark", and one
    systemAppearanceChanged;
  - the desktop to "default": "light", and a message;
  - to "prefer-dark" again: "dark", and a message;
  - set back to false: "light", and a message;
  - the desktop switched again while it is false: "light", and no message.

It is a standalone engine (the runtime's Standalone), which opens that
script-only stack as a user's standalone opens its stack. Needs Xvfb and
the schema org.gnome.desktop.interface with its color-scheme key (the
package gsettings-desktop-schemas, 42 or later).

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
SCRIPT = os.path.join(HERE, 'appearance-check.livecodescript')

# step: (systemAppearance, messages so far), as the script logs them
EXPECTED = (
    ('OPTIN', 'dark', 1),
    ('SWITCH', 'light', 2),
    ('BACK', 'dark', 3),
    ('OPTOUT', 'light', 4),
    ('QUIET', 'light', 4),
)

KEYFILE_GROUP = '[org/gnome/desktop/interface]'


def log(msg=''):
    print(msg, flush=True)


def keyfile_text(scheme):
    return "%s\ncolor-scheme='%s'\n" % (KEYFILE_GROUP, scheme)


def evaluate(result):
    """[(name, ok, detail)] for the engine's log lines."""
    steps = {}
    for line in result:
        words = line.split()
        if words and words[0] not in ('INFO', 'WROTE', 'MESSAGE', 'QUIT', 'ERROR'):
            steps[words[0]] = words[1:]
    checks = []
    errors = [x for x in result if x.startswith('ERROR')]
    checks.append(('the script ran without an error', not errors, '; '.join(errors)))
    default = steps.get('DEFAULT')
    checks.append(('as it starts, the useDesktopAppearance is false and the systemAppearance light',
                   default is not None and default[:3] == ['false', 'light', '0'],
                   'logged %r' % (default,)))
    for name, appearance, count in EXPECTED:
        got = steps.get(name)
        checks.append(('%s: the systemAppearance is %s after %d systemAppearanceChanged' % (name, appearance, count),
                       got is not None and got[:2] == [appearance, str(count)],
                       'logged %r' % (got,)))
    checks.append(('the engine quit when it was done', any(x.startswith('QUIT') for x in result), ''))
    return checks


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


def schema_note():
    """What gsettings says about the key, for a failure's message."""
    gsettings = shutil.which('gsettings')
    if not gsettings:
        return 'gsettings is not installed, so the schema could not be looked at'
    try:
        out = subprocess.run([gsettings, 'list-keys', 'org.gnome.desktop.interface'], capture_output=True,
                             text=True, timeout=20)
    except (OSError, subprocess.SubprocessError) as e:
        return 'gsettings failed: %s' % e
    if out.returncode != 0:
        return 'the schema org.gnome.desktop.interface is not installed (gsettings-desktop-schemas)'
    if 'color-scheme' not in out.stdout.split():
        return 'the schema org.gnome.desktop.interface has no color-scheme key (gsettings-desktop-schemas before 42)'
    return 'the schema has the color-scheme key'


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    ap.add_argument('--engine', required=True, help='the standalone engine to run')
    ap.add_argument('--log', help='write the results to this file too')
    ap.add_argument('--timeout', type=int, default=90, help='seconds the engine may take')
    args = ap.parse_args(argv)

    if not sys.platform.startswith('linux'):
        log('The appearance check is for Linux only')
        return 0
    engine = os.path.abspath(args.engine)

    lines, problems = [], []
    work = tempfile.mkdtemp(prefix='oxt-appearance-')
    xvfb = None
    try:
        config = os.path.join(work, 'config')
        settings = os.path.join(config, 'glib-2.0', 'settings')
        os.makedirs(settings)
        keyfile = os.path.join(settings, 'keyfile')
        with open(keyfile, 'w', encoding='utf-8') as f:
            f.write(keyfile_text('prefer-dark'))
        result_log = os.path.join(work, 'engine.log')

        xvfb, display_name = start_xvfb()
        log('X server %s, engine %s' % (display_name, engine))
        env = dict(os.environ)
        env.pop('WAYLAND_DISPLAY', None)
        env.update({'DISPLAY': display_name, 'GSETTINGS_BACKEND': 'keyfile', 'XDG_CONFIG_HOME': config,
                    'OXT_APPEARANCE_KEYFILE': keyfile, 'OXT_APPEARANCE_LOG': result_log})
        try:
            proc = subprocess.run([engine, SCRIPT], cwd=work, env=env, stdout=subprocess.PIPE,
                                  stderr=subprocess.STDOUT, timeout=args.timeout)
            code, output = proc.returncode, proc.stdout.decode('utf-8', 'replace')
        except subprocess.TimeoutExpired as e:
            code, output = None, (e.stdout or b'').decode('utf-8', 'replace')
        result = []
        if os.path.exists(result_log):
            with open(result_log, encoding='utf-8', errors='replace') as f:
                result = [x.rstrip('\r\n') for x in f if x.strip()]
        lines += ['INFO engine: ' + x for x in result]
        if code is None:
            lines.append('INFO the engine timed out after %d seconds' % args.timeout)
        for name, ok, detail in evaluate(result):
            lines.append('%s %s%s' % ('PASS' if ok else 'FAIL', name, (': ' + detail) if detail and not ok else ''))
            if not ok:
                problems.append('%s%s' % (name, (': ' + detail) if detail else ''))
        if problems:
            lines.append('INFO ' + schema_note())
            if output.strip():
                lines.append('INFO engine output: ' + output[-2000:])
    except RuntimeError as e:
        problems.append(str(e))
        lines.append('FAIL ' + str(e))
    finally:
        if xvfb is not None:
            xvfb.kill()
            xvfb.wait()
        shutil.rmtree(work, ignore_errors=True)

    log('\n'.join(lines))
    if args.log:
        with open(args.log, 'w', encoding='utf-8') as f:
            f.write('\n'.join(lines) + '\n')
    if os.environ.get('GITHUB_ACTIONS') == 'true':
        for p in problems:
            print('::error title=Appearance check::%s' % p.replace('\n', ' '))
        summary = os.environ.get('GITHUB_STEP_SUMMARY')
        if summary:
            with open(summary, 'a', encoding='utf-8') as f:
                f.write('### Appearance check (Linux)\n\n```\n%s\n```\n' % '\n'.join(lines))
    return 1 if problems else 0


if __name__ == '__main__':
    sys.exit(main())
