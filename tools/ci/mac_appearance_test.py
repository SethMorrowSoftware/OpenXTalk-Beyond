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
that folder, as tools/ci/render-test.ps1 does on Windows), rendering S1, S2
and S9 only (OXT_RENDER_SCENARIOS). The Mac is set to dark or light first, as
a user's Appearance setting is stored:

  defaults write -g AppleInterfaceStyle Dark     (dark)
  defaults delete -g AppleInterfaceStyle         (light)

  run  the Mac  appAppearance  stacks drawn
  M1   dark     system         dark
  M2   dark     (default)      light
  M3   light    system         light
  M4   light    (default)      light

HITheme, which draws the classic native controls, only draws them light, so
the engine draws those of a dark stack itself (MCMacDrawThemeDark in
engine/src/osxtheme.mm). M1 checks them, and M2 that a dark Mac leaves a
stack light until a script asks for the dark appearance.

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
  field, dark or not;
* in the dark run, S2 (but its card, above) and S9, the native controls in
  a stack with no colours, with render_check.py's checks (EXPECT) as on
  Windows, where macOS's dark controls differ (MAC_DARK_EXPECT): lighter
  push button faces (101, as macOS's), a thin progress bar
  (check_mac_progress), a field whose own fill differs from the window
  (check_mac_field_frame checks its frame), and a disabled grey of 136 on
  the window's 50.

The whole cards of S2 and S9 of M1 and M3 are also printed, as base64 PNG
in lines "IMAGE <run>/<file> <part>/<parts> <base64>", for a person to look
at without downloading the logs (tools/ci/print_images.py puts them back
together from a saved log).

The Mac's setting is restored at the end. Every check prints one line,
"PASS <run> <check>: ..." or "FAIL <run> <check>: ...", the last line is
"SUMMARY passed=<n> failed=<n>", and the exit code is the number of failed
checks (at most 100). The images, render.txt and the engine's output of each
run are left in <folder>/<run>.
"""

import argparse
import base64
import os
import shutil
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import render_check  # noqa: E402

SCRIPT = os.path.join(HERE, 'render-test.livecodescript')
SCENARIOS = 's1,s2,s9'

# The images printed for people to look at, by run
PRINTED = {'M1': ('s2-card.png', 's9.png'), 'M3': ('s2-card.png', 's9.png')}
IMAGE_PART = 4000

# render_check.py's checks of the dark run, where macOS's dark controls
# differ from Windows's: a push button face of 101 (pressed 132, disabled
# 56), not 0x37; the disabled grey of the Mac (0x88) on its dark window (50)
# is 3.6:1; the little arrows' face is 101 with white arrows. The card is
# checked above (S2_DARK_MAX), the progress bar by check_mac_progress, and
# the field's frame by check_mac_field_frame (a Mac field's own fill, 30,
# differs from the window, so the whole field changes when it is hidden).
MAC_DARK_EXPECT = {
    's2-card': [],
    's9-push-face': [('interior_max_l', 115)],
    's9-push-pressed-face': [('interior_max_l', 145), ('interior_differs', 's9-push-face', 6)],
    's9-push-disabled-face': [('interior_max_l', 80)],
    's9-check-disabled': [('far_near_l', 136, render_check.GREY_TOLERANCE), ('far_contrast', 3.0)],
    's9-radio-disabled': [('far_near_l', 136, render_check.GREY_TOLERANCE), ('far_contrast', 3.0)],
    's9-push-disabled': [('far_near_l', 136, render_check.GREY_TOLERANCE), ('far_contrast', 3.0)],
    's9-arrows': [('interior_max_l', 140), ('glyph_halves', 60, 3)],
    's9-progress': [],
    's9-field-frame': [('record_face',)],
}

# The frame of a field: its outermost pixels, where HITheme draws it
FIELD_FRAME_L = (100, 170)
FIELD_FRAME_CONTRAST = 3.0

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


def print_images(run, images):
    """Prints the run's PRINTED images as base64, in parts."""
    for name in PRINTED.get(run, ()):
        path = os.path.join(images, name)
        if not os.path.isfile(path):
            print('IMAGE %s/%s missing' % (run, name))
            continue
        with open(path, 'rb') as f:
            data = base64.b64encode(f.read()).decode('ascii')
        parts = [data[i:i + IMAGE_PART] for i in range(0, len(data), IMAGE_PART)] or ['']
        for i, part in enumerate(parts):
            print('IMAGE %s/%s %d/%d %s' % (run, name, i + 1, len(parts), part))
    sys.stdout.flush()


def check_mac_progress(report, images, shots):
    """The progress bar at 50%, a thin bar in the middle of its rect: in
    its middle row, the left quarter (done, the accent colour) shows the
    accent (B - R of at least 60) or differs from the right quarter (the
    track) by at least 25 in L."""
    shot_ = shot(shots, 's9-progress')
    if shot_ is None or len(shot_) < 3:
        report.check('s9-progress progress', False, 'render.txt has no s9-progress shot')
        return
    try:
        w, h, rows = render_check.read_png(os.path.join(images, shot_[2]))
    except Exception as e:  # a broken image is a failure, not a crash
        report.check('s9-progress progress', False, 'cannot read %s: %s' % (shot_[2], e))
        return
    y = h // 2
    quarter = (w - 6) // 4
    if quarter < 2:
        report.check('s9-progress progress', False, '%s is too small (%dx%d)' % (shot_[2], w, h))
        return
    left = [render_check.flatten(rows[y][x]) for x in range(3, 3 + quarter)]
    right = [render_check.flatten(rows[y][x]) for x in range(w - 3 - quarter, w - 3)]
    mean = lambda ps, i: sum(p[i] for p in ps) / float(len(ps))
    left_rgb = [mean(left, i) for i in range(3)]
    right_rgb = [mean(right, i) for i in range(3)]
    left_l = render_check.luma(left_rgb)
    right_l = render_check.luma(right_rgb)
    ok = left_rgb[2] - left_rgb[0] >= 60 or abs(left_l - right_l) >= 25
    report.check('s9-progress progress', ok, 'row %d of %s: the left quarter %s (L=%.0f), the right quarter %s '
                 '(L=%.0f), %s the accent on the left or 25 in L between them (MCMacDarkDrawTrack, '
                 'engine/src/osxtheme.mm)' % (y, shot_[2], render_check._fmt(left_rgb), left_l,
                                              render_check._fmt(right_rgb), right_l,
                                              'expected' if ok else 'FAILED: expected'))


def check_mac_field_frame(report, images, shots):
    """The frame of an empty field: the outermost ring of pixels of its face
    shot (the field's rect) has a median L in FIELD_FRAME_L, and at least
    FIELD_FRAME_CONTRAST against the same ring with the field hidden (the
    card)."""
    shot_ = shot(shots, 's9-field-frame')
    if shot_ is None or len(shot_) < 4:
        report.check('s9-field-frame frame', False, 'render.txt has no s9-field-frame shot')
        return
    try:
        w, h, rows = render_check.read_png(os.path.join(images, shot_[2]))
        rw, rh, ref = render_check.read_png(os.path.join(images, shot_[3]))
    except Exception as e:  # a broken image is a failure, not a crash
        report.check('s9-field-frame frame', False, 'cannot read %s and %s: %s' % (shot_[2], shot_[3], e))
        return
    if (w, h) != (rw, rh) or w < 8 or h < 8:
        report.check('s9-field-frame frame', False, '%s is %dx%d and %s is %dx%d' % (shot_[2], w, h, shot_[3], rw, rh))
        return
    # The ring without its corners, which a rounded frame may leave out
    ring = [(x, 0) for x in range(2, w - 2)] + [(x, h - 1) for x in range(2, w - 2)] + \
        [(0, y) for y in range(2, h - 2)] + [(w - 1, y) for y in range(2, h - 2)]
    frame = render_check._median_rgb([render_check.flatten(rows[y][x]) for (x, y) in ring])
    card = render_check._median_rgb([render_check.flatten(ref[y][x]) for (x, y) in ring])
    frame_l = render_check.luma(frame)
    ratio = render_check.contrast_ratio(frame, card)
    ok = FIELD_FRAME_L[0] <= frame_l <= FIELD_FRAME_L[1] and ratio >= FIELD_FRAME_CONTRAST
    report.check('s9-field-frame frame', ok, 'the outermost pixels of %s are %s (L=%.0f) on the card %s, %.2f:1, '
                 '%s L %d-%d and at least %.1f:1 (THEME_DRAW_TYPE_FRAME in MCMacDrawThemeDark, '
                 'engine/src/osxtheme.mm)' % (shot_[2], render_check._fmt(frame), frame_l, render_check._fmt(card),
                                              ratio, 'expected' if ok else 'FAILED: expected', FIELD_FRAME_L[0],
                                              FIELD_FRAME_L[1], FIELD_FRAME_CONTRAST))


def check_shots(report, images, shots, prefixes):
    """render_check.py's checks of the shots whose names start with one of
    prefixes, as render_check.run makes them."""
    for s in shots:
        kind, name = s[0], s[1]
        if not name.startswith(prefixes):
            continue
        if kind == 'label' and len(s) >= 4:
            enabled = s[4:6] if len(s) >= 6 else [None, None]
            render_check.check_label(report, images, name, s[2], s[3], enabled[0], enabled[1])
        elif kind == 'text' and len(s) >= 4:
            render_check.check_text(report, images, name, s[2], s[3])
        elif kind == 'face' and len(s) >= 4:
            render_check.check_face(report, images, name, s[2], s[3])
        elif kind == 'region' and len(s) >= 4:
            render_check.check_region(report, images, name, s[2], render_check.parse_region(s[3]))


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

    # S2 and S9 in the dark appearance, the controls drawn by
    # MCMacDrawThemeDark (engine/src/osxtheme.mm)
    if drawn == 'dark':
        render_check.FACE_RESULTS.clear()
        check_shots(report, images, shots, ('s2-', 's9-'))
        check_mac_progress(report, images, shots)
        check_mac_field_frame(report, images, shots)


def use_mac_expectations():
    """Puts MAC_DARK_EXPECT into render_check.EXPECT's dark checks."""
    for name, checks in MAC_DARK_EXPECT.items():
        table = dict(render_check.EXPECT.get(name, {}))
        table['dark'] = checks
        render_check.EXPECT[name] = table


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    where = parser.add_mutually_exclusive_group(required=True)
    where.add_argument('--app', help='OXT-Beyond.app (its engine is Contents/MacOS/OXT-Beyond)')
    where.add_argument('--engine', help='the engine to run')
    parser.add_argument('--out', required=True, help='folder for the runs')
    parser.add_argument('--timeout', type=int, default=180, help='seconds for each run (default: %(default)s)')
    args = parser.parse_args(argv)

    use_mac_expectations()
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
            print_images(run, images)
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
