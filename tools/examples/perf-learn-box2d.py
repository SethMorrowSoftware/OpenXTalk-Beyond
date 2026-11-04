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

"""What the two Box2D Learn stacks cost the computer, lesson by lesson, and
the budgets they must keep.

  python3 tools/examples/perf-learn-box2d.py --install DIR
      [--box2d FILE] [--kit FILE] [--before-box2d FILE --before-kit FILE]

It runs perf-learn-box2d.livecodescript, beside this, in the install's
development engine under xvfb-run (Linux only: it reads the engine's
processor time from /proc), for the committed stacks or those given, and
prints, for each card: the share of a core it used running, paused and with
its window hidden, and the milliseconds of one frame. With --before-..., it
measures those stacks too and prints both side by side.

Then it checks the budgets (BUDGET): what a lesson costs while it is paused
or its window is hidden, when it should cost almost nothing, and how long a
frame may take on a CI machine. The share of a core while running depends
on the machine, and is only printed. It ends with "DONE" (exit status 0) or
"FAILED <how many>" (exit status 1).
"""

import argparse
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
SCRIPT = os.path.join(HERE, 'perf-learn-box2d.livecodescript')

# Per card: the most percent of a core while paused, or with the window
# hidden (the ticks it reads are a hundredth of a second, so 2 is "next to
# nothing"), and the most milliseconds a frame may take. Before rc.6.15,
# Learn Box2D's paused lessons used 1 to 5 and its hidden ones as much as
# running; its slowest frame (Hinges) took about 1 ms where these were set.
BUDGET = {'paused': 2, 'hidden': 2, 'frame': 6.0, 'busy': 12.0}


def measure(install, box2d, kit):
    env = dict(os.environ, OXT_INSTALL=install)
    env['OXT_LEARN_BOX2D'] = box2d or ''
    env['OXT_LEARN_KIT'] = kit or ''
    engine = os.path.join(install, 'oxt-beyond')
    out = subprocess.run(['xvfb-run', '-a', '-s', '-screen 0 1280x1024x24', engine, '-ui', SCRIPT],
                         env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                         universal_newlines=True, timeout=900).stdout
    rows = {}
    for line in out.splitlines():
        words = line.split()
        if words[:1] == ['PERF']:
            rows[(words[1], words[2])] = dict(zip(words[3::2], words[4::2]))
        elif words[:1] == ['FAILED']:
            raise SystemExit(line)
    if 'DONE' not in out.split():
        raise SystemExit('FAILED the engine did not finish:\n' + out[-2000:])
    return rows


def number(value):
    try:
        return float(value)
    except ValueError:
        return None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--install', required=True)
    ap.add_argument('--box2d')
    ap.add_argument('--kit')
    ap.add_argument('--before-box2d')
    ap.add_argument('--before-kit')
    args = ap.parse_args()
    after = measure(os.path.abspath(args.install), args.box2d, args.kit)
    before = None
    if args.before_box2d or args.before_kit:
        before = measure(os.path.abspath(args.install), args.before_box2d, args.before_kit)
    keys = ('run', 'paused', 'hidden', 'frame', 'busy')
    print('%-16s %s' % ('card', '  '.join('%13s' % k for k in keys)))
    for card, row in after.items():
        cells = []
        for k in keys:
            if before and card in before:
                cells.append('%13s' % ('%s -> %s' % (before[card][k], row[k])))
            else:
                cells.append('%13s' % row[k])
        print('%-16s %s' % (' '.join(card), '  '.join(cells)))
    fails = 0
    for card, row in after.items():
        for k, most in BUDGET.items():
            value = number(row.get(k, '-'))
            if value is not None and value > most:
                print('FAIL %s %s: %s %s, over %s' % (card[0], card[1], k, row[k], most))
                fails += 1
    if fails:
        print('FAILED %d' % fails)
        return 1
    print('DONE')
    return 0


if __name__ == '__main__':
    sys.exit(main())
