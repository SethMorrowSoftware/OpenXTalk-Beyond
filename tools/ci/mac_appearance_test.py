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

"""The light and dark appearance of OXT-Beyond on macOS, with a user interface.

  python3 tools/ci/mac_appearance_test.py --app <OXT-Beyond.app> --out <folder>
                                          [--timeout <seconds>]
  python3 tools/ci/mac_appearance_test.py --engine <file> --out <folder> ...

The other tests run the engine with -ui, where there is no appearance: the
systemAppearance is always "light". This runs the installed app's engine
with a user interface, four times, with tools/ci/render-test.livecodescript
as its home stack (copied to <run>/tools/Startup.rev, REV_TOOLS_PATH set to
that folder, as tools/ci/render-test.ps1 does on Windows), rendering S1 and
S2 only (OXT_RENDER_SCENARIOS). The Mac is set to dark or light first, as a
user's Appearance setting is stored:

  defaults write -g AppleInterfaceStyle Dark     (dark)
  defaults delete -g AppleInterfaceStyle         (light)

  run  the Mac  appAppearance  stacks drawn
  M1   dark     system         dark
  M2   dark     (default)      light
  M3   light    system         light
  M4   light    (default)      light

Checked, in every run, with render_check.py's measurements:

* the systemAppearance is exactly the Mac's setting, "dark" or "light"
  (read afresh from the preferences, MCMacPlatformReadSystemAppearanceIsDark
  in engine/src/mac-core.mm);
* the appAppearance is "light" before the script sets it, and the effective
  appAppearance is the "stacks drawn" column (MCAppearanceIsDark,
  engine/src/appearance.cpp);
* S2, a stack with no colours: its card (s2-card) has a mean L below 60
  when drawn dark and above 200 when drawn light;
* S1, the colours of the owner's libMQTTxt stack (built by the script): the
  black text of its white input field (s1-host) is at least 7:1 against the
  field, dark or not.

The Mac's setting is restored at the end. Every check prints one line,
"PASS <run> <check>: ..." or "FAIL <run> <check>: ...", the last line is
"SUMMARY passed=<n> failed=<n>", and the exit code is the number of failed
checks (at most 100). The images, render.txt and the engine's output of each
run are left in <folder>/<run>.
"""

import argparse
import os
import shutil
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import render_check  # noqa: E402

SCRIPT = os.path.join(HERE, 'render-test.livecodescript')
SCENARIOS = 's1,s2'

# (run, the Mac's setting, OXT_RENDER_APPEARANCE, what stacks are drawn in)
RUNS = [
    ('M1', 'dark', 'system', 'dark'),
    ('M2', 'dark', '', 'light'),
    ('M3', 'light', 'system', 'light'),
    ('M4', 'light', '', 'light'),
]

S2_DARK_MAX = 60
S2_LIGHT_MIN = 200


def defaults(*args):
    """Runs defaults(1) and gives (exit code, output)."""
    proc = subprocess.run(('defaults',) + args, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    return proc.returncode, proc.stdout.decode('utf-8', 'replace').strip()


def read_mac_setting():
    """The AppleInterfaceStyle of the global domain, or None when not set."""
    code, out = defaults('read', '-g', 'AppleInterfaceStyle')
    return out if code == 0 and out else None


def set_mac_setting(value):
    """Sets AppleInterfaceStyle, or removes it for None (a light Mac)."""
    if value is None:
        # Fails when it is not set, which is what is wanted
        defaults('delete', '-g', 'AppleInterfaceStyle')
    else:
        code, out = defaults('write', '-g', 'AppleInterfaceStyle', value)
        if code != 0:
            raise RuntimeError('defaults write -g AppleInterfaceStyle %s failed: %s' % (value, out))


def run_engine(engine, folder, appearance, timeout):
    """Runs the engine with the render test as its home stack; gives
    (exit code or None when it timed out, the images folder)."""
    tools = os.path.join(folder, 'tools')
    images = os.path.join(folder, 'images')
    for path in (tools, images):
        if os.path.isdir(path):
            shutil.rmtree(path)
        os.makedirs(path)
    shutil.copyfile(SCRIPT, os.path.join(tools, 'Startup.rev'))
    env = dict(os.environ)
    env['REV_TOOLS_PATH'] = tools
    env['OXT_RENDER_OUT'] = images
    env['OXT_RENDER_APPEARANCE'] = appearance
    env['OXT_RENDER_SCENARIOS'] = SCENARIOS
    with open(os.path.join(folder, 'engine-stdout.txt'), 'wb') as out, \
            open(os.path.join(folder, 'engine-stderr.txt'), 'wb') as err:
        proc = subprocess.Popen([engine], cwd=tools, env=env, stdout=out, stderr=err)
        try:
            return proc.wait(timeout=timeout), images
        except subprocess.TimeoutExpired:
            proc.kill()
            proc.wait()
            return None, images


def shot(shots, name):
    for s in shots:
        if s[1] == name:
            return s
    return None


def check_run(report, images, mac, drawn, code, timeout):
    if code is None:
        report.check('engine run', False, 'the engine did not finish within %d seconds (see engine-stdout.txt); '
                     'it may not have opened Startup.rev from REV_TOOLS_PATH '
                     '(engine/src/environment/stackbehavior.livecodescript)' % timeout)
    try:
        info, shots = render_check.read_manifest(images)
    except (IOError, OSError) as e:
        report.check('engine run', False, 'cannot read render.txt in %s (exit code %s): %s' % (images, code, e))
        return
    if 'error' in info:
        report.check('engine run', False, 'the render script stopped with an error: %s' % info['error'])
    if info.get('done') != 'true':
        report.check('engine run', False, 'render.txt is incomplete (no "done" line, exit code %s); see the '
                     'engine output' % code)
    elif code is not None:
        report.check('engine run', True, 'exit code %s, %s' % (code, info.get('version', '')))

    system = info.get('systemAppearance', '')
    report.check('system appearance', system == mac, 'the systemAppearance is "%s"%s' % (
        system, '' if system == mac else ', FAILED: expected "%s", the AppleInterfaceStyle just set '
        '(MCMacPlatformReadSystemAppearanceIsDark, engine/src/mac-core.mm)' % mac))
    if info.get('hasAppAppearance') != 'true':
        report.check('appAppearance', False, 'this engine has no appAppearance')
        return
    start = info.get('appAppearanceAtStart', '')
    report.check('appAppearance default', start == 'light', 'the appAppearance is "%s" before the test sets it%s' % (
        start, '' if start == 'light' else ', FAILED: expected "light" (MCappappearance, engine/src/appearance.cpp)'))
    effective = info.get('effectiveAppAppearance', '')
    report.check('effective appAppearance', effective == drawn,
                 'the effective appAppearance is "%s" (the appAppearance "%s", the systemAppearance "%s")%s' % (
                     effective, info.get('appAppearance', ''), system, '' if effective == drawn else
                     ', FAILED: expected "%s" (MCAppearanceIsDark, engine/src/appearance.cpp)' % drawn))

    # S2: the card of a stack that sets no colours
    card = shot(shots, 's2-card')
    if card is None or len(card) < 4:
        report.check('s2-card colour', False, 'render.txt has no s2-card shot')
    else:
        try:
            w, h, rows = render_check.read_png(os.path.join(images, card[2]))
            box = render_check.region_box(render_check.parse_region(card[3]) or (0, 0, w, h), w, h)
            mean = render_check.box_mean(rows, box or (0, 0, w, h))
            if drawn == 'dark':
                ok, want = mean < S2_DARK_MAX, 'below %d' % S2_DARK_MAX
            else:
                ok, want = mean > S2_LIGHT_MIN, 'above %d' % S2_LIGHT_MIN
            report.check('s2-card colour', ok, 'mean L=%.0f of %s, %s %s (drawn %s; getdefaultcolors in '
                         'engine/src/desktop-dc.cpp)' % (mean, card[2], 'expected' if ok else 'FAILED: expected',
                                                         want, drawn))
        except Exception as e:  # a broken image is a failure, not a crash
            report.check('s2-card colour', False, 'cannot measure %s: %s' % (card[2], e))

    # S1: the input field's own text, black on its white fill
    host = shot(shots, 's1-host')
    if host is None or len(host) < 4:
        report.check('s1-host contrast', False, 'render.txt has no s1-host shot')
    else:
        render_check.check_text(report, images, 's1-host', host[2], host[3])


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    where = parser.add_mutually_exclusive_group(required=True)
    where.add_argument('--app', help='OXT-Beyond.app (its engine is Contents/MacOS/OXT-Beyond)')
    where.add_argument('--engine', help='the engine to run')
    parser.add_argument('--out', required=True, help='folder for the runs')
    parser.add_argument('--timeout', type=int, default=180, help='seconds for each run (default: %(default)s)')
    args = parser.parse_args(argv)

    engine = args.engine or os.path.join(args.app, 'Contents', 'MacOS', 'OXT-Beyond')
    if not os.path.isfile(engine):
        print('FAIL setup: no engine at %s' % engine)
        print('SUMMARY passed=0 failed=1')
        return 1
    if not os.path.isdir(args.out):
        os.makedirs(args.out)

    saved = read_mac_setting()
    print('The Mac\'s AppleInterfaceStyle before the test: %s' % (saved or '(not set: light)'))
    passed = failed = 0
    try:
        for run, mac, appearance, drawn in RUNS:
            set_mac_setting('Dark' if mac == 'dark' else None)
            now = read_mac_setting()
            print('')
            print('Run %s: the Mac %s (AppleInterfaceStyle %s), appAppearance %s, drawn %s' % (
                run, mac, now or '(not set)', appearance or '(default)', drawn))
            sys.stdout.flush()
            folder = os.path.join(args.out, run)
            code, images = run_engine(engine, folder, appearance, args.timeout)
            report = render_check.Report(drawn, run)
            check_run(report, images, mac, drawn, code, args.timeout)
            passed += report.passed
            failed += report.failed
    finally:
        set_mac_setting(saved)
        print('')
        print('The Mac\'s AppleInterfaceStyle restored: %s' % (read_mac_setting() or '(not set: light)'))

    print('SUMMARY passed=%d failed=%d' % (passed, failed))
    return min(failed, 100)


if __name__ == '__main__':
    sys.exit(main())
