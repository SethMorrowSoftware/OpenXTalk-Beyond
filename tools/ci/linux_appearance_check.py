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

"""Check that a Linux standalone of an installed OXT-Beyond follows a dark
GTK theme.

  python tools/ci/linux_appearance_check.py (--install DIR | --package FILE)
      [--platform P] [--log FILE] [--timeout SECONDS]

On Linux GTK draws the native controls, so the engine's appearance is the
GTK theme's: dark when the background of a window the theme has not
painted is dark (engine/src/lnxgtktheme.cpp, MCLinuxGtkThemeIsDark; the
way OpenXTalk Lite 1.15's IDE told, since a theme's name does not say).

The layout's own standalone runtime is staged as media_check.py does and
runs tools/ci/linux-appearance-check.livecodescript twice under Xvfb, with
GTK2_RC_FILES naming a gtkrc that gives every widget a light background,
then a dark one. With the light theme the systemAppearance and the
effective appearances must be "light", with the dark theme "dark"
(the appAppearance "light" changes nothing on Linux), and the effective
backgroundColor of a stack without colours must be the theme's.

Exit status 0 when every check passed, 1 otherwise. Only the Python 3
standard library is used (3.8 or later).
"""

import argparse
import os
import shutil
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(os.path.dirname(HERE), 'oxt'))
sys.path.insert(0, HERE)
import media_check  # noqa: E402
import package  # noqa: E402
import run_livecode_check as rlc  # noqa: E402

SCRIPT = os.path.join(HERE, 'linux-appearance-check.livecodescript')

# name: (background, text, the appearance the engine must report)
THEMES = {
    'light': ('#e8e8e8', '#101010', 'light'),
    'dark': ('#303030', '#e8e8e8', 'dark'),
}

GTKRC = """style "oxt-appearance-check"
{
  bg[NORMAL] = "%(bg)s"
  bg[PRELIGHT] = "%(bg)s"
  fg[NORMAL] = "%(fg)s"
  base[NORMAL] = "%(bg)s"
  text[NORMAL] = "%(fg)s"
}
class "GtkWidget" style "oxt-appearance-check"
"""


def rgb(hex_colour):
    return ','.join(str(int(hex_colour[i:i + 2], 16)) for i in (1, 3, 5))


def main(argv=None):
    ap = argparse.ArgumentParser(description='Check that a Linux standalone follows a dark GTK theme.')
    ap.add_argument('--install', metavar='DIR', help='installed layout')
    ap.add_argument('--package', metavar='FILE', help='a package to extract and check like --install')
    ap.add_argument('--platform', choices=[n for n in package.PLATFORMS if n.startswith('linux-')],
                    help='the layout (default: this machine\'s, %s)' % rlc.default_platform())
    ap.add_argument('--log', metavar='FILE', help='write the results here too')
    ap.add_argument('--timeout', type=int, default=120, help='seconds for each engine run (default: %(default)s)')
    args = ap.parse_args(argv)
    if bool(args.install) == bool(args.package):
        ap.error('pass --install or --package')
    p = package.PLATFORMS[args.platform or rlc.default_platform()]
    if p.family != 'linux':
        ap.error('this check is for Linux')

    lines, problems, temp_dirs = [], [], []
    try:
        base = os.environ.get('RUNNER_TEMP') or tempfile.gettempdir()
        work = tempfile.mkdtemp(prefix='oxt-appearance-', dir=base)
        temp_dirs.append(work)
        args.bin_dir, args.engine = None, None
        lay = rlc.find_layout(args, p, temp_dirs)
        rlc.log('Layout  : %s' % lay.root)
        engine, _ = media_check.stage_runtime(lay.tools, p, work)
        rlc.log('Engine  : %s' % engine)
        cmd = [engine, SCRIPT]
        if not os.environ.get('DISPLAY'):
            xvfb = shutil.which('xvfb-run')
            if not xvfb:
                raise rlc.CheckError('no DISPLAY and no xvfb-run')
            cmd = [xvfb, '-a', '-s', '-screen 0 1280x1024x24'] + cmd
        rlc.log('Running : %s' % ' '.join(cmd))

        for name, (bg, fg, expected) in THEMES.items():
            rc = os.path.join(work, 'gtkrc-%s' % name)
            with open(rc, 'w', encoding='utf-8', newline='\n') as f:
                f.write(GTKRC % {'bg': bg, 'fg': fg})
            result_log = os.path.join(work, 'appearance-%s.log' % name)
            env = dict(os.environ)
            env['GTK2_RC_FILES'] = rc
            env['OXT_APPEARANCE_LOG'] = result_log
            # No desktop's theme or settings daemon may decide instead
            env.pop('GTK_THEME', None)
            try:
                proc = subprocess.run(cmd, cwd=work, env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                      timeout=args.timeout)
                code, output = proc.returncode, proc.stdout
            except subprocess.TimeoutExpired as e:
                code, output = None, e.stdout or b''
            values, finished = {}, False
            if os.path.exists(result_log):
                with open(result_log, encoding='utf-8', errors='replace') as f:
                    for x in f:
                        x = x.rstrip('\r\n')
                        if x == 'DONE':
                            finished = True
                        elif x.startswith('VALUE ') and '=' in x:
                            k, v = x[6:].split('=', 1)
                            values[k] = v
            for k, v in values.items():
                lines.append('INFO %s theme: %s = %s' % (name, k, v))
            if not finished:
                problems.append('%s theme: the engine did not finish (%s)'
                                % (name, 'timed out after %d seconds' % args.timeout if code is None
                                   else 'exit status %s' % code))
                tail = output.decode('utf-8', 'replace').splitlines()[-30:]
                if tail:
                    rlc.log('Engine output (%s theme, last lines):' % name)
                    for x in tail:
                        rlc.log('  ' + x)
                continue
            if 'error' in values:
                problems.append('%s theme: script error %s' % (name, values['error']))
                continue
            expect = {
                'systemAppearance': expected,
                'effective appAppearance light': expected,
                'effective appAppearance system': expected,
                'effective stackAppearance': expected,
                'effective backgroundColor': rgb(bg),
            }
            for k, want in expect.items():
                got = values.get(k)
                if got == want:
                    lines.append('PASS %s theme: %s is %s' % (name, k, want))
                else:
                    lines.append('FAIL %s theme: %s is %s, not %s' % (name, k, got, want))
                    problems.append('%s theme: %s is %s, not %s' % (name, k, got, want))
    except (rlc.CheckError, OSError) as e:
        problems.append(str(e))
    finally:
        for d in temp_dirs:
            shutil.rmtree(d, ignore_errors=True)

    rlc.log('')
    for x in lines:
        rlc.log(x)
    for msg in problems:
        rlc.log('::error title=Linux appearance check::%s' % msg if media_check.gha() else 'error: %s' % msg)
    result = 'passed' if not problems else 'FAILED (%d problems)' % len(problems)
    rlc.log('Linux appearance check %s.' % result)
    rlc._append('GITHUB_STEP_SUMMARY', '### Linux appearance check (%s)\n\n%s\n\nResult: **%s**\n\n'
                % (p.name, '\n'.join('- ' + x for x in lines + ['problem: ' + m for m in problems]), result))
    if args.log:
        with open(args.log, 'w', encoding='utf-8') as f:
            f.write('\n'.join(lines + ['problem: ' + m for m in problems] + ['Linux appearance check %s.' % result])
                    + '\n')
    return 0 if not problems else 1


if __name__ == '__main__':
    sys.exit(main())
